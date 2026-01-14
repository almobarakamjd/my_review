import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PromoteAdminScreen extends StatefulWidget {
  const PromoteAdminScreen({super.key});

  @override
  State<PromoteAdminScreen> createState() => _PromoteAdminScreenState();
}

class _PromoteAdminScreenState extends State<PromoteAdminScreen> {
  final ApiService _api = ApiService();
  final _usernameController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isLoading = false;

  Future<void> _promote() async {
    if (_usernameController.text.isEmpty || _keyController.text.isEmpty) return;

    setState(() => _isLoading = true);

    // تصحيح الخطأ هنا: استخدام Named Parameters
    final response = await _api.promoteUserToAdmin(
      username: _usernameController.text.trim(),
      promoteKey: _keyController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? "تمت العملية"),
          backgroundColor: response['status'] == 'success'
              ? Colors.green
              : Colors.red,
        ),
      );
      if (response['status'] == 'success') {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ترقية إلى مشرف")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "أدخل اسم المستخدم ومفتاح الترقية السري",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "اسم المستخدم المراد ترقيته",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _keyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "مفتاح الترقية (Secret Key)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _promote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("تـرقـيـة الآن"),
                  ),
          ],
        ),
      ),
    );
  }
}
