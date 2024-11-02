<?php
// notification_client.php

/**
 * 发送通知到服务端
 * 
 * @param string $message 通知消息
 * @param string|null $error_tag 错误标签,用于去重
 * @param string $error_level 错误级别 debug/info/error
 * @return bool 是否发送成功
 */
function send_notification($message, $error_tag = null, $error_level = 'info') {
    try {
        $data = [
            'message' => $message,
            'error_level' => $error_level
        ];
        
        if ($error_tag !== null) {
            $data['error_tag'] = $error_tag;
        }
        
        $socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
        if ($socket === false) {
            throw new Exception("socket_create() failed: " . socket_strerror(socket_last_error()));
        }
        
        // 设置超时
        socket_set_option($socket, SOL_SOCKET, SO_RCVTIMEO, ['sec' => 1, 'usec' => 0]);
        socket_set_option($socket, SOL_SOCKET, SO_SNDTIMEO, ['sec' => 1, 'usec' => 0]);
        
        $result = socket_connect($socket, '127.0.0.1', 9123);
        if ($result === false) {
            throw new Exception("socket_connect() failed: " . socket_strerror(socket_last_error($socket)));
        }
        
        socket_write($socket, json_encode($data), strlen(json_encode($data)));
        socket_close($socket);
        
        return true;
    } catch (Exception $e) {
        error_log("Server notification connection failed: " . $e->getMessage());
        return false;
    }
}

// 使用示例
function test_notification() {
    // 发送各种级别的通知
    send_notification("这是一条调试信息", "DEBUG_001", "debug");
    send_notification("这是一条普通信息", "INFO_001", "info");
    send_notification("这是一条错误信息", "ERR_001", "error");
    
    // 不带error_tag的通知
    send_notification("这是一条临时通知");
}

// 运行测试
// test_notification();