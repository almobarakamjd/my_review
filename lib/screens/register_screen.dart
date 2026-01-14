import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../services/api_service.dart';
import 'lock_screen/lock_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final ApiService _api = ApiService();
  final _nameController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  final Map<String, String> _gradeMap = {
    'الصف الأول': 'middle_1',
    'الصف الثاني': 'middle_2',
    'الصف الثالث': 'middle_3',
    'الصف الرابع': 'prim_4',
    'الصف الخامس': 'prim_5',
    'الصف السادس': 'prim_6',
  };

  String _selectedGradeLabel = "الصف الأول";
  final List<String> _grades = [
    "الصف الأول",
    "الصف الثاني",
    "الصف الثالث",
    "الصف الرابع",
    "الصف الخامس",
    "الصف السادس",
  ];

  bool _isLoading = false;

  Future<void> _register() async {
    if (_nameController.text.isEmpty ||
        _userController.text.isEmpty ||
        _passController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("يرجى ملء جميع الحقول")));
      return;
    }

    setState(() => _isLoading = true);

    String deviceId = "unknown";
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? "unknown";
      }
    } catch (e) {
      debugPrint("Error getting device ID: $e");
    }

    // تحديد كود الصف لإرساله للسيرفر
    String gradeToSend = _gradeMap[_selectedGradeLabel] ?? 'middle_1';

    final response = await _api.registerStudent(
      fullName: _nameController.text.trim(),
      username: _userController.text.trim(),
      password: _passController.text.trim(),
      gradeLevel: gradeToSend,
      deviceId: deviceId,
    );

    setState(() => _isLoading = false);

    if (response['status'] == 'success') {
      final userData = response['data'];
      final prefs = await SharedPreferences.getInstance();

      // حفظ البيانات
      final int sid = int.tryParse(userData['id'].toString()) ?? 0;
      final String sGrade = (userData['grade_level'] ?? gradeToSend).toString();

      await prefs.setInt('student_id', sid);
      await prefs.setString(
        'student_name',
        (userData['full_name'] ?? '').toString(),
      );
      await prefs.setString('grade_level', sGrade);
      await prefs.setBool('is_logged_in', true);

      if (mounted) {
        // الانتقال لشاشة القفل وتمرير البيانات المطلوبة
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LockScreen(studentId: sid, gradeLevel: sGrade),
          ),
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? "فشل التسجيل"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إنشاء حساب جديد")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.person_add, size: 80, color: Color(0xFF006C35)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "الاسم الكامل",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: "اسم المستخدم",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "كلمة المرور",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: _selectedGradeLabel,
              decoration: const InputDecoration(
                labelText: "المرحلة الدراسية",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school),
              ),
              items: _grades.map((String grade) {
                return DropdownMenuItem<String>(
                  value: grade,
                  child: Text(grade),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedGradeLabel = val!),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006C35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: _register,
                      child: const Text(
                        "تسجيل حساب",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
