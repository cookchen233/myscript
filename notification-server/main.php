<?php
require 'vendor/autoload.php';
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

// 加载环境变量
$dotenv = Dotenv\Dotenv::createUnsafeImmutable(__DIR__);
$dotenv->load();

function sendMail($to, $subject, $message) {
    // 检查是否启用邮件功能
    if (getenv('NF_ENABLE_MAIL') !== 'true') {
        return true;
    }

    $mail = new PHPMailer(true);

    try {
        $mail->isSMTP();
        $mail->Host = getenv('NF_SMTP_HOST');
        $mail->SMTPAuth = true;
        $mail->Username = getenv('NF_SMTP_USER');
        $mail->Password = getenv('NF_SMTP_PASS');
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
        $mail->Port = getenv('NF_SMTP_PORT');
        $mail->CharSet = 'UTF-8';

        $mail->setFrom(getenv('NF_MAIL_FROM'));

        $recipients = explode(';', $to);
        foreach ($recipients as $recipient) {
            $recipient = trim($recipient);
            if (empty($recipient)) continue;
            $mail->addAddress($recipient);
        }

        $mail->isHTML(true);
        $mail->Subject = $subject;
        $mail->Body = $message;

        return $mail->send();
    } catch (Exception $e) {
        throw new Exception("Mail sending failed: " . $mail->ErrorInfo);
    }
}

try {
    $port = getenv("NF_PORT");
    $socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
    if ($socket === false) {
        throw new Exception("Failed to create socket: " . socket_strerror(socket_last_error()));
    }

    if (!socket_set_option($socket, SOL_SOCKET, SO_REUSEADDR, 1)) {
        throw new Exception("Failed to set socket option: " . socket_strerror(socket_last_error($socket)));
    }

    if (!socket_bind($socket, '0.0.0.0', $port)) {
        throw new Exception("Failed to bind socket: " . socket_strerror(socket_last_error($socket)));
    }

    if (!socket_listen($socket)) {
        throw new Exception("Failed to listen on socket: " . socket_strerror(socket_last_error($socket)));
    }

    echo "Server listening on port $port...\n";

    while (true) {
        $client = socket_accept($socket);
        if ($client === false) {
            echo "Failed to accept client connection: " . socket_strerror(socket_last_error($socket)) . "\n";
            continue;
        }
        echo "New client connected\n";
        
        $data = '';
        while ($buf = socket_read($client, 2048)) {
            if ($buf === false) {
                echo "Failed to read from client: " . socket_strerror(socket_last_error($client)) . "\n";
                break;
            }
            $data .= $buf;
            echo "Received data chunk: " . bin2hex($buf) . "\n";
            if (strpos($buf, "\n") !== false) break;
        }
        
        echo "Complete data received: " . $data . "\n";
        
        $json = json_decode(trim($data), true);
        
        if ($json) {
            try {
                $log_file = __DIR__ . '/main.log';
                $log_dir = dirname($log_file);

                // 1. 输出当前用户和目录信息进行调试
                echo "Current user: " . exec('whoami') . "\n";
                echo "Log directory: " . $log_dir . "\n";
                echo "Log file: " . $log_file . "\n";

                // 2. 检查目录权限
                if (file_exists($log_dir)) {
                    echo "Directory permissions: " . decoct(fileperms($log_dir)) . "\n";
                    echo "Directory owner: " . fileowner($log_dir) . "\n";
                    echo "Directory writable: " . (is_writable($log_dir) ? 'yes' : 'no') . "\n";
                }

                // 3. 创建目录（如果不存在）
                if (!is_dir($log_dir)) {
                    echo "Creating directory...\n";
                    if (!mkdir($log_dir, 0777, true)) {
                        throw new Exception(
                            "Failed to create log directory: $log_dir" .
                            " (Error: " . error_get_last()['message'] . ")"
                        );
                    }
                    // 确保设置了正确的权限
                    chmod($log_dir, 0777);
                }

                // 4. 检查文件权限
                if (file_exists($log_file)) {
                    echo "File permissions: " . decoct(fileperms($log_file)) . "\n";
                    echo "File owner: " . fileowner($log_file) . "\n";
                    echo "File writable: " . (is_writable($log_file) ? 'yes' : 'no') . "\n";
                } else {
                    // 如果文件不存在，创建文件
                    echo "Creating file...\n";
                    if (file_put_contents($log_file, '') === false) {
                        throw new Exception(
                            "Failed to create log file: $log_file" .
                            " (Error: " . error_get_last()['message'] . ")"
                        );
                    }
                    // 设置文件权限
                    chmod($log_file, 0666);
                }

                // 5. 尝试写入文件
                $log_message = date('Y-m-d H:i:s') . " - Received: " . json_encode($json) . "\n";
                $write_result = file_put_contents($log_file, $log_message, FILE_APPEND | LOCK_EX);

                if ($write_result === false) {
                    $error = error_get_last();
                    throw new Exception(
                        "Failed to write to log file: $log_file" .
                        " (Error: " . ($error ? $error['message'] : 'Unknown error') . ")" .
                        " (File writable: " . (is_writable($log_file) ? 'yes' : 'no') . ")"
                    );
                }
                
                $subject = "系统通知 [{$json['program_name']}] [{$json['message_type']}]";
                
                $message = <<<EOT
<html><head>
<style>
    body {
        font-family: 'Helvetica', sans-serif;
    }
    h2 {
        font-size:16px;
        font-weight: bold;
        color: #333;
        margin-bottom: 10px;
    }
    pre {
        font-size:12px;
    }
</style>
</head>
<body>
<h2>{$json['title']}</h2>
<p><pre>{$json['details']}</pre></p>
</body></html>
EOT;

                $to = getenv('NF_MAIL_TO');
                if (!sendMail($to, $subject, $message)) {
                    throw new Exception("Failed to send email");
                }
                
                $response = json_encode([
                    'status' => 'success',
                    'message' => 'Notification sent successfully',
                    'timestamp' => date('Y-m-d H:i:s'),
                    'recipients' => explode(';', $to)
                ]) . "\n";
                echo "Sending response: " . $response;
                
                if (!socket_write($client, $response)) {
                    throw new Exception("Failed to send response to client: " . socket_strerror(socket_last_error($client)));
                }
                
            } catch (Exception $e) {
                $error_response = json_encode([
                    'status' => 'error',
                    'message' => $e->getMessage(),
                    'timestamp' => date('Y-m-d H:i:s')
                ]) . "\n";
                socket_write($client, $error_response);
                echo "Error: " . $e->getMessage() . "\n";
            }
        } else {
            $invalid_response = json_encode([
                'status' => 'error',
                'message' => 'Invalid JSON data received',
                'timestamp' => date('Y-m-d H:i:s')
            ]) . "\n";
            socket_write($client, $invalid_response);
            echo "Error: Invalid JSON received\n";
        }
        
        socket_close($client);
        echo "Client connection closed\n";
    }

} catch (Exception $e) {
    throw $e;
} finally {
    if (isset($socket) && is_resource($socket)) {
        socket_close($socket);
    }
}