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
    }

    // 计算两个时间范围内的重叠分钟数
    function getOverlapMinutes($rangeStart, $rangeEnd, $intervalStart, $intervalEnd) {
        $start = max($rangeStart, $intervalStart);
        $end = min($rangeEnd, $intervalEnd);
        return max(0, $end - $start);
    }

    // 计算单天内某个时间段的有效分钟数
    function calculateDayMinutes($startMinutes, $endMinutes, $timeRanges) {
        $totalMinutes = 0;
        foreach ($timeRanges as $range) {
            list($rangeStart, $rangeEnd) = $range;
            $totalMinutes += getOverlapMinutes($startMinutes, $endMinutes, $rangeStart, $rangeEnd);
        }
        return $totalMinutes;
    }

    // 处理单个日期的有效分钟数
    function handleSingleDay($date, $startMinutes, $endMinutes, $timeRanges) {
        return calculateDayMinutes($startMinutes, $endMinutes, $timeRanges);
    }

    // 处理跨多天的有效分钟数
    function handleMultipleDays($startDate, $endDate, $timeRanges) {
        $totalMinutes = 0;
        $currentDate = $startDate;

        // 计算开始当天的有效分钟数
        $totalMinutes += handleSingleDay($currentDate, date('G', $currentDate) * 60 + date('i', $currentDate), 24 * 60, $timeRanges);

        // 处理中间的完整天数
        $currentDate = strtotime('+1 day', $currentDate);
        while (date('Y-m-d', $currentDate) != date('Y-m-d', $endDate)) {
            $totalMinutes += handleSingleDay($currentDate, 0, 24 * 60, $timeRanges);
            $currentDate = strtotime('+1 day', $currentDate);
        }

        // 计算截止日期的有效分钟数
        $totalMinutes += handleSingleDay($endDate, 0, date('G', $endDate) * 60 + date('i', $endDate), $timeRanges);

        return $totalMinutes;
    }

    // 计算总的有效分钟数
    function calculateTotalMinutes($currentTime, $deadlineTime, $timeRanges) {
        $startDate = $currentTime;
        $endDate = $deadlineTime;

        if (date('Y-m-d', $startDate) === date('Y-m-d', $endDate)) {
            // 同一天的情况
            $startMinutes = date('G', $startDate) * 60 + date('i', $startDate);
            $endMinutes = date('G', $endDate) * 60 + date('i', $endDate);
            return handleSingleDay($startDate, $startMinutes, $endMinutes, $timeRanges);
        } else {
            // 跨天的情况
            return handleMultipleDays($startDate, $endDate, $timeRanges);
        }
    }

    // 主函数
    function cacu() {
        $deadlineStr = isset($_GET['deadline']) ? $_GET['deadline'] : null;
        if (!$deadlineStr) {
            return '请在地址栏提供有效的deadline参数。';
        }

        $deadline = parseDeadline($deadlineStr);
        if (!$deadline) {
            return '日期格式无效，请检查输入。'. $deadlineStr;
        }

        $currentTime = time();
        $timeRanges = [
            [parseTimeString("07:50"), parseTimeString("08:30")],
            [parseTimeString("08:40"), parseTimeString("09:20")],
            [parseTimeString("09:30"), parseTimeString("10:20")],
            [parseTimeString("10:40"), parseTimeString("11:50")],
            [parseTimeString("13:00"), parseTimeString("14:30")],
            [parseTimeString("14:40"), parseTimeString("15:40")],
            [parseTimeString("16:00"), parseTimeString("17:10")],
            [parseTimeString("17:20"), parseTimeString("18:00")],
            [parseTimeString("19:30"), parseTimeString("20:30")],
            [parseTimeString("21:00"), parseTimeString("22:00")]
        ];

        return calculateTotalMinutes($currentTime, $deadline, $timeRanges);
        
    }

    echo '<h2 id="result">'.cacu().'</h2>';
    ?>
    <script>
        setInterval(() => {
            location.reload()
        }, 60000);
    </script>

</body>

</html>