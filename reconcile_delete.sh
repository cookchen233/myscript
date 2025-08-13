#!/usr/bin/env bash
set -euo pipefail
set -o errtrace

export LC_ALL=C

### ================ 配置 ================
# MySQL
MYSQL_HOST="172.18.11.146"
MYSQL_PORT="33306"
MYSQL_USER="canal_es"
MYSQL_PASS="5gVTDk66BW90wmB9WYBM"
MYSQL_DB="forebay_msr"
MYSQL_TABLE="sheet1"
MYSQL_ID_COL="AutoID"

# ES
ES_BASE="http://172.18.11.90:9200"
ES_INDEX="ebay_listing3"
ES_USER=""
ES_PASS=""

# Scroll
SCROLL_KEEPALIVE="5m"
SCROLL_PAGE=10000

# 删除批大小（terms(_id) 每批 ID 数）
DEL_BATCH=200

# 可选 ID 范围（纯数字 _id 时有效）
MIN_ID=""
MAX_ID=""

# 差集算法：hash | sort
DIFF_MODE="hash"
### =====================================

# 运行开关
DRY_RUN=false
KEEP_TMP=false
DEBUG=false
for a in "${@:-}"; do
  case "$a" in
    --dry-run) DRY_RUN=true ;;
    --keep-tmp) KEEP_TMP=true ;;
    --debug) DEBUG=true ;;
  esac
done

# 确保变量初始化
: "${DEBUG:=false}" "${DRY_RUN:=false}" "${KEEP_TMP:=false}"

# 日志
log() { echo "[INFO] $*" >&2; }
dbg() { [ "${DEBUG:-false}" = true ] && echo "[DEBUG] $*" >&2; }
err() { echo "[ERROR] $*" >&2; }

# 清理旧的 trap
trap '' EXIT ERR
# 设置新的错误处理 trap
trap 'err "脚本异常退出（行号:$LINENO，上一条命令: $BASH_COMMAND）"' ERR

# 检查依赖工具
for cmd in mysql curl jq awk; do
  command -v "$cmd" >/dev/null 2>&1 || { err "需要安装 $cmd"; exit 1; }
done

# 工作目录
WORKDIR="$(mktemp -d /tmp/es_reconcile.XXXXXX)"
MYSQL_IDS="$WORKDIR/mysql_ids.txt"
ES_IDS="$WORKDIR/es_ids.txt"
TO_DELETE="$WORKDIR/to_delete.txt"
cleanup() {
  rm -rf "$WORKDIR" || true
  [[ -n "${last_scroll_id:-}" ]] && curl -s "${auth_args[@]}" -XDELETE "${ES_BASE}/_search/scroll" -H 'Content-Type: application/json' -d "{\"scroll_id\":\"$last_scroll_id\"}" >/dev/null || true
}
[[ $KEEP_TMP == true ]] || trap 'cleanup' EXIT

log "工作目录: $WORKDIR"

# 1) 导出 MySQL ID
WHERE=""
[[ -n "$MIN_ID" && -n "$MAX_ID" ]] && WHERE="WHERE ${MYSQL_ID_COL} BETWEEN ${MIN_ID} AND ${MAX_ID}"
[[ -n "$MIN_ID" && -z "$MAX_ID" ]] && WHERE="WHERE ${MYSQL_ID_COL} >= ${MIN_ID}"
[[ -z "$MIN_ID" && -n "$MAX_ID" ]] && WHERE="WHERE ${MYSQL_ID_COL} <= ${MAX_ID}"

log "导出 MySQL ID..."
if ! MYSQL_PWD="$MYSQL_PASS" mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u"$MYSQL_USER" -q -N \
  -e "SELECT ${MYSQL_ID_COL} FROM ${MYSQL_DB}.${MYSQL_TABLE} ${WHERE}" > "$MYSQL_IDS"; then
  err "MySQL 查询失败"
  exit 1
fi
MYSQL_COUNT=$(wc -l < "$MYSQL_IDS" | tr -d ' ')
[[ "$MYSQL_COUNT" -gt 0 ]] || { err "MySQL 导出的 ID 数量为 0"; exit 1; }
log "MySQL ID 数量: $MYSQL_COUNT"

# 2) Scroll 导出 ES 全量 _id（压缩 + 精简字段）
auth_args=()
[[ -n "$ES_USER" || -n "$ES_PASS" ]] && auth_args=(-u "${ES_USER}:${ES_PASS}")

log "滚动导出 ES _id..."
resp=$(curl --compressed -s "${auth_args[@]}" -H 'Content-Type: application/json' \
  -XPOST "${ES_BASE}/${ES_INDEX}/_search?scroll=${SCROLL_KEEPALIVE}&filter_path=_scroll_id,hits.hits._id" \
  -d "$(jq -n --argjson size "$SCROLL_PAGE" '{size:$size, _source:false, sort: ["_doc"], query: {"match_all":{}} }')") || { err "ES 初始搜索失败"; exit 1; }
scroll_id=$(jq -r '._scroll_id // empty' <<<"$resp")
hits=$(jq -r '.hits.hits | length // 0' <<<"$resp")
jq -r '.hits.hits[]._id' <<<"$resp" >> "$ES_IDS" || { err "解析 ES 初始响应失败"; exit 1; }
last_scroll_id="$scroll_id"

while [[ "$hits" -gt 0 && -n "$scroll_id" ]]; do
  resp=$(curl --compressed -s "${auth_args[@]}" -H 'Content-Type: application/json' \
    -XPOST "${ES_BASE}/_search/scroll?filter_path=_scroll_id,hits.hits._id" \
    -d "$(jq -n --arg sid "$scroll_id" --arg keep "$SCROLL_KEEPALIVE" '{scroll:$keep, scroll_id:$sid}')") || { err "ES 滚动搜索失败"; exit 1; }
  hits=$(jq -r '.hits.hits | length // 0' <<<"$resp")
  [[ "$hits" -eq 0 ]] && break
  jq -r '.hits.hits[]._id' <<<"$resp" >> "$ES_IDS" || { err "解析 ES 滚动响应失败"; exit 1; }
  scroll_id=$(jq -r '._scroll_id // empty' <<<"$resp")
  last_scroll_id="$scroll_id"
done
ES_COUNT=$(wc -l < "$ES_IDS" | tr -d ' ')
[[ "$ES_COUNT" -gt 0 ]] || { err "ES 导出的 ID 数量为 0"; exit 1; }
log "ES ID 数量: $ES_COUNT"

# 清理 scroll（忽略失败）
if [[ -n "${last_scroll_id:-}" ]]; then
  curl -s "${auth_args[@]}" -H 'Content-Type: application/json' \
    -XDELETE "${ES_BASE}/_search/scroll" \
    -d "$(jq -n --arg sid "$last_scroll_id" '{scroll_id:$sid}')" >/dev/null || true
fi

# 3) 按范围过滤（仅数字 _id）
if [[ -n "${MIN_ID}${MAX_ID}" ]]; then
  log "按范围过滤 ES _id..."
  awk -v min="${MIN_ID:-}" -v max="${MAX_ID:-}" '
    function isnum(x){ return (x ~ /^[0-9]+$/) }
    { if (!isnum($0)) next
      if (min != "" && $0 < min) next
      if (max != "" && $0 > max) next
      print }' "$ES_IDS" > "$ES_IDS.tmp" || { err "ES ID 范围过滤失败"; exit 1; }
  mv "$ES_IDS.tmp" "$ES_IDS"
  ES_COUNT=$(wc -l < "$ES_IDS" | tr -d ' ')
  log "过滤后 ES ID 数量: $ES_COUNT"
fi

# 4) 差集（ES - MySQL）
log "计算差集..."
if [[ "$DIFF_MODE" == "hash" ]]; then
  awk 'NR==FNR { seen[$1]=1; next } !($1 in seen) { print $1 }' "$MYSQL_IDS" "$ES_IDS" > "$TO_DELETE" || { err "计算差集失败"; exit 1; }
else
  sort -u --parallel="$(nproc)" -S 50% "$ES_IDS" -o "$ES_IDS" || { err "排序 ES_IDS 失败"; exit 1; }
  sort -u --parallel="$(nproc)" -S 50% "$MYSQL_IDS" -o "$MYSQL_IDS" || { err "排序 MYSQL_IDS 失败"; exit 1; }
  comm -23 "$ES_IDS" "$MYSQL_IDS" > "$TO_DELETE" || { err "计算差集失败"; exit 1; }
fi
DEL_COUNT=$(wc -l < "$TO_DELETE" | tr -d ' ')
log "待删除数量: $DEL_COUNT"
[[ "$DEL_COUNT" -gt 0 ]] || { log "没有需要删除的文档"; exit 0; }

# dry-run
if $DRY_RUN; then
  log "[DRY-RUN] 仅展示前 20 个待删 ID："
  head -n 20 "$TO_DELETE"
  log "[DRY-RUN] 文件保留在: $WORKDIR"
  exit 0
fi

# 5) 删除：_delete_by_query terms(_id)
log "开始删除..."
[[ -s "$TO_DELETE" ]] || { err "待删除文件 $TO_DELETE 为空或不存在"; exit 1; }

i=0
batch_ids=()

flush_delete_by_query() {
  local ids_json http_code resp_file deleted failed
  [[ ${#batch_ids[@]} -gt 0 ]] || return
  ids_json=$(printf '%s\n' "${batch_ids[@]}" | jq -R . | jq -s .) || { err "生成 JSON ID 列表失败"; exit 1; }
  resp_file="$WORKDIR/dq_resp_${i}.json"
  http_code=$(curl --compressed -s "${auth_args[@]}" -H 'Content-Type: application/json' \
      -XPOST "${ES_BASE}/${ES_INDEX}/_delete_by_query?wait_for_completion=true&conflicts=proceed" \
      -d "$(jq -n --argjson ids "$ids_json" '{query:{terms:{_id:$ids}}}')" \
      -o "$resp_file" -w '%{http_code}') || { err "curl 删除请求失败"; exit 1; }

  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    err "_delete_by_query HTTP $http_code，响应: $resp_file"
    head -n 80 "$resp_file" || true
    exit 1
  fi

  failed=$(jq -r '.failures | length // 0' "$resp_file" 2>/dev/null || echo 0)
  deleted=$(jq -r '.deleted // 0' "$resp_file" 2>/dev/null || echo 0)
  if [[ "$failed" != "0" ]]; then
    err "_delete_by_query 存在失败项（deleted=$deleted），详见: $resp_file"
    jq -r '.failures[] | @json' "$resp_file" 2>/dev/null | head -n 10 || true
    exit 1
  fi
  log "批次完成：提交 ${#batch_ids[@]} 条，ES 实际删除 $deleted 条（不存在的文档不会计入）"
  batch_ids=()
}

while IFS= read -r id; do
  [[ -n "$id" ]] || continue  # 跳过空行
  dbg "准备删除 ID: $id"
  batch_ids+=("$id")
  ((i+=1))
  if (( ${#batch_ids[@]} >= DEL_BATCH )); then
    log "提交删除请求进度: $i / $DEL_COUNT"
    flush_delete_by_query
  fi
done < "$TO_DELETE"

flush_delete_by_query
log "删除完成，总计提交: $i 条"
[[ $KEEP_TMP == true ]] && log "保留临时目录: $WORKDIR"