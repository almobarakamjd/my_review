<?php
header("Content-Type: application/json; charset=UTF-8");

// 1. Database Connection
$host = "localhost"; 
$db_name = "u317488478_db_schema"; 
$username = "u317488478_db_schema";
$password = "@#Aa!@EDd1";

try {
    $conn = new PDO("mysql:host=" . $host . ";dbname=" . $db_name . ";charset=utf8", $username, $password);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "Connected to DB...<br>";
} catch(PDOException $exception) {
    die("Connection failed: " . $exception->getMessage());
}

// 2. Read JSON file
// You can change this to 'quiz/6th/tajweed.json' or whatever file you want to import
$json_file = 'quiz/6th/tajweed.json'; 

// Check if file exists relative to this script
if (!file_exists($json_file)) {
    // Try looking in current dir for simple filename if full path fails
    $json_file = 'tajweed.json';
    if (!file_exists($json_file)) {
         die("Error: JSON file not found.");
    }
}

$json_data = file_get_contents($json_file);
$questions = json_decode($json_data, true);

if (!$questions) {
    die("Error: Failed to decode JSON.");
}

echo "JSON loaded. Inserting data...<br>";

// 3. Insert Data
// Updated query to include new columns
$sql = "INSERT INTO questions (grade_level, subject, question_text, options, correct_answer, explanation, verse_text, highlight_text) 
        VALUES (:grade, :subject, :q_text, :opts, :correct, :exp, :v_text, :hl_text)";

$stmt = $conn->prepare($sql);

$count = 0;
foreach ($questions as $q) {
    // Determine correct answer from 'ans' index
    $correct_option = $q['opts'][$q['ans']] ?? '';

    // Encode options
    $options_json = json_encode($q['opts'] ?? [], JSON_UNESCAPED_UNICODE);

    $grade = "6th"; 
    $subject = "tajweed"; 

    // Extract new fields if they exist
    $explanation = $q['exp'] ?? '';
    $verse_text = $q['text'] ?? '';
    $highlight_text = $q['highlight'] ?? '';
    $question_text = $q['q'] ?? '';

    $stmt->bindParam(':grade', $grade);
    $stmt->bindParam(':subject', $subject);
    $stmt->bindParam(':q_text', $question_text);
    $stmt->bindParam(':opts', $options_json);
    $stmt->bindParam(':correct', $correct_option);
    $stmt->bindParam(':exp', $explanation);
    $stmt->bindParam(':v_text', $verse_text);
    $stmt->bindParam(':hl_text', $highlight_text);

    if ($stmt->execute()) {
        $count++;
    }
}

echo "Successfully inserted " . $count . " questions into database.";
?>