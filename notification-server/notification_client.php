// client.php
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
     * @param string[] $data = [
     * 'program_name' => '', //程序名称
     * 'title' => '', // 标题
     * 'details' => '', // 详情
     * 'message_tag' => '', // 消息标签(用于频率限制)
     * 'message_type' => '', // 消息类型(用于频率限制)
     * ]
     * @return bool 是否发送成功
     */
    public static function send_notification(array $data = [
        'program_name' => '',
        'title' => '',
        'details' => '',
        'message_tag' => '',
        'message_type' => '',
    ]): bool
    {
        $ip = env('NOTIFICATION_SERVER_HOST');
        if (!$ip) {
            return false;
        }

        $port = env('NOTIFICATION_SERVER_PORT');
        $socket = null;

        try {
            // 准备要发送的数据
            $json_data = json_encode($data) . "\n";  // 添加换行符
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
            $result = @socket_connect($socket, $ip, $port);
            if ($result === false) {
                throw new Exception('Failed to connect to primary server: ' . socket_strerror(socket_last_error($socket)));
            }

            // 发送数据
            $bytes_sent = socket_write($socket, $json_data, strlen($json_data));
            if ($bytes_sent === false) {
                throw new Exception('Failed to write to socket: ' . socket_strerror(socket_last_error($socket)));
            }

            // 读取服务器响应
            $response = '';
            while ($buf = socket_read($socket, 1024)) {
                $response .= $buf;
                // 如果响应结束，跳出循环
                if (substr($buf, -1) === "\n") {
                    break;
                }
            }

            // 处理响应
            $response_data = json_decode(trim($response), true);
            var_dump('Server response:', $response_data);

            return true;
        } catch (Exception $e) {
            var_dump(
                'Server notification failed', 
                $e->getMessage(),
                $ip,
                $port,
                $data,
            );
            throw $e;
            
        } finally {
            if ($socket && is_resource($socket)) {
                socket_close($socket);
            }
        }
    }
    
}
 
HandleException::send_notification([
    'program_name' => 'a',
    'title' => 'b',
    'details' => 'c',
    'message_tag' => 'd',
    'message_type' => 'ERROR',
]);