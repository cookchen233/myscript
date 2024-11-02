#!/bin/bash

parse_ali_log_to_json() {
	result=$(echo "$1" | jq -C -e -r .content)
    if [[ $? == 0 ]]; then
        echo "$result" | jq -C -e -r '.ip, .method, .host, .uri, .timestamp, .traceid'
        if echo "$result" | jq '. | has("log") or has ("error") or has ("info")' | grep -q true; then
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
                result2=$(echo "$result" | jq -e -r ."$key" | sed -E -e 's/ +/sepsep/g' -e 's/\\r\\n/\n/g')
                for r2 in $result2; do
                    r2="${r2//sepsep/ }"
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
        echo echo "$1" | jq -C -e -r .
    fi
	return $?
}

parse_ali_log_to_json "$1"