import 'dart:async'; // مهم للمؤقت
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // مهم لقناة الاتصال
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/lock_screen/lock_screen.dart';
import 'screens/parent_dashboard_screen.dart'; // Add this import

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'المراجع الذكي',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
        useMaterial3: false,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // قناة الاتصال لفك القفل في حال الطوارئ
  static const platform = MethodChannel('com.example.my_review/lock');

  // متغير لإظهار زر الطوارئ
  bool _showEmergencyButton = false;
  Timer? _failsafeTimer;

  @override
  void initState() {
    super.initState();

    // 1. تشغيل مؤقت الأمان: إذا لم يفتح التطبيق خلال 8 ثوانٍ، اظهر زر الطوارئ
    _failsafeTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _showEmergencyButton = true;
        });
      }
    });

    _initApp();
  }

  @override
  void dispose() {
    _failsafeTimer?.cancel();
    super.dispose();
  }

  // دالة الطوارئ: تفك القفل وتغلق التطبيق
  Future<void> _emergencyExit() async {
    try {
      // محاولة فك القفل من الأندرويد
      await platform.invokeMethod('stopLock');
    } catch (e) {
      debugPrint("Emergency unlock failed: $e");
    }
    // إغلاق التطبيق
    SystemNavigator.pop();
  }

  Future<void> _initApp() async {
    try {
      // إضافة مهلة زمنية (Timeout) لتهيئة التنبيهات لتجنب تعليق التطبيق
      await Future(() async {
        await NotificationService().init();
        await NotificationService().scheduleDailyNotification();
        await NotificationService().requestPermissions();
      }).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint("Notification init timed out");
          return;
        },
      );
    } catch (e) {
      debugPrint("Error initializing notifications: $e");
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      // محاكاة تأخير بسيط ليرى المستخدم الشعار (اختياري)
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      if (isLoggedIn) {
        // التحقق من نوع المستخدم
        String userType = prefs.getString('user_type') ?? 'student';

        if (userType == 'parent') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
          );
        } else {
          int studentId = prefs.getInt('student_id') ?? 0;
          String gradeLevel = prefs.getString('grade_level') ?? 'middle_1';

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  LockScreen(studentId: studentId, gradeLevel: gradeLevel),
            ),
          );
        }
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      // في حال الخطأ نذهب لتسجيل الدخول
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // المحتوى الأساسي (الشعار والتحميل)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ميزة خفية: ضغط مطول على الشعار يفك القفل أيضاً
                GestureDetector(
                  onLongPress: _emergencyExit,
                  child: const Icon(
                    Icons.lock_clock,
                    size: 80,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text(
                  "جاري التجهيز...",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          // زر الطوارئ (يظهر فقط بعد 8 ثوانٍ من الانتظار)
          if (_showEmergencyButton)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  const Text(
                    "هل واجهت مشكلة؟",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _emergencyExit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text("خروج طوارئ (فك القفل)"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
