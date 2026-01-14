import 'package:flutter/material.dart';
import 'package:my_review/services/api_service.dart';

class QuizLogic {
  /// تقوم هذه الدالة بإرسال النتيجة والتحقق مما إذا كان الطالب قد اجتاز الاختبار
  static Future<void> submitAndFinish({
    required BuildContext context,
    required ApiService apiService,
    required int studentId,
    required int score,
    required int totalQuestions,
    required VoidCallback onUnlock, // دالة استدعاء عند النجاح
    required VoidCallback onRetry, // دالة استدعاء عند الفشل
  }) async {
    // 1. إرسال النتيجة للسيرفر
    await apiService.submitQuiz(
      studentId: studentId,
      score: score,
      details: {},
    );

    // 2. حساب النجاح (أكثر من أو يساوي النصف)
    int total = totalQuestions == 0 ? 1 : totalQuestions;
    bool isPassed = score >= (total / 2);

    if (isPassed) {
      // حالة النجاح
      onUnlock();
      if (context.mounted) Navigator.of(context).pop();
    } else {
      // حالة الفشل
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('حاول مرة أخرى.')));
        onRetry();
      }
    }
  }
}
