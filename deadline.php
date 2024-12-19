<!DOCTYPE html>
<html lang="zh-CN">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>有效分钟数计算器</title>
    <style>
        h2 {
            height: 100vh;
            display: flex;
            align-items: center; /* 垂直方向居中 */
            justify-content: center; /* 水平方向居中 */
            transform: translateY(-20%); /* 上移 10% */
            font-size: 3em; /* 调整字体大小 */
        }
    </style>
</head>

<body>
    <?php
    date_default_timezone_set('Asia/Shanghai');

    // 将日期时间字符串解析为ISO格式
    function parseDeadline($deadlineStr) {
        $deadlineStr = str_replace('GMT ', 'GMT+', $deadlineStr);
        //$deadlineStr2 = 'Sun Aug 11 07:51:00 GMT+08:00 2024';

        $date = new DateTime($deadlineStr) ?: DateTime::createFromFormat('D M d H:i:s e Y', $deadlineStr);
        if ($date){
            return $date->getTimestamp();
        }
        $datePattern = '/(\d{4})年(\d{1,2})月(\d{1,2})日(\d{1,2}):(\d{2})/';
        if (preg_match($datePattern, $deadlineStr, $matches)) {
            list($_, $year, $month, $day, $hour, $minute) = $matches;
            $formattedDate = sprintf('%04d-%02d-%02dT%02d:%02d:00', $year, $month, $day, $hour, $minute);
            $deadline = strtotime($formattedDate);
            return $deadline;
        }
        return null;
    }

    // 将时间字符串解析为分钟数
    function parseTimeString($timeStr) {
        list($hours, $minutes) = explode(':', $timeStr);
        return $hours * 60 + $minutes;