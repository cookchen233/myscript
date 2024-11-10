<?php
function env($key){
    if($key == "NOTIFICATION_SERVER_HOST"){
        return "127.0.0.1";
    }
    if($key == "NOTIFICATION_SERVER_PORT"){
        return 9123;
    }
    return "";
}
class HandleException{

    /**
     * 发送通知到服务端
     * @param string $message 通知消息
     * @param string|null $error_tag 错误标签,用于去重
     * @param string $error_level 错误级别 debug/info/error
     * @return bool 是否发送成功
     */
    public static function send_notification(string $message, $details = null, $error_tag = null, $error_level = 'info'): bool
    {
        $primary_ip = env("NOTIFICATION_SERVER_HOST");
        if(!$primary_ip){
            return false;
        }
        $backup_ip = '10.211.55.2';

        $port = env("NOTIFICATION_SERVER_PORT");
        $socket = null;

        try {
            $data = [
                'message' => $message,
                'details' => $details,
                'error_level' => $error_level,
                'timestamp' => time(),
            ];

            if ($error_tag !== null) {
                $data['error_tag'] = $error_tag;
            }

            $json_data = json_encode($data);
            if ($json_data === false) {
                throw new Exception('Failed to encode JSON data');
            }

            $socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
            if ($socket === false) {
                throw new Exception('socket_create() failed: ' . socket_strerror(socket_last_error()));
            }

            // 设置超时
            socket_set_option($socket, SOL_SOCKET, SO_RCVTIMEO, ['sec' => 1, 'usec' => 0]);
            socket_set_option($socket, SOL_SOCKET, SO_SNDTIMEO, ['sec' => 1, 'usec' => 0]);

            // 尝试连接主IP
            $result = @socket_connect($socket, $primary_ip, $port);
            if ($result === false) {
                // 主IP连接失败，尝试备用IP
                socket_close($socket);
                $socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);

                if ($socket === false) {
                    throw new Exception('socket_create() failed on backup attempt: ' . socket_strerror(socket_last_error()));
                }

                // 重新设置超时
                socket_set_option($socket, SOL_SOCKET, SO_RCVTIMEO, ['sec' => 1, 'usec' => 0]);
                socket_set_option($socket, SOL_SOCKET, SO_SNDTIMEO, ['sec' => 1, 'usec' => 0]);

                $result = @socket_connect($socket, $backup_ip, $port);
                if ($result === false) {
                    throw new Exception('Both primary and backup connections failed');
                }
            }

            $bytes_sent = socket_write($socket, $json_data, strlen($json_data));
            if ($bytes_sent === false) {
                throw new Exception('Failed to write to socket: ' . socket_strerror(socket_last_error($socket)));
            }

            return true;
        } catch (Exception $e) {
            Log::error('Server notification failed: ' . $e->getMessage(), [
                'primary_ip' => $primary_ip,
                'backup_ip' => $backup_ip,
                'message' => $message,
                'details' => $details,
                'error_tag' => $error_tag
            ]);
            return false;
        } finally {
            if ($socket && is_resource($socket)) {
                socket_close($socket);
            }
        }
    }
}


// 使用示例
function test_notification() {
    // 发送各种级别的通知
    HandleException::send_notification("这是一条调试信息", "DEBUG_001", "debug");
    HandleException::    send_notification("这是一条普通信息", "INFO_001", "info");
    HandleException::send_notification("这是一条错误信息", "ERR_001", "error");
    
    // 不带error_tag的通知
    HandleException::send_notification("这是一条临时通知");
}

// 运行测试
test_notification();