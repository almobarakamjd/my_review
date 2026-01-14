import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart'; // مهم للتحقق
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api_service.dart';
import 'models/math_pro_screen.dart';
import '../../widgets/feedback_dialog.dart';
import '../lock_screen/logic/update_manager.dart';

class LockScreen extends StatefulWidget {
  final int studentId;
  final String gradeLevel;
  final bool isParentPreview;

  const LockScreen({
    super.key,
    required this.studentId,
    required this.gradeLevel,
    this.isParentPreview = false,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int _correctAnswersCount = 0;
  bool _isMadrasatiUnlocked = false;
  bool _isLoading = true;
  final ApiService _apiService = ApiService();

  double _correctDuration = 2.0;
  double _wrongDuration = 4.0;
  bool _showSettings = false;
  Timer? _sessionTimer; // مؤقت الجلسة

  @override
  void initState() {
    super.initState();
    _loadQuiz();
    _requestBatteryPermission();

    // تشغيل التحقق فقط إذا كان طالباً (وليس معاينة أب)
    if (!widget.isParentPreview) {
      _startSessionCheck();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateManager.checkForUpdate(context);
    });
  }

  Future<void> _requestBatteryPermission() async {
    // التحقق هل الإذن ممنوح مسبقاً؟
    var status = await Permission.ignoreBatteryOptimizations.status;

    if (!status.isGranted) {
      // إذا لم يكن ممنوحاً، نطلبه من المستخدم
      // ستظهر نافذة من النظام تطلب الموافقة
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  // 👇 دالة بدء التحقق الدوري (كل 10 ثواني)
  void _startSessionCheck() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _checkSession();
    });
  }

  // 👇 دالة التحقق الفعلي من السيرفر
  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDeviceId = prefs.getString('device_id') ?? '';

    if (savedDeviceId.isEmpty) return;

    // نسأل السيرفر: هل هذا الجهاز ما زال هو الجهاز النشط للطالب؟
    bool isActive = await _apiService.checkSessionStatus(
      widget.studentId,
      savedDeviceId,
    );

    if (!isActive) {
      _sessionTimer?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم تسجيل خروجك من قبل ولي الأمر"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );

        await prefs.clear(); // مسح البيانات

        // الخروج لشاشة الدخول
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  Future<void> _loadQuiz() async {
    setState(() => _isLoading = true);
    try {
      final questions = await _apiService.getQuiz(
        gradeLevel: widget.gradeLevel,
      );
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
          _currentIndex = 0;
          _score = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processAnswer(
    bool isCorrect,
    String correctAnswer,
    String explanation,
  ) {
    if (isCorrect) {
      _score++;
      _correctAnswersCount++;
      if (_correctAnswersCount >= 4) {
        setState(() => _isMadrasatiUnlocked = true);
      }
    }

    int duration = isCorrect
        ? _correctDuration.toInt()
        : _wrongDuration.toInt();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Feedback",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: FeedbackDialog(
            isCorrect: isCorrect,
            correctAnswer: correctAnswer,
            explanation: explanation,
          ),
        );
      },
    );

    Timer(Duration(seconds: duration), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        if (_currentIndex < _questions.length - 1) {
          setState(() => _currentIndex++);
        } else {
          _finishQuiz();
        }
      }
    });
  }

  Future<void> _finishQuiz() async {
    setState(() => _isLoading = true);
    if (!widget.isParentPreview) {
      await _apiService.submitQuiz(
        studentId: widget.studentId,
        score: _score,
        details: {'total': _questions.length},
      );
    }
    setState(() => _isLoading = false);

    if (!mounted) return;
    int total = _questions.isEmpty ? 1 : _questions.length;
    bool passed = _score >= (total / 2);
    _showResultDialog(passed, total);
  }

  void _showResultDialog(bool passed, int total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Icon(
              passed ? Icons.emoji_events : Icons.sentiment_neutral,
              size: 70,
              color: passed ? Colors.amber : Colors.grey,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  passed ? "ممتاز يا بطل! 🎉" : "حاول مرة أخرى 💪",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text("الدرجة: $_score من $total"),
              ],
            ),
            actions: [
              if (widget.isParentPreview)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text("إغلاق المعاينة"),
                )
              else ...[
                if (_isMadrasatiUnlocked)
                  ElevatedButton(
                    onPressed: _launchPlatform,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      "الذهاب للمنصة",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _loadQuiz();
                  },
                  child: const Text("إعادة الاختبار"),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchPlatform() async {
    final Uri url = Uri.parse('https://schools.madrasati.sa/');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('$e');
    }
  }

  bool _isMathQuestion(String text) {
    return RegExp(r'[0-9]').hasMatch(text) &&
        RegExp(r'[+\-×÷xX*\/]').hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF6DD5FA), Color(0xFF2980B9)],
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "سؤال ${_currentIndex + 1} / ${_questions.length}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.settings,
                                  color: Colors.white,
                                ),
                                onPressed: () => setState(
                                  () => _showSettings = !_showSettings,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_isMadrasatiUnlocked && !widget.isParentPreview)
                        SliverToBoxAdapter(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 5,
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _launchPlatform,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                elevation: 5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              icon: const Icon(Icons.school, size: 24),
                              label: const Text(
                                "اذهب لمنصة مدرستي",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _questions.isEmpty
                            ? const Center(child: Text("لا توجد أسئلة"))
                            : Builder(
                                builder: (context) {
                                  final q = _questions[_currentIndex];
                                  final String qText = q['question_text'] ?? '';
                                  final String correctAns =
                                      q['correct_answer'] ?? '';
                                  final String explanation =
                                      q['explanation'] ?? '';

                                  if (_isMathQuestion(qText)) {
                                    return Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: MathProScreen(
                                        questionText: qText,
                                        correctAnswer: correctAns,
                                        onSubmit: (val) {
                                          bool isCorrect =
                                              val.trim() == correctAns.trim();
                                          _processAnswer(
                                            isCorrect,
                                            correctAns,
                                            explanation,
                                          );
                                        },
                                      ),
                                    );
                                  }

                                  List<dynamic> options = q['options'] ?? [];
                                  return Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(30),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 10,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            qText,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              height: 1.6,
                                              fontFamily: 'Arial',
                                            ),
                                            textAlign: TextAlign.center,
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ),
                                        const SizedBox(height: 30),
                                        ...options.map<Widget>((option) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 15,
                                            ),
                                            child: ElevatedButton(
                                              onPressed: () => _processAnswer(
                                                option.toString() == correctAns,
                                                correctAns,
                                                explanation,
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 18,
                                                    ),
                                                backgroundColor: Colors.white,
                                                foregroundColor: const Color(
                                                  0xFF2980B9,
                                                ),
                                                elevation: 3,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                ),
                                              ),
                                              child: Text(
                                                option.toString(),
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        const SizedBox(height: 50),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
          if (_showSettings)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "⚙️ إعدادات العرض",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _showSettings = false),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildTimeSlider(
                      "وقت الإجابة الصحيحة",
                      _correctDuration,
                      Colors.green,
                      (v) => setState(() => _correctDuration = v),
                    ),
                    _buildTimeSlider(
                      "وقت الإجابة الخاطئة",
                      _wrongDuration,
                      Colors.red,
                      (v) => setState(() => _wrongDuration = v),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeSlider(
    String label,
    double val,
    Color color,
    Function(double) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          flex: 4,
          child: Slider(
            value: val,
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: color,
            label: "${val.toInt()} ث",
            onChanged: onChanged,
          ),
        ),
        Text(
          "${val.toInt()} ث",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
