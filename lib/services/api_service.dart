import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// تعريف كلاس السؤال
class Question {
  final int id;
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final String? originalText;
  final String? highlightText;
  final String? questionOnly;

  Question({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    this.originalText,
    this.highlightText,
    this.questionOnly,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    String qText = '';
    String? qOnly;
    String? origText = json['text'];
    String? highText = json['highlight'];

    if (json.containsKey('q')) {
      qOnly = json['q'];
      qText = qOnly ?? '';
      if (origText != null) {
        qText = "$origText\n$qText";
      }
    } else if (json.containsKey('question_text')) {
      qText = json['question_text'];
      qOnly = qText;
    } else {
      qText = json['question'] ?? 'السؤال غير متاح';
      qOnly = qText;
    }

    List<String> parsedOptions = [];
    var optsData = json['opts'] ?? json['options'];
    if (optsData != null) {
      if (optsData is String) {
        try {
          parsedOptions = List<String>.from(jsonDecode(optsData));
        } catch (e) {
          parsedOptions = [];
        }
      } else if (optsData is List) {
        parsedOptions = List<String>.from(optsData);
      }
    }

    int ansIdx = 0;
    if (json.containsKey('ans')) {
      ansIdx = json['ans'];
    } else if (json.containsKey('correct_option_index')) {
      ansIdx = int.tryParse(json['correct_option_index'].toString()) ?? 0;
    } else if (json.containsKey('correctAnswerIndex')) {
      ansIdx = int.tryParse(json['correctAnswerIndex'].toString()) ?? 0;
    }

    String expText = json['exp'] ?? json['explanation'] ?? '';

    return Question(
      id: int.tryParse(json['id'].toString()) ?? 0,
      questionText: qText,
      options: parsedOptions,
      correctAnswerIndex: ansIdx,
      explanation: expText,
      originalText: origText,
      highlightText: highText,
      questionOnly: qOnly,
    );
  }
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = 'https://amjd.law/backend/api.php';

  // --- دوال الاتصال بالسيرفر ---
  // تحديث دالة تسجيل الطالب لتقبل اسم الأب
  Future<Map<String, dynamic>> registerStudent({
    required String fullName,
    required String username,
    required String password,
    required String gradeLevel,
    required String deviceId,
    String? parentUsername, // خانة اختيارية
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'register_student',
          'full_name': fullName,
          'username': username,
          'password': password,
          'grade_level': gradeLevel,
          'device_id': deviceId,
          'parent_username': parentUsername, // إرسال للسيرفر
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Server error'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> loginStudent({required String deviceId}) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'login_student', 'device_id': deviceId}),
      );
      if (response.body.isEmpty)
        return {'status': 'error', 'message': 'Empty response from server'};
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> loginStudentManual({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'login_student_manual',
          'username': username,
          'password': password,
          'device_id': deviceId,
        }),
      );

      if (response.body.isEmpty) {
        return {'status': 'error', 'message': 'Server returned empty response'};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> registerParent({
    required String fullName,
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'register_parent',
          'full_name': fullName,
          'username': username,
          'password': password,
        }),
      );
      if (response.body.isEmpty) return {'status': 'error'};
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> promoteUserToAdmin({
    required String username,
    required String promoteKey,
  }) async {
    return {'status': 'error', 'message': 'Not implemented'};
  }

  Future<bool> submitQuiz({
    required int studentId,
    required int score,
    Map<String, dynamic>? details,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'submit_quiz',
          'student_id': studentId,
          'score': score,
          'details': details,
        }),
      );
      if (response.body.isEmpty) return false;
      final data = jsonDecode(response.body);
      return data['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getReport({
    required int studentId,
    required String period,
  }) async {
    return {'status': 'error'};
  }

  // ==========================================
  // 👇👇 دالة جلب الاختبار المعدلة 👇👇
  // ==========================================

  Future<List<dynamic>> getQuiz({
    String? studentId,
    required String gradeLevel,
  }) async {
    List<Question> jsonQuestions = await _loadLocalQuiz(gradeLevel);
    jsonQuestions.shuffle();

    List<Question> selectedQuestions = jsonQuestions.take(7).toList();

    int remainingCount = 10 - selectedQuestions.length;

    if (remainingCount < 3) remainingCount = 3;

    if (selectedQuestions.length + 3 > 10) {
      selectedQuestions = selectedQuestions.take(10 - 3).toList();
    }

    List<Question> algebraQuestions = _generateLocalAlgebra(remainingCount);

    List<Question> finalQuestions = [...selectedQuestions, ...algebraQuestions];

    finalQuestions.shuffle();

    return finalQuestions.take(10).map((q) {
      String correctAnsString = '';
      if (q.options.isNotEmpty &&
          q.correctAnswerIndex >= 0 &&
          q.correctAnswerIndex < q.options.length) {
        correctAnsString = q.options[q.correctAnswerIndex];
      }

      List<String> shuffledOpts = List<String>.from(q.options);
      shuffledOpts.shuffle();

      return {
        'question_text': q.questionText,
        'original_text': q.originalText,
        'highlight_text': q.highlightText,
        'question_only': q.questionOnly,
        'options': shuffledOpts,
        'correct_answer': correctAnsString,
        'explanation': q.explanation,
      };
    }).toList();
  }

  Future<List<Question>> _loadLocalQuiz(String grade) async {
    List<Question> allQuestions = [];
    const String folderName = '6th';

    final files = [
      'assets/quiz/$folderName/hadeeth.json',
      'assets/quiz/$folderName/islam_history.json',
      'assets/quiz/$folderName/math_eng.json',
      'assets/quiz/$folderName/tafseer.json',
      'assets/quiz/$folderName/tajweed.json',
      'assets/quiz/$folderName/faqh.json',
      'assets/quiz/$folderName/arabic.json',
    ];

    for (String path in files) {
      try {
        String jsonString = await rootBundle.loadString(path);
        List<dynamic> jsonList = json.decode(jsonString);
        for (var item in jsonList) {
          allQuestions.add(Question.fromJson(item));
        }
      } catch (e) {}
    }
    return allQuestions;
  }

  List<Question> _generateLocalAlgebra(int count) {
    List<Question> algebraQuestions = [];
    var rng = Random();

    for (int i = 0; i < count; i++) {
      int opType = rng.nextInt(3);
      int num1, num2, result;
      String opSymbol;

      switch (opType) {
        case 0:
          num1 = rng.nextInt(89) + 10;
          num2 = rng.nextInt(89) + 10;
          result = num1 + num2;
          opSymbol = "+";
          break;
        case 1:
          num1 = rng.nextInt(50) + 50;
          num2 = rng.nextInt(39) + 10;
          result = num1 - num2;
          opSymbol = "-";
          break;
        case 2:
          num1 = rng.nextInt(89) + 10;
          num2 = rng.nextInt(89) + 10;
          result = num1 * num2;
          opSymbol = "×";
          break;
        default:
          num1 = 0;
          num2 = 0;
          result = 0;
          opSymbol = "+";
      }

      Set<String> optionsSet = {result.toString()};
      while (optionsSet.length < 4) {
        int offset = (rng.nextInt(5) + 1) * 10 * (rng.nextBool() ? 1 : -1);
        if (offset == 0) offset = 5;
        int wrong = result + offset;
        if (wrong >= 0) optionsSet.add(wrong.toString());
      }

      List<String> opts = optionsSet.toList();
      opts.shuffle();

      algebraQuestions.add(
        Question(
          id: 9000 + i,
          questionText: "$num1 $opSymbol $num2",
          options: opts,
          correctAnswerIndex: opts.indexOf(result.toString()),
          explanation: "الإجابة هي $result",
        ),
      );
    }
    return algebraQuestions;
  }

  // 👇✅ الآن هي في المكان الصحيح (داخل الكلاس) ✅👇
  Future<bool> verifyParentPassword({
    required int studentId,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'verify_parent_password',
          'student_id': studentId,
          'password': password,
        }),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // 👇 أضف هذه الدوال داخل كلاس ApiService

  // 1. للأب: طرد الابن
  // Returns null if success, or error message string
  Future<String?> remoteLogoutChild(int parentId, int studentId) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'remote_logout_student',
          'parent_id': parentId,
          'student_id': studentId,
        }),
      );
      if (response.body.isEmpty) return "Empty response";
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') return null;
      return data['message'] ?? "Server Error";
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  // 2. للابن: التحقق من الجلسة (بسيط)
  Future<bool> checkSessionStatus(int studentId, String currentDeviceId) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'check_session_status',
          'student_id': studentId,
          'device_id': currentDeviceId,
        }),
      );
      if (response.body.isEmpty) return true;
      final data = jsonDecode(response.body);
      return data['status'] == 'active';
    } catch (e) {
      return true;
    }
  }

  // 2-ب. للابن: التحقق من الجلسة (كامل مع حالة الطلبات)
  Future<Map<String, dynamic>> checkFullSessionStatus(
    int studentId,
    String currentDeviceId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'check_session_status',
          'student_id': studentId,
          'device_id': currentDeviceId,
        }),
      );
      if (response.body.isEmpty) return {'status': 'error'};
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createChildAccount({
    required int parentId,
    required String fullName,
    required String username,
    required String password,
    required String gradeLevel,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'create_child_account',
          'parent_id': parentId,
          'full_name': fullName,
          'username': username,
          'password': password,
          'grade_level': gradeLevel,
        }),
      );
      if (response.body.isEmpty)
        return {'status': 'error', 'message': 'Empty response'};
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // 3. للأب: جلب قائمة الأبناء
  Future<List<dynamic>> getMyChildren(int parentId) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'get_my_children', 'parent_id': parentId}),
      );
      if (response.body.isEmpty) return [];
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return data['data'] ?? []; // Corrected key from 'children' to 'data'
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 4. للابن: إرسال طلب خروج
  // Returns null if success, or error message string
  Future<String?> sendExitRequest(int studentId) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'request_exit', 'student_id': studentId}),
      );
      if (response.body.isEmpty) return "Empty response";
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') return null;
      return data['message'] ?? "Server Error: ${response.body}";
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  // 5. للابن: إرسال طلب فتح القفل
  // Returns null if success, or error message string
  Future<String?> sendUnlockRequest(int studentId) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'request_unlock', 'student_id': studentId}),
      );
      if (response.body.isEmpty) return "Empty response";
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') return null;
      return data['message'] ?? "Server Error: ${response.body}";
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  // 6. للأب: الموافقة على طلب الخروج
  Future<String?> approveExitRequest(int parentId, int studentId) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'approve_exit',
          'parent_id': parentId,
          'student_id': studentId,
        }),
      );
      if (response.body.isEmpty) return "Empty response";
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') return null;
      return data['message'] ?? "Server Error";
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  // 8. للأب: الموافقة على طلب فتح القفل
  Future<String?> approveUnlockRequest(int parentId, int studentId) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'approve_unlock',
          'parent_id': parentId,
          'student_id': studentId,
        }),
      );
      if (response.body.isEmpty) return "Empty response";
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') return null;
      return data['message'] ?? "Server Error";
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  // 7. للأب: فتح القفل عن بعد (Unlock)
  Future<String?> remoteUnlockChild(int parentId, int studentId) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'remote_unlock',
          'parent_id': parentId,
          'student_id': studentId,
        }),
      );
      if (response.body.isEmpty) return "Empty response";
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') return null;
      return data['message'] ?? "Server Error";
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  // 9. للأب: رفض طلب الخروج
  Future<String?> rejectExitRequest(
    int parentId,
    int studentId,
    String message,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'reject_exit',
          'parent_id': parentId,
          'student_id': studentId,
          'message': message,
        }),
      );
      if (response.body.isEmpty) return "Empty response";
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') return null;
      return data['message'] ?? "Server Error";
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  // 10. للأب: رفض طلب فتح القفل
  Future<String?> rejectUnlockRequest(
    int parentId,
    int studentId,
    String message,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'reject_unlock',
          'parent_id': parentId,
          'student_id': studentId,
          'message': message,
        }),
      );
      if (response.body.isEmpty) return "Empty response";
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') return null;
      return data['message'] ?? "Server Error";
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  // 11. للابن: تأكيد قراءة التنبيه
  Future<void> acknowledgeAlert(int studentId) async {
    try {
      await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'acknowledge_alert',
          'student_id': studentId,
        }),
      );
    } catch (_) {}
  }

  // دالة التحقق من التحديث
  Future<Map<String, dynamic>> checkUpdate() async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'check_update'}),
      );
      if (response.body.isEmpty) return {'status': 'error'};
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error'};
    }
  }
} // نهاية الكلاس ApiService
