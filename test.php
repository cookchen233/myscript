<?php
$sock = socket_create_listen(9123);
while(true) {
    $conn = socket_accept($sock);
    shell_exec('afplay /System/Library/Sounds/Ping.aiff');
    socket_close($conn);
}