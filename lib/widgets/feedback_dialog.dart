import 'package:flutter/material.dart';

class FeedbackDialog extends StatelessWidget {
  final bool isCorrect;
  final String correctAnswer;
  final String explanation;

  const FeedbackDialog({
    super.key,
    required this.isCorrect,
    required this.correctAnswer,
    this.explanation = '',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      backgroundColor: isCorrect
          ? const Color(0xFFE8F5E9)
          : const Color(0xFFFFEBEE), // خلفية فاتحة
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // الأيقونة الدائرية الكبيرة
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isCorrect
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFE53935), // أحمر أو أخضر
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isCorrect ? Colors.green : Colors.red).withOpacity(
                      0.3,
                    ),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                isCorrect ? Icons.check : Icons.close,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // عنوان الرسالة
            Text(
              isCorrect
                  ? "أحسنت! إجابة ممتازة 🌟"
                  : "خطأ، حاول التركيز أكثر 💡",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isCorrect ? Colors.green[800] : const Color(0xFFC62828),
                fontFamily: 'Arial',
              ),
            ),

            // مربع الإجابة الصحيحة (يظهر فقط عند الخطأ)
            if (!isCorrect) ...[
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFEF9A9A),
                    width: 1.5,
                  ), // حدود حمراء فاتحة
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      "الإجابة الصحيحة هي:",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      correctAnswer,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // الشرح (لماذا؟)
            if (explanation.isNotEmpty && explanation != 'null') ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              const Text(
                "لماذا؟",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                explanation,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
