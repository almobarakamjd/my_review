<?php
header('Content-Type: text/plain');

$host = "localhost"; 
$db_name = "u317488478_db_schema"; 
$username = "u317488478_db_schema";
$password = "@#Aa!@EDd1";

try {
    $conn = new PDO("mysql:host=" . $host . ";dbname=" . $db_name . ";charset=utf8", $username, $password);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "Connected successfully\n";

    // Add columns if they don't exist
    $sql = "
    ALTER TABLE questions 
    ADD COLUMN IF NOT EXISTS explanation TEXT,
    ADD COLUMN IF NOT EXISTS verse_text TEXT,
    ADD COLUMN IF NOT EXISTS highlight_text VARCHAR(255);
    ";

    $conn->exec($sql);
    echo "Table 'questions' altered successfully.\n";

} catch(PDOException $e) {
    echo "Connection failed: " . $e->getMessage();
}
?>