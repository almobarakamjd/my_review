import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // import for MethodChannel
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
  static const platform = MethodChannel('com.example.my_review/lock');
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int _correctAnswersCount = 0;
  bool _isMadrasatiUnlocked = false;
  bool _isLoading = true;
  bool _isInterfaceLoaded = false;
  final ApiService _apiService = ApiService();

  double _correctDuration = 2.0;
  double _wrongDuration = 4.0;
  bool _showSettings = false;
  Timer? _sessionTimer; // مؤقت الجلسة

  @override
  void initState() {
    super.initState();
    // 1. نبدأ بعملية التحميل الآمن
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enableLockSafely();
    });

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

  // 👇 دالة القفل الآمن (التسلسل المطلوب)
  Future<void> _enableLockSafely() async {
    // أ. تحميل الأزرار أولاً
    if (mounted) {
      setState(() {
        _isInterfaceLoaded = true;
      });
    }

    // ب. تأخير بسيط لضمان رسم الأزرار
    await Future.delayed(const Duration(seconds: 1));

    // ج. تفعيل القفل
    if (!widget.isParentPreview && mounted) {
      try {
        await platform.invokeMethod('startLock');
      } catch (e) {
        debugPrint("Failed to enable lock: $e");
      }
    }
  }

  Future<void> _requestExit() async {
    // Returns null on success, error string on failure
    final String? error = await _apiService.sendExitRequest(widget.studentId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == null
                ? "تم إرسال طلب الخروج لولي الأمر"
                : "فشل الإرسال: $error",
          ),
          backgroundColor: error == null ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _requestUnlock() async {
    final String? error = await _apiService.sendUnlockRequest(widget.studentId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == null ? "تم إرسال طلب فتح القفل" : "فشل الإرسال: $error",
          ),
          backgroundColor: error == null ? Colors.green : Colors.red,
        ),
      );
    }
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

    // التحقق الكامل للحصول على حالة الطلبات
    final statusData = await _apiService.checkFullSessionStatus(
      widget.studentId,
      savedDeviceId,
    );

    // FIX PREVENT FALSE LOGOUT:
    if (statusData['status'] == 'error') {
      return;
    }

    final bool isActive = statusData['status'] == 'active';
    final String requestStatus = statusData['request_status'] ?? 'none';
    final String? parentMsg = statusData['parent_message'];

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
    } else {
      // 1. معالجة الموافقة
      if (requestStatus == 'unlock_approved' ||
          requestStatus == 'exit_approved') {
        // فك القفل (Kiosk Mode)
        try {
          await platform.invokeMethod('stopLock');
        } catch (e) {
          debugPrint("Error stopping lock: $e");
        }

        // إشعار بفك القفل
        if (mounted && requestStatus == 'unlock_approved') {
          // إخفاء أي تنبيهات سابقة لتجنب التكرار
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("تم فتح القفل من قبل ولي الأمر ✅"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        if (mounted && requestStatus == 'exit_approved') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("وافق ولي الأمر على الخروج، يمكنك الخروج الآن"),
              backgroundColor: Colors.green,
            ),
          );
          // الخروج من التطبيق
          await Future.delayed(const Duration(seconds: 2));
          SystemNavigator.pop();
        }
      }

      // 2. معالجة الرفض (إرسال إشعار للطالب)
      if (requestStatus == 'exit_rejected' ||
          requestStatus == 'unlock_rejected') {
        // نوقف التنبيه المتكرر بإخبار السيرفر أن الطالب رأى الرسالة
        await _apiService.acknowledgeAlert(widget.studentId);

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("تم رفض الطلب ❌"),
              content: Text(
                (parentMsg != null && parentMsg.isNotEmpty)
                    ? "رسالة من ولي الأمر:\n$parentMsg"
                    : "رفض ولي الأمر طلبك.",
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("حسناً"),
                ),
              ],
            ),
          );
        }
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
                    onPressed:
                        _launchPlatform, // يستخدم نفس دالة فك القفل والخروج
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      "الذهاب للمنصة",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                const SizedBox(height: 5),
                // أزرار الطوارئ داخل الديالوج لضمان عدم احتجاز الطالب
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _requestExit,
                      child: const Text(
                        "طلب خروج",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed: _requestUnlock,
                      child: const Text(
                        "طلب فتح",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
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
    // يجب فك القفل أولاً لأن وضع "تثبيت الشاشة" يمنع فتح تطبيقات خارجية (مثل المتصفح)
    try {
      await platform.invokeMethod('stopLock');
    } catch (e) {
      debugPrint("Failed to stop lock: $e");
    }

    final Uri url = Uri.parse('https://schools.madrasati.sa/');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      // اختياري: إغلاق التطبيق بعد فتح المنصة إذا كان الهدف هو الخروج النهائي
      // SystemNavigator.pop();
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
    // FIX PARENT PREVIEW EXIT:
    // If it's parent preview, allow pop (return true).
    // If it's student lock, prevent pop (return false).
    return WillPopScope(
      onWillPop: () async => widget.isParentPreview,
      child: Scaffold(
        appBar: AppBar(
          // Show back button explicitly if parent preview
          automaticallyImplyLeading: widget.isParentPreview,
          title: const Text("الاختبار اليومي"),
          actions: _isInterfaceLoaded
              ? [
                  if (widget.isParentPreview)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      tooltip: "إغلاق المعاينة",
                      onPressed: () => Navigator.of(context).pop(),
                    ),

                  // زر إعادة التحميل
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: "إعادة تحميل",
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                      });
                      _loadQuiz();
                    },
                  ),
                  // زر طلب فتح القفل
                  TextButton(
                    onPressed: _requestUnlock,
                    child: const Text(
                      "استئذان فتح",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  // زر طلب الخروج
                  TextButton(
                    onPressed: _requestExit,
                    child: const Text(
                      "استئذان خروج",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ]
              : [],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
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
                    child: CustomScrollView(
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
                                    final String qText =
                                        q['question_text'] ?? '';
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
                                              borderRadius:
                                                  BorderRadius.circular(25),
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
                                                  option.toString() ==
                                                      correctAns,
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
                                                        BorderRadius.circular(
                                                          15,
                                                        ),
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
                                          }),
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
