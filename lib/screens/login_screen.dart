import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart'; // 👈 مكتبة معلومات النسخة
import 'package:url_launcher/url_launcher.dart'; // 👈 لفتح رابط التحميل

import '../services/api_service.dart';
import 'lock_screen/lock_screen.dart';
import 'register_student_screen.dart';
import 'register_parent_screen.dart'; // 👈 تأكدنا من استدعاء شاشة تسجيل الأب
import 'parent_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _api = ApiService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();

    // 👇 فحص التحديثات بعد ثانية من فتح الشاشة
    Future.delayed(const Duration(seconds: 1), () {
      _checkForUpdates();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- 1. منطق التحديث التلقائي ---
  Future<void> _checkForUpdates() async {
    try {
      // جلب رقم النسخة الحالية للتطبيق
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // سؤال السيرفر عن أحدث نسخة
      // (تأكد أنك أضفت دالة checkUpdate في ApiService)
      final res = await _api.checkUpdate();

      if (res['status'] == 'success') {
        String serverVersion = res['version'];
        String url = res['url'];
        bool isForce = res['force'] == true;

        // إذا كانت نسخة السيرفر تختلف عن النسخة الحالية
        if (serverVersion != currentVersion) {
          if (!mounted) return;
          _showUpdateDialog(serverVersion, url, isForce);
        }
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  void _showUpdateDialog(String newVersion, String url, bool isForce) {
    showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (ctx) => PopScope(
        canPop: !isForce,
        child: AlertDialog(
          title: const Text("تحديث جديد متوفر 🚀"),
          content: Text(
            "الإصدار $newVersion متاح الآن.\nيرجى التحديث للحصول على الميزات الجديدة.",
          ),
          actions: [
            if (!isForce)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("لاحقاً"),
              ),
            ElevatedButton(
              onPressed: () async {
                final Uri uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text("تحديث الآن"),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. منطق تسجيل الدخول ---
  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    }
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown-ios';
    }
    return 'unknown-device';
  }

  Future<void> _saveAndGoToHome(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final id = int.tryParse(user['id'].toString()) ?? 0;
    final name = (user['full_name'] ?? '').toString();
    final grade = (user['grade_level'] ?? '').toString();
    final userType = (user['user_type'] ?? 'student').toString();

    await prefs.setBool('is_logged_in', true);
    await prefs.setInt('student_id', id);
    await prefs.setString('student_name', name);
    await prefs.setString('grade_level', grade);
    await prefs.setString('user_type', userType);

    // حفظ معرف الجهاز للطرد لاحقاً
    await prefs.setString('device_id', (user['device_id'] ?? '').toString());

    if (!mounted) return;

    if (userType == 'parent') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LockScreen(studentId: id, gradeLevel: grade),
        ),
      );
    }
  }

  Future<void> _tryAutoLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final deviceId = await _getDeviceId();
      final res = await _api.loginStudent(deviceId: deviceId);

      if (res['status'] == 'success') {
        final user = (res['data'] as Map).cast<String, dynamic>();
        await _saveAndGoToHome(user);
        return;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginManual() async {
    if (_usernameController.text.isEmpty) {
      setState(() => _error = 'أدخل اسم المستخدم');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final deviceId = await _getDeviceId();
      final res = await _api.loginStudentManual(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        deviceId: deviceId,
      );

      if (res['status'] != 'success') {
        setState(
          () => _error = (res['message'] ?? 'فشل تسجيل الدخول').toString(),
        );
        return;
      }

      final user = (res['data'] as Map).cast<String, dynamic>();
      await _saveAndGoToHome(user);
    } catch (e) {
      setState(() => _error = 'خطأ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_circle,
                    size: 80,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),

                  if (_loading)
                    const CircularProgressIndicator()
                  else
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loginManual,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(15),
                            ),
                            child: const Text(
                              'دخـول',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Divider(),
                        const SizedBox(height: 15),
                        // زر تسجيل طالب
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterStudentScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_add),
                          label: const Text('تسجيل طالب جديد'),
                        ),
                        const SizedBox(height: 10),
                        // 👇 زر تسجيل ولي أمر (تمت إضافته لك)
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterParentScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.supervisor_account),
                          label: const Text('تسجيل ولي أمر جديد'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
