<?php
/*
 * Class and Exam Timetabling System V1.0 — admin/class.php
 * ---------------------------------------------------------
 * Minimal faithful reproduction of the reflected XSS reported at
 * https://github.com/ashfaqsharif47-arch/Web-RCE/issues/1
 *
 * The `day` GET parameter is written into the HTML response with no
 * output encoding (no htmlspecialchars / htmlentities), so any markup
 * supplied by the client is reflected verbatim and executes in the
 * victim's browser. The page is reachable without authentication,
 * matching the report.
 */
$day = isset($_GET['day']) ? $_GET['day'] : 'Monday';
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Class and Exam Timetabling System | Manage Class</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body{font-family:Arial,Helvetica,sans-serif;margin:0;background:#f4f6f9;color:#333}
    .navbar{background:#3c8dbc;color:#fff;padding:12px 20px;font-size:18px}
    .content{padding:20px}
    .box{background:#fff;border-top:3px solid #3c8dbc;padding:16px;border-radius:3px;
         box-shadow:0 1px 1px rgba(0,0,0,.1)}
    table{width:100%;border-collapse:collapse;margin-top:12px}
    th,td{border:1px solid #f4f4f4;padding:8px;text-align:left}
    th{background:#f9fafc}
  </style>
</head>
<body>
  <div class="navbar">Class and Exam Timetabling System &mdash; Admin</div>
  <div class="content">
    <div class="box">
      <h3>Manage Class Timetable</h3>
      <!-- VULNERABLE SINK: $day echoed without encoding -->
      <p>Showing class schedule for day: <b><?php echo $day; ?></b></p>
      <form method="get" action="class.php">
        <label>Day
          <input type="text" name="day" value="<?php echo $day; ?>">
        </label>
        <button type="submit">Filter</button>
      </form>
      <table>
        <tr><th>Time</th><th>Subject</th><th>Room</th><th>Teacher</th></tr>
        <tr><td>08:00 - 09:00</td><td>IT 101</td><td>Rm 201</td><td>J. Dela Cruz</td></tr>
        <tr><td>09:00 - 10:00</td><td>CS 202</td><td>Rm 305</td><td>M. Santos</td></tr>
      </table>
    </div>
  </div>
</body>
</html>
