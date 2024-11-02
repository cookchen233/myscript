#!/bin/bash

parse_ali_log_to_json() {
	result=$(pbpaste | jq -C -e -r .content)
    if [[ $? == 0 ]]; then
        echo "$result" | jq -C -e -r '.ip, .method, .host, .uri, .timestamp, .traceid'
        if [[ $1 ]]; then
            echo "$result" | jq -C -e -r ."$1"| jq -C -e -r .
        elif echo "$result" | jq '. | has("log") or has ("error") or has ("info")' | grep -q true; then
            keys=$(echo "$result"|jq -r 'keys[]')
            for key in $keys; do
                if [[ $key != "log" && $key != "error" && $key != "info" ]]; then
                    continue
                fi
                color=""
                if [[ $key == "error" ]]; then
                    color="\033[31m"
                elif [[ $key == "info" ]]; then
                    color="\033[33m"
                elif [[ $key == "log" ]]; then
                    color="\033[32m"
                fi
                echo -e "$color============================[Parse Field \"$key\"]==============================\033[0m"
                # parse multiple json strings joined by newlines
                result2=$(echo "$result" | jq -e -r ."$key" | sed -E -e 's/ +/dddd/g' -e 's/\\r\\n/\n/g')
                for r2 in $result2; do
                    r2="${r2//dddd/ }"
                    if [[ $r2 =~ ^[{\[] ]]; then
                        echo "$r2" | jq -C -e -r .
                    else
                        echo  -e "$r2"
                    fi
                done
            done
        else
            echo "$result" | jq -C -e -r .
        fi
    else
        echo echo "$result" | jq -C -e -r .
    fi
	return $?
}

parse_ali_log_to_json2() {
	pbpaste \
    | sed -e 's/\[ DB \].*$/\\\"\}\"\}/g' \
    | jq -e .content -r \
    | jq -e . \
    | sed -e 's/\\\\u/\\u/g' -e 's/\\"/\\\\"/g' -e 's/\\n/\\\\n/g' -e 's/\\r//g' -e "s/'/\\\\'/g" \
    | awk -F "ddddddd" '{print "print(u\047" $1 "\047)"}' \
    | xargs -0  python3 -c \
    | sed 's/\\\([^"]\)/\\\\\1/g' \
    | jq -e ."$1"
	return $?
}

parse_ali_log_to_json3() {
	pbpaste \
    | jq -e .content -r \
    | jq -e . \
    | sed -e 's/\\\\u/\\u/g' -e 's/\\"/\\\\"/g' -e "s/'/\\\\'/g" \
    | awk -F "ddddddd" '{print "print(u\047" $1 "\047)"}' \
    | xargs -0  python3 -c \
    | sed 's/\\\([^"]\)/\\\\\1/g' \
    | jq -e ."$1" | sed -e 's/\\\\n/\n/g' -e 's/\\//g'
	return $?
}

if parse_ali_log_to_json; then
    echo "succesfully parsed json style 1"
    read -t 300 key
    parse_ali_log_to_json "$key" | sed -e 's/\\\\n/\n/g'
    read -t 300
elif parse_ali_log_to_json2; then
    echo "succesfully parsed json style 2"
    read -t 300 key
    parse_ali_log_to_json2 "$key" | sed -e 's/\\\\n/\n/g'
    read -t 300
elif parse_ali_log_to_json3; then
    echo "succesfully parsed json style 3"
    read -t 300
else
    echo "failed to parse json"
    read -r
fi