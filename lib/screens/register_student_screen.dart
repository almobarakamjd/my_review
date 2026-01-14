import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'lock_screen/lock_screen.dart';

class RegisterStudentScreen extends StatefulWidget {
  const RegisterStudentScreen({super.key});

  @override
  State<RegisterStudentScreen> createState() => _RegisterStudentScreenState();
}

class _RegisterStudentScreenState extends State<RegisterStudentScreen> {
  final _api = ApiService();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _parentUserController =
      TextEditingController(); // 👈 حقل جديد لولي الأمر

  String _selectedGrade = 'middle_1';
  final List<Map<String, String>> _grades = [
    {'label': 'الصف الأول المتوسط', 'value': 'middle_1'},
    {'label': 'الصف الثاني المتوسط', 'value': 'middle_2'},
    {'label': 'الصف الثالث المتوسط', 'value': 'middle_3'},
    {'label': 'الصف الرابع الابتدائي', 'value': 'prim_4'},
    {'label': 'الصف الخامس الابتدائي', 'value': 'prim_5'},
    {'label': 'الصف السادس الابتدائي', 'value': 'prim_6'},
  ];

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _parentUserController.dispose();
    super.dispose();
  }

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

  Future<void> _saveAndGoToLock(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final id = int.tryParse(user['id'].toString()) ?? 0;
    final name = (user['full_name'] ?? '').toString();
    final grade = (user['grade_level'] ?? '').toString();
    final deviceId = (user['device_id'] ?? '').toString();
    // الطالب دائماً نوعه student
    await prefs.setBool('is_logged_in', true);
    await prefs.setInt('student_id', id);
    await prefs.setString('student_name', name);
    await prefs.setString('grade_level', grade);
    await prefs.setString('user_type', 'student');
    await prefs.setString('device_id', deviceId);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LockScreen(studentId: id, gradeLevel: grade),
      ),
      (_) => false,
    );
  }

  Future<void> _register() async {
    if (_fullNameController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = "الرجاء تعبئة الحقول الأساسية");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final deviceId = await _getDeviceId();

      // استدعاء الدالة المحدثة التي تقبل parentUsername
      final res = await _api.registerStudent(
        fullName: _fullNameController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        gradeLevel: _selectedGrade,
        deviceId: deviceId,
        parentUsername: _parentUserController.text
            .trim(), // 👈 إرسال اسم الأب (اختياري)
      );

      if (res['status'] != 'success') {
        setState(() => _error = (res['message'] ?? 'فشل التسجيل').toString());
        return;
      }

      final user = (res['data'] as Map).cast<String, dynamic>();
      await _saveAndGoToLock(user);
    } catch (e) {
      setState(() => _error = 'خطأ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل طـالـب جـديـد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(Icons.school, size: 80, color: Colors.blue),
              const SizedBox(height: 20),

              TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 12),

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

              DropdownButtonFormField<String>(
                value: _selectedGrade,
                decoration: const InputDecoration(
                  labelText: 'الصف الدراسي',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.class_),
                ),
                items: _grades.map((g) {
                  return DropdownMenuItem(
                    value: g['value'],
                    child: Text(g['label']!),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedGrade = val!),
              ),

              const SizedBox(height: 20),
              const Divider(thickness: 1),
              const SizedBox(height: 10),

              // 👇 حقل ربط ولي الأمر (اختياري)
              TextField(
                controller: _parentUserController,
                decoration: const InputDecoration(
                  labelText: 'اسم مستخدم ولي الأمر (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.family_restroom),
                  helperText: "اتركه فارغاً إذا لم ترد ربط الحساب الآن",
                ),
              ),

              const SizedBox(height: 20),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),

              if (_loading)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'تسجيل الحساب',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
