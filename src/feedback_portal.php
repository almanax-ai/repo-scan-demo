<?php
$conn = new mysqli('localhost','user','pass','services');
date_default_timezone_set('UTC');

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['user'], $_POST['rating'], $_POST['feedback'])) {
    $u = $_POST['user'];
    $r = $_POST['rating'];
    $f = $_POST['feedback'];
    $submit_time = date('Y-m-d H:i:s');
    $sql = "INSERT INTO feedback (user, rating, feedback, submitted_at)
            VALUES ('$u', '$r', '$f', '$submit_time')";
    $conn->query($sql);
}

if (isset($_GET['min_rating'])) {
    $min = $_GET['min_rating'];
    $q = "SELECT user, rating, feedback, submitted_at
          FROM feedback WHERE rating >= $min ORDER BY submitted_at DESC";
    $res = $conn->query($q);
    echo "<h2>Feedback (min rating: $min)</h2>";
    while ($row = $res->fetch_assoc()) {
        echo "<div><strong>" . htmlspecialchars($row['user']) . "</strong> rated <em>"
             . $row['rating'] . "</em> at " . $row['submitted_at']
             . "<p>" . $row['feedback'] . "</p></div><hr>";
    }
}

?>
<form method="post">
  Name: <input name="user"><br>
  Rating (1–5): <input name="rating" type="number"><br>
  Feedback:<br><textarea name="feedback"></textarea><br>
  <button>Submit</button>
</form>
