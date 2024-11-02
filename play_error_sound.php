<?php
/*
the client
function playErrorSound($message) {
    $errno = 0;
    $errstr = '';
    $fp = @fsockopen('10.211.55.2', 9123, $errno, $errstr, 1);
    if (!$fp) {
        LcLog::error("Server playErrorSound connection failed: [$errno] $errstr");
        return false;
    }
    fwrite($fp, $message);
    fclose($fp);
    return true;
}

usage: php ~/Coding/myscript/play_error_sound.php
kill: kill `cat ~/Coding/myscript/play_error_sound.pid`
status: ps aux | grep play_error_sound
or cat ~/Coding/myscript/play_error_sound.pid
*/

declare(ticks = 1);
date_default_timezone_set('Asia/Shanghai');

// 配置项
$config = [
    'port' => 9123,
    'logFile' => __DIR__ . '/play_error_sound.log',
    'maxLogSize' => 10 * 1024 * 1024,
    'maxLines' => 10000,
    'cleanStrategy' => 'size',
    'enableSound' => true,
    'soundFile' => '/System/Library/Sounds/Ping.aiff',
    'bufferSize' => 2048,
    'timeFormat' => 'Y-m-d H:i:s',
    'pidFile' => __DIR__ . '/play_error_sound.pid',
];

// 守护进程化
function daemonize() {
    // 1. 创建子进程
    $pid = pcntl_fork();
    if ($pid == -1) {
        die("Error: Can't fork process\n");
    } else if ($pid > 0) {
        // 父进程退出
        exit(0);
    }

    // 2. 设置新会话组长
    if (posix_setsid() == -1) {
        die("Error: Can't setsid()\n");
    }

    // 3. 再次fork以确保进程不是会话组长
    $pid = pcntl_fork();
    if ($pid == -1) {
        die("Error: Can't fork process\n");
    } else if ($pid > 0) {
        exit(0);
    }

    // 4. 修改工作目录
    chdir('/');

    // 5. 重设文件掩码
    umask(0);

    // 6. 关闭标准输入输出和错误输出
    fclose(STDIN);
    fclose(STDOUT);
    fclose(STDERR);

    // 重新打开标准输入输出和错误输出到/dev/null
    $stdIn = fopen('/dev/null', 'r');
    $stdOut = fopen('/dev/null', 'w');
    $stdErr = fopen('/dev/null', 'w');
}

// 启动守护进程
daemonize();

// 信号处理
pcntl_signal(SIGTERM, 'signalHandler');
pcntl_signal(SIGHUP,  'signalHandler');
pcntl_signal(SIGINT,  'signalHandler');

function signalHandler($signal) {
    global $sock, $config;
    switch ($signal) {
        case SIGTERM:
        case SIGINT:
        case SIGHUP:
            @socket_close($sock);
            @unlink($config['pidFile']);
            exit(0);
    }
}

// 写入PID文件
file_put_contents($config['pidFile'], getmypid());

// 创建socket
$sock = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
if (!$sock) {
    error_log("Failed to create socket\n", 3, $config['logFile']);
    exit(1);
}

// 设置socket选项
socket_set_option($sock, SOL_SOCKET, SO_REUSEADDR, 1);
if (!socket_bind($sock, '0.0.0.0', $config['port'])) {
    error_log("Failed to bind socket\n", 3, $config['logFile']);
    exit(1);
}

if (!socket_listen($sock)) {
    error_log("Failed to listen socket\n", 3, $config['logFile']);
    exit(1);
}

error_log("Listening on port {$config['port']}...\n", 3, $config['logFile']);

// 设置非阻塞模式
socket_set_nonblock($sock);

while (true) {
    $conn = @socket_accept($sock);
    if ($conn) {
        $buf = '';
        socket_recv($conn, $buf, $config['bufferSize'], 0);
        
        if (!empty($buf)) {
            $logMessage = '[' . date($config['timeFormat']) . '] ' . trim($buf) . "\n";
            
            // 根据策略清理日志
            if ($config['cleanStrategy'] === 'size') {
                if (file_exists($config['logFile']) && filesize($config['logFile']) > $config['maxLogSize']) {
                    file_put_contents($config['logFile'], '');
                }
                file_put_contents($config['logFile'], $logMessage, FILE_APPEND);
            } else {
                if (file_exists($config['logFile'])) {
                    $lines = file($config['logFile']);
                    if (count($lines) >= $config['maxLines']) {
                        $lines = array_slice($lines, -(($config['maxLines'] - 1)));
                        $lines[] = $logMessage;
                        file_put_contents($config['logFile'], implode('', $lines));
                    } else {
                        file_put_contents($config['logFile'], $logMessage, FILE_APPEND);
                    }
                } else {
                    file_put_contents($config['logFile'], $logMessage, FILE_APPEND);
                }
            }
            
            // 播放声音
            if ($config['enableSound']) {
                shell_exec('afplay ' . $config['soundFile'] . ' > /dev/null 2>&1 &');
            }
        }
        
        socket_close($conn);
    }
    
    // 避免CPU占用过高
    usleep(100000); // 休眠0.1秒
}
