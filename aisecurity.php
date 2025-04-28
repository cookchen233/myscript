<?php
namespace app\admin\controller;

use think\facade\Db;
use think\facade\Request;
use think\facade\Validate;
use app\common\model\PlatformAccount; // 假设的模型文件
use app\common\model\Package;        // 套餐模型
use think\Controller;

/**
 * 平台账号管理控制器
 * 用于总管理后台的平台账号相关操作
 */
class PlatformAccountController extends Controller
{
    /**
     * 平台账号列表
     * 显示所有平台账号信息，支持分页和筛选
     * @return \think\Response
     */
    public function index()
    {
        // 获取查询参数
        $keyword = Request::param('keyword', ''); // 搜索关键词
        $status  = Request::param('status', '');  // 账号状态

        // 构建查询条件
        $query = PlatformAccount::where('deleted_at', null); // 软删除字段，确保只查未删除数据
        if (!empty($keyword)) {
            $query->where('account_name|account_code', 'like', "%{$keyword}%");
        }
        if ($status !== '') {
            $query->where('status', $status);
        }

        // 分页查询，每页10条
        $list = $query->order('id', 'desc')
                      ->paginate(10);

        // 返回视图并传递数据
        return view('platform_account/index', [
            'list'    => $list,
            'keyword' => $keyword,
            'status'  => $status
        ]);
    }

    /**
     * 添加平台账号
     * 处理新增平台账号的请求
     * @return \think\Response
     */
    public function add()
    {
        if (Request::isPost()) {
            // 获取提交的数据
            $data = Request::only([
                'account_name',  // 账号名称
                'account_code',  // 账号编码
                'package_id',    // 关联套餐ID
                'expire_time',   // 到期时间
                'status'         // 状态（0禁用，1启用）
            ]);

            // 数据验证
            $validate = Validate::make([
                'account_name|账号名称' => 'require|max:50',
                'account_code|账号编码' => 'require|unique:platform_account|max:20',
                'package_id|套餐'      => 'require|integer',
                'expire_time|到期时间' => 'require|date',
                'status|状态'          => 'require|in:0,1'
            ]);

            if (!$validate->check($data)) {
                return json(['code' => 1, 'msg' => $validate->getError()]);
            }

            // 保存数据
            $data['created_at'] = date('Y-m-d H:i:s');
            $result = PlatformAccount::create($data);

            if ($result) {
                // 记录操作日志（假设有日志方法）
                $this->logOperation('添加平台账号：' . $data['account_name']);
                return json(['code' => 0, 'msg' => '添加成功']);
            }
            return json(['code' => 1, 'msg' => '添加失败']);
        }

        // 获取所有套餐供选择
        $packages = Package::where('status', 1)->select();

        return view('platform_account/add', ['packages' => $packages]);
    }

    /**
     * 编辑平台账号
     * 修改已有平台账号信息
     * @param int $id 账号ID
     * @return \think\Response
     */
    public function edit($id)
    {
        $account = PlatformAccount::find($id);
        if (!$account) {
            $this->error('账号不存在');
        }

        if (Request::isPost()) {
            // 获取提交数据
            $data = Request::only([
                'account_name',
                'account_code',
                'package_id',
                'expire_time',
                'status'
            ]);

            // 数据验证
            $validate = Validate::make([
                'account_name|账号名称' => 'require|max:50',
                'account_code|账号编码' => 'require|max:20|unique:platform_account,account_code,' . $id,
                'package_id|套餐'      => 'require|integer',
                'expire_time|到期时间' => 'require|date',
                'status|状态'          => 'require|in:0,1'
            ]);

            if (!$validate->check($data)) {
                return json(['code' => 1, 'msg' => $validate->getError()]);
            }

            // 更新数据
            $data['updated_at'] = date('Y-m-d H:i:s');
            $result = $account->save($data);

            if ($result) {
                $this->logOperation('编辑平台账号：' . $data['account_name']);
                return json(['code' => 0, 'msg' => '更新成功']);
            }
            return json(['code' => 1, 'msg' => '更新失败']);
        }

        // 获取套餐列表
        $packages = Package::where('status', 1)->select();
        return view('platform_account/edit', [
            'account'  => $account,
            'packages' => $packages
        ]);
    }

    /**
     * 切换账号状态
     * 启用或禁用平台账号
     * @param int $id 账号ID
     * @return \think\Response
     */
    public function toggleStatus($id)
    {
        $account = PlatformAccount::find($id);
        if (!$account) {
            return json(['code' => 1, 'msg' => '账号不存在']);
        }

        // 切换状态
        $account->status = $account->status == 1 ? 0 : 1;
        $result = $account->save();

        if ($result) {
            $this->logOperation('切换账号状态：' . $account->account_name . ' -> ' . ($account->status ? '启用' : '禁用'));
            return json(['code' => 0, 'msg' => '操作成功']);
        }
        return json(['code' => 1, 'msg' => '操作失败']);
    }

    /**
     * 删除平台账号（软删除）
     * @param int $id 账号ID
     * @return \think\Response
     */
    public function delete($id)
    {
        $account = PlatformAccount::find($id);
        if (!$account) {
            return json(['code' => 1, 'msg' => '账号不存在']);
        }

        // 执行软删除
        $account->deleted_at = date('Y-m-d H:i:s');
        $result = $account->save();

        if ($result) {
            $this->logOperation('删除平台账号：' . $account->account_name);
            return json(['code' => 0, 'msg' => '删除成功']);
        }
        return json(['code' => 1, 'msg' => '删除失败']);
    }

    /**
     * 记录操作日志
     * @param string $message 日志内容
     */
    private function logOperation($message)
    {
        // 假设有一个日志表
        Db::table('operation_log')->insert([
            'admin_id'   => session('admin_id'), // 当前管理员ID
            'action'     => $message,
            'created_at' => date('Y-m-d H:i:s')
        ]);
    }
}