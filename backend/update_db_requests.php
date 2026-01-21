<?php
header('Content-Type: text/plain');

$host = "localhost";
// Try using the same credentials as api.php
$db_name   = "u317488478_db_schema";
$username   = "u317488478_db_schema";
$password   = "@#Aa!@EDd1";

// If you are running locally with XAMPP default, uncomment this:
// $username = "root"; $password = "";

try {
    $conn = new PDO("mysql:host=" . $host . ";dbname=" . $db_name . ";charset=utf8", $username, $password);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "Connected successfully\n";

    // Add request_status column to users table
    $sql = "
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS request_status ENUM('none', 'exit_pending', 'unlock_pending', 'exit_approved', 'unlock_approved') DEFAULT 'none';
    ";

    $conn->exec($sql);
    echo "Column 'request_status' added successfully to 'users' table.\n";

} catch(PDOException $e) {
    echo "Connection failed: " . $e->getMessage();
}
?>
