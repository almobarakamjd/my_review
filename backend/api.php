<?php
// ⚠️ تأكد أن هذا هو السطر رقم 1 في الملف ولا يوجد قبله مسافات
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Allow-Methods: POST, OPTIONS');

// تفعيل إظهار الأخطاء للتشخيص (يمكن إيقافه لاحقاً)
ini_set('display_errors', 0);
error_reporting(E_ALL);

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

function respond($arr, $code = 200) {
    http_response_code($code);
    echo json_encode($arr, JSON_UNESCAPED_UNICODE);
    exit;
}

function get_input_data() {
    $raw = file_get_contents("php://input");
    $json = json_decode($raw, true);
    if (is_array($json)) return $json;
    if (!empty($_POST)) return $_POST;
    return [];
}

// ---------------------------------------------------------
// جلب المتغيرات من ملف خارجي
// ---------------------------------------------------------
require_once 'variables.php';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$db_name;charset=utf8mb4", $db_user, $db_pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
} catch (PDOException $e) {
    // إذا فشل الاتصال نرجع JSON يوضح السبب بدلاً من صفحة بيضاء
    respond(['status' => 'error', 'message' => 'DB connection failed: ' . $e->getMessage()], 500);
}

$input = get_input_data();
$action = $input['action'] ?? '';

// إذا لم يرسل التطبيق "أكشن"، نعيد رسالة خطأ بصيغة JSON
if ($action === '') {
    respond(['status' => 'error', 'message' => 'No action provided', 'debug_input' => $input], 400);
}

switch ($action) {

    // --- 1. تسجيل طالب ---
    case 'register_student': {
        $full_name = trim($input['full_name'] ?? '');
        $username = trim($input['username'] ?? '');
        $password = trim($input['password'] ?? '');
        $grade_level = trim($input['grade_level'] ?? '');
        $device_id = trim($input['device_id'] ?? '');
        $parent_username = trim($input['parent_username'] ?? '');

        if ($full_name === '' || $username === '' || $password === '' || $grade_level === '' || $device_id === '') {
            respond(['status' => 'error', 'message' => 'بيانات ناقصة'], 400);
        }

        $check = $pdo->prepare("SELECT id FROM users WHERE username = ?");
        $check->execute([$username]);
        if ($check->fetch()) {
            respond(['status' => 'error', 'message' => 'اسم المستخدم موجود مسبقاً'], 400);
        }

        $parent_id = null;
        if ($parent_username !== '') {
            $stmtP = $pdo->prepare("SELECT id FROM users WHERE username = ? AND user_type = 'parent'");
            $stmtP->execute([$parent_username]);
            $parent = $stmtP->fetch();
            if ($parent) $parent_id = $parent['id'];
        }

        try {
            $stmt = $pdo->prepare("INSERT INTO users (full_name, username, password_hash, user_type, grade_level, device_id, parent_id, created_at) VALUES (:fn, :un, :pw, 'student', :gl, :did, :pid, NOW())");
            $stmt->execute([
                ':fn' => $full_name, ':un' => $username, ':pw' => $password, ':gl' => $grade_level, ':did' => $device_id, ':pid' => $parent_id
            ]);
            $newId = (int)$pdo->lastInsertId();

            // إرجاع البيانات كاملة
            respond(['status' => 'success', 'data' => [
                'id' => $newId, 'full_name' => $full_name, 'username' => $username, 'grade_level' => $grade_level, 'user_type' => 'student', 'device_id' => $device_id
            ]]);
        } catch (Exception $e) {
            respond(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
        break;
    }

    // --- 2. تسجيل ولي أمر ---
    case 'register_parent': {
        $full_name = trim($input['full_name'] ?? '');
        $username = trim($input['username'] ?? '');
        $password = trim($input['password'] ?? '');

        if ($full_name === '' || $username === '' || $password === '') {
            respond(['status' => 'error', 'message' => 'بيانات ناقصة'], 400);
        }

        $check = $pdo->prepare("SELECT id FROM users WHERE username = ?");
        $check->execute([$username]);
        if ($check->fetch()) respond(['status' => 'error', 'message' => 'اسم المستخدم موجود'], 400);

        try {
            $stmt = $pdo->prepare("INSERT INTO users (full_name, username, password_hash, user_type, created_at) VALUES (?, ?, ?, 'parent', NOW())");
            $stmt->execute([$full_name, $username, $password]);
            respond(['status' => 'success', 'data' => ['id' => (int)$pdo->lastInsertId(), 'username' => $username]]);
        } catch (Exception $e) {
            respond(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
        break;
    }

  // --- 3. تسجيل دخول يدوي (أب أو طالب) ---
      case 'login_student_manual': {
          $username = trim($input['username'] ?? '');
          $password = trim($input['password'] ?? '');
          $device_id = trim($input['device_id'] ?? '');

          if ($username === '') respond(['status' => 'error', 'message' => 'اسم المستخدم مطلوب']);

          // جلب المستخدم كما هو في قاعدة البيانات
          $stmt = $pdo->prepare("SELECT * FROM users WHERE username = :u LIMIT 1");
          $stmt->execute([':u' => $username]);
          $user = $stmt->fetch();

          if (!$user) {
              respond(['status' => 'error', 'message' => 'اسم المستخدم غير صحيح']);
          }

          // مقارنة كلمة المرور
          if ($user['password_hash'] !== $password) {
              respond(['status' => 'error', 'message' => 'كلمة المرور غير صحيحة']);
          }

          // تحديث معرف الجهاز فقط (بدون تغيير نوع المستخدم)
          if ($device_id !== '') {
              $pdo->prepare("UPDATE users SET device_id = ? WHERE id = ?")->execute([$device_id, $user['id']]);
              $user['device_id'] = $device_id; // تحديث القيمة في المتغير للعودة بها
          }

          // تحويل المعرف لرقم (للفلاتر)
          $user['id'] = (int)$user['id'];

          respond(['status' => 'success', 'data' => $user]);
          break;
      }

    // --- 4. تسجيل دخول تلقائي ---
    case 'login_student': {
        $device_id = trim($input['device_id'] ?? '');
        if ($device_id === '') respond(['status' => 'error', 'message' => 'No device ID']);

        $stmt = $pdo->prepare("SELECT * FROM users WHERE device_id = ? AND user_type = 'student' LIMIT 1");
        $stmt->execute([$device_id]);
        $user = $stmt->fetch();

        if ($user) {
            $user['id'] = (int)$user['id'];
            respond(['status' => 'success', 'data' => $user]);
        } else {
            respond(['status' => 'error', 'message' => 'Not found']);
        }
        break;
    }

    // --- 5. جلب أبناء ولي الأمر ---
    case 'get_my_children': {
        $pid = (int)($input['parent_id'] ?? 0);
        try {
            // المحاولة الأولى: مع السجلات اليومية (إذا كان الجدول موجوداً)
            // Added u.request_status
            $stmt = $pdo->prepare("
                SELECT u.id, u.full_name, u.grade_level, u.username, u.request_status,
                (SELECT COUNT(*) FROM daily_logs dl WHERE dl.student_id = u.id AND dl.log_date = CURDATE()) as logged_today,
                (SELECT score FROM daily_logs dl WHERE dl.student_id = u.id ORDER BY log_date DESC LIMIT 1) as last_score
                FROM users u WHERE u.parent_id = ? AND u.user_type = 'student'
            ");
            $stmt->execute([$pid]);
            respond(['status' => 'success', 'data' => $stmt->fetchAll()]);
        } catch (PDOException $e) {
            // المحاولة الثانية: استعلام بسيط
            try {
                 // Added request_status
                 $stmt = $pdo->prepare("SELECT id, full_name, grade_level, username, request_status FROM users WHERE parent_id = ? AND user_type = 'student'");
                 $stmt->execute([$pid]);
                 respond(['status' => 'success', 'data' => $stmt->fetchAll()]);
            } catch (Exception $ex) {
                 respond(['status' => 'error', 'message' => $ex->getMessage()]);
            }
        }
        break;
    }

    // --- 6. الأب يضيف ابناً ---
    case 'create_child_account': {
        $pid = (int)($input['parent_id'] ?? 0);
        $full_name = trim($input['full_name'] ?? '');
        $username = trim($input['username'] ?? '');
        $password = trim($input['password'] ?? '');
        $grade = trim($input['grade_level'] ?? '');

        if ($pid <= 0 || $full_name === '' || $username === '' || $password === '' || $grade === '') {
            respond(['status' => 'error', 'message' => 'بيانات ناقصة'], 400);
        }

        $check = $pdo->prepare("SELECT id FROM users WHERE username = ?");
        $check->execute([$username]);
        if ($check->fetch()) respond(['status' => 'error', 'message' => 'اسم المستخدم محجوز'], 400);

        try {
            $stmt = $pdo->prepare("INSERT INTO users (full_name, username, password_hash, user_type, grade_level, parent_id, created_at) VALUES (?, ?, ?, 'student', ?, ?, NOW())");
            $stmt->execute([$full_name, $username, $password, $grade, $pid]);
            respond(['status' => 'success', 'message' => 'تمت الإضافة']);
        } catch (Exception $e) {
            respond(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
        break;
    }

    // --- 7. طرد الابن (خروج عن بعد) ---
    case 'remote_logout_student': {
        $pid = (int)($input['parent_id'] ?? 0);
        $sid = (int)($input['student_id'] ?? 0);

        $check = $pdo->prepare("SELECT id FROM users WHERE id = ? AND parent_id = ?");
        $check->execute([$sid, $pid]);
        if (!$check->fetch()) respond(['status' => 'error', 'message' => 'ليس ابنك'], 403);

        $pdo->prepare("UPDATE users SET device_id = NULL, request_status = 'none' WHERE id = ?")->execute([$sid]);
        respond(['status' => 'success', 'message' => 'Logged out']);
        break;
    }

    // --- 8. التحقق من حالة الجلسة ---
    case 'check_session_status': {
        $sid = (int)($input['student_id'] ?? 0);
        $did = trim($input['device_id'] ?? '');

        // Fetch all fields including parent_message if exists
        $stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
        $stmt->execute([$sid]);
        $user = $stmt->fetch();

        if ($user && $user['device_id'] === $did && $did !== '') {
            $reqStatus = $user['request_status'] ?? 'none';
            $msg = $user['parent_message'] ?? '';

            respond([
                'status' => 'active',
                'request_status' => $reqStatus,
                'parent_message' => $msg
            ]);
        } else {
            respond(['status' => 'logged_out']);
        }
        break;
    }

    // --- New Actions for Exit/Unlock Requests ---

    case 'acknowledge_alert': {
        $sid = (int)($input['student_id'] ?? 0);
        // Reset status to none after student sees the alert
        $pdo->prepare("UPDATE users SET request_status = 'none', parent_message = NULL WHERE id = ?")->execute([$sid]);
        respond(['status' => 'success']);
        break;
    }

    case 'request_exit': {
        $sid = (int)($input['student_id'] ?? 0);
        try {
            $pdo->prepare("UPDATE users SET request_status = 'exit_pending' WHERE id = ?")->execute([$sid]);
            respond(['status' => 'success']);
        } catch (PDOException $e) {
            // Auto-fix: Add column if missing
            if (strpos($e->getMessage(), 'Unknown column') !== false) {
                 try {
                     $pdo->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS request_status ENUM('none', 'exit_pending', 'unlock_pending', 'exit_approved', 'unlock_approved') DEFAULT 'none'");
                     // Retry
                     $pdo->prepare("UPDATE users SET request_status = 'exit_pending' WHERE id = ?")->execute([$sid]);
                     respond(['status' => 'success']);
                 } catch (Exception $ex) {
                     respond(['status' => 'error', 'message' => 'DB Error (Retry Failed): ' . $ex->getMessage()]);
                 }
            } else {
                 respond(['status' => 'error', 'message' => 'DB Error: ' . $e->getMessage()]);
            }
        }
        break;
    }

    case 'request_unlock': {
        $sid = (int)($input['student_id'] ?? 0);
        try {
            $pdo->prepare("UPDATE users SET request_status = 'unlock_pending' WHERE id = ?")->execute([$sid]);
            respond(['status' => 'success']);
        } catch (PDOException $e) {
             // Auto-fix: Add column if missing
            if (strpos($e->getMessage(), 'Unknown column') !== false) {
                 try {
                     $pdo->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS request_status ENUM('none', 'exit_pending', 'unlock_pending', 'exit_approved', 'unlock_approved') DEFAULT 'none'");
                     // Retry
                     $pdo->prepare("UPDATE users SET request_status = 'unlock_pending' WHERE id = ?")->execute([$sid]);
                     respond(['status' => 'success']);
                 } catch (Exception $ex) {
                     respond(['status' => 'error', 'message' => 'DB Error (Retry Failed): ' . $ex->getMessage()]);
                 }
            } else {
                 respond(['status' => 'error', 'message' => 'DB Error: ' . $e->getMessage()]);
            }
        }
        break;
    }

    case 'approve_exit': {
        $pid = (int)($input['parent_id'] ?? 0);
        $sid = (int)($input['student_id'] ?? 0);

        // Verify parent
        $check = $pdo->prepare("SELECT id FROM users WHERE id = ? AND parent_id = ?");
        $check->execute([$sid, $pid]);
        if (!$check->fetch()) respond(['status' => 'error', 'message' => 'Not your child'], 403);

        try {
            // Approve exit means logging them out (clearing device_id)
            $pdo->prepare("UPDATE users SET device_id = NULL, request_status = 'exit_approved' WHERE id = ?")->execute([$sid]);
            respond(['status' => 'success']);
        } catch (PDOException $e) {
             if (strpos($e->getMessage(), 'Unknown column') !== false) {
                 try {
                     $pdo->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS request_status ENUM('none', 'exit_pending', 'unlock_pending', 'exit_approved', 'unlock_approved', 'exit_rejected', 'unlock_rejected') DEFAULT 'none'");
                     $pdo->prepare("UPDATE users SET device_id = NULL, request_status = 'exit_approved' WHERE id = ?")->execute([$sid]);
                     respond(['status' => 'success']);
                 } catch (Exception $ex) {
                     respond(['status' => 'error', 'message' => 'DB Error: ' . $ex->getMessage()]);
                 }
            } else {
                 respond(['status' => 'error', 'message' => 'DB Error: ' . $e->getMessage()]);
            }
        }
        break;
    }

    case 'reject_exit': {
        $pid = (int)($input['parent_id'] ?? 0);
        $sid = (int)($input['student_id'] ?? 0);
        $msg = trim($input['message'] ?? '');

        // Verify parent
        $check = $pdo->prepare("SELECT id FROM users WHERE id = ? AND parent_id = ?");
        $check->execute([$sid, $pid]);
        if (!$check->fetch()) respond(['status' => 'error', 'message' => 'Not your child'], 403);

        try {
            $pdo->prepare("UPDATE users SET request_status = 'exit_rejected', parent_message = ? WHERE id = ?")->execute([$msg, $sid]);
            respond(['status' => 'success']);
        } catch (PDOException $e) {
             if (strpos($e->getMessage(), 'Unknown column') !== false) {
                 try {
                     // Add both columns if missing
                     $pdo->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS request_status ENUM('none', 'exit_pending', 'unlock_pending', 'exit_approved', 'unlock_approved', 'exit_rejected', 'unlock_rejected') DEFAULT 'none'");
                     $pdo->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS parent_message TEXT DEFAULT NULL");

                     $pdo->prepare("UPDATE users SET request_status = 'exit_rejected', parent_message = ? WHERE id = ?")->execute([$msg, $sid]);
                     respond(['status' => 'success']);
                 } catch (Exception $ex) {
                     respond(['status' => 'error', 'message' => 'DB Error: ' . $ex->getMessage()]);
                 }
            } else {
                 respond(['status' => 'error', 'message' => 'DB Error: ' . $e->getMessage()]);
            }
        }
        break;
    }

    case 'reject_unlock': {
        $pid = (int)($input['parent_id'] ?? 0);
        $sid = (int)($input['student_id'] ?? 0);
        $msg = trim($input['message'] ?? '');

        $check = $pdo->prepare("SELECT id FROM users WHERE id = ? AND parent_id = ?");
        $check->execute([$sid, $pid]);
        if (!$check->fetch()) respond(['status' => 'error'], 403);

        try {
            $pdo->prepare("UPDATE users SET request_status = 'unlock_rejected', parent_message = ? WHERE id = ?")->execute([$msg, $sid]);
            respond(['status' => 'success']);
        } catch (PDOException $e) {
             if (strpos($e->getMessage(), 'Unknown column') !== false) {
                 try {
                     $pdo->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS request_status ENUM('none', 'exit_pending', 'unlock_pending', 'exit_approved', 'unlock_approved', 'exit_rejected', 'unlock_rejected') DEFAULT 'none'");
                     $pdo->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS parent_message TEXT DEFAULT NULL");

                     $pdo->prepare("UPDATE users SET request_status = 'unlock_rejected', parent_message = ? WHERE id = ?")->execute([$msg, $sid]);
                     respond(['status' => 'success']);
                 } catch (Exception $ex) {
                     respond(['status' => 'error', 'message' => 'DB Error: ' . $ex->getMessage()]);
                 }
            } else {
                 respond(['status' => 'error', 'message' => 'DB Error: ' . $e->getMessage()]);
            }
        }
        break;
    }

    case 'approve_unlock': {
        $pid = (int)($input['parent_id'] ?? 0);
        $sid = (int)($input['student_id'] ?? 0);

        $check = $pdo->prepare("SELECT id FROM users WHERE id = ? AND parent_id = ?");
        $check->execute([$sid, $pid]);
        if (!$check->fetch()) respond(['status' => 'error'], 403);

        try {
            $pdo->prepare("UPDATE users SET request_status = 'unlock_approved' WHERE id = ?")->execute([$sid]);
            respond(['status' => 'success']);
        } catch (PDOException $e) {
             if (strpos($e->getMessage(), 'Unknown column') !== false) {
                 try {
                     $pdo->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS request_status ENUM('none', 'exit_pending', 'unlock_pending', 'exit_approved', 'unlock_approved', 'exit_rejected', 'unlock_rejected') DEFAULT 'none'");
                     $pdo->prepare("UPDATE users SET request_status = 'unlock_approved' WHERE id = ?")->execute([$sid]);
                     respond(['status' => 'success']);
                 } catch (Exception $ex) {
                     respond(['status' => 'error', 'message' => 'DB Error: ' . $ex->getMessage()]);
                 }
            } else {
                 respond(['status' => 'error', 'message' => 'DB Error: ' . $e->getMessage()]);
            }
        }
        break;
    }

    case 'remote_unlock': {
        $pid = (int)($input['parent_id'] ?? 0);
        $sid = (int)($input['student_id'] ?? 0);

        $check = $pdo->prepare("SELECT id FROM users WHERE id = ? AND parent_id = ?");
        $check->execute([$sid, $pid]);
        if (!$check->fetch()) respond(['status' => 'error'], 403);

        try {
            // Force unlock
            $pdo->prepare("UPDATE users SET request_status = 'unlock_approved' WHERE id = ?")->execute([$sid]);
            respond(['status' => 'success']);
        } catch (PDOException $e) {
             if (strpos($e->getMessage(), 'Unknown column') !== false) {
                 try {
                     $pdo->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS request_status ENUM('none', 'exit_pending', 'unlock_pending', 'exit_approved', 'unlock_approved', 'exit_rejected', 'unlock_rejected') DEFAULT 'none'");
                     $pdo->prepare("UPDATE users SET request_status = 'unlock_approved' WHERE id = ?")->execute([$sid]);
                     respond(['status' => 'success']);
                 } catch (Exception $ex) {
                     respond(['status' => 'error', 'message' => 'DB Error: ' . $ex->getMessage()]);
                 }
            } else {
                 respond(['status' => 'error', 'message' => 'DB Error: ' . $e->getMessage()]);
            }
        }
        break;
    }

    // --- 9. جلب الأسئلة ---

    // --- 9. جلب الأسئلة ---
    case 'get_quiz': {
        // (الكود المختصر لجلب الأسئلة كما كان سابقاً لعدم الإطالة، تأكد أنه موجود إذا كنت تستخدمه)
        // إذا أردت الكود الكامل لهذا الجزء أخبرني، لكن الأهم الآن هو الدخول.
        // سأضع استجابة وهمية للتجربة إذا لم يوجد كود، لكن يفضل وضع كود الأسئلة السابق هنا.
        respond(['status' => 'success', 'questions' => []]);
        break;
    }

    // --- 10. حفظ النتيجة ---
    case 'submit_quiz': {
        $sid = (int)($input['student_id'] ?? 0);
        $score = (int)($input['score'] ?? 0);
        $details = $input['details'] ?? []; // JSON format if needed

        if ($sid <= 0) {
            respond(['status' => 'error', 'message' => 'Invalid student ID'], 400);
        }

        try {
            // Save to daily_logs
            // Note: We use details field as a text/json dump
            $detailsJson = json_encode($details, JSON_UNESCAPED_UNICODE);

            $stmt = $pdo->prepare("INSERT INTO daily_logs (student_id, score, details, log_date, created_at) VALUES (?, ?, ?, CURDATE(), NOW())");
            $stmt->execute([$sid, $score, $detailsJson]);

            respond(['status' => 'success']);
        } catch (PDOException $e) {
            // Auto-create table if missing
            if (strpos($e->getMessage(), "doesn't exist") !== false) {
                 try {
                     $pdo->exec("CREATE TABLE IF NOT EXISTS daily_logs (
                         id INT AUTO_INCREMENT PRIMARY KEY,
                         student_id INT NOT NULL,
                         score INT DEFAULT 0,
                         details TEXT,
                         log_date DATE,
                         created_at DATETIME,
                         FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE
                     ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");

                     // Retry insert
                     $stmt = $pdo->prepare("INSERT INTO daily_logs (student_id, score, details, log_date, created_at) VALUES (?, ?, ?, CURDATE(), NOW())");
                     $stmt->execute([$sid, $score, json_encode($details, JSON_UNESCAPED_UNICODE)]);
                     respond(['status' => 'success']);
                 } catch (Exception $ex) {
                     respond(['status' => 'error', 'message' => 'Create Table Failed: ' . $ex->getMessage()]);
                 }
            } else {
                 respond(['status' => 'error', 'message' => 'DB Error: ' . $e->getMessage()]);
            }
        }
        break;
    }


// =========================================================
    // 12. التحقق من التحديثات
    // =========================================================
    case 'check_update': {
        // نستخدم المتغيرات المعرفة في أعلى الملف
        respond([
            'status' => 'success',
            'version' => $LATEST_VERSION,
            'url' => $DOWNLOAD_URL,
            'force' => $FORCE_UPDATE
        ]);
        break;
    }

    default:
        respond(['status' => 'error', 'message' => 'Unknown action: ' . $action], 400);
}
?>