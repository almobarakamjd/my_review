import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'lock_screen/logic/update_manager.dart';
import 'login_screen.dart';
import 'lock_screen/lock_screen.dart';
import 'report_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _children = [];
  bool _isLoading = true;
  String _parentName = "";
  int _parentId = 0; // لحفظ رقم الأب

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateManager.checkForUpdate(context);
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _parentId = prefs.getInt('student_id') ?? 0; // student_id هنا يحمل رقم الأب
    _parentName = prefs.getString('student_name') ?? "ولي الأمر";

    if (_parentId != 0) {
      final children = await _api.getMyChildren(_parentId);
      if (mounted) {
        setState(() {
          _children = children;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // 👇 نافذة إضافة ابن جديد
  void _showAddChildDialog() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedGrade = 'middle_1';

    final grades = [
      {'label': 'أول متوسط', 'value': 'middle_1'},
      {'label': 'ثاني متوسط', 'value': 'middle_2'},
      {'label': 'ثالث متوسط', 'value': 'middle_3'},
      {'label': 'رابع ابتدائي', 'value': 'prim_4'},
      {'label': 'خامس ابتدائي', 'value': 'prim_5'},
      {'label': 'سادس ابتدائي', 'value': 'prim_6'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إضافة ابن جديد"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: "الاسم الكامل",
                  icon: Icon(Icons.person),
                ),
              ),
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(
                  labelText: "اسم المستخدم (للدخول)",
                  icon: Icon(Icons.account_circle),
                ),
              ),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(
                  labelText: "كلمة المرور",
                  icon: Icon(Icons.lock),
                ),
              ),
              DropdownButtonFormField<String>(
                value: selectedGrade,
                items: grades
                    .map(
                      (g) => DropdownMenuItem(
                        value: g['value'],
                        child: Text(g['label']!),
                      ),
                    )
                    .toList(),
                onChanged: (v) => selectedGrade = v!,
                decoration: const InputDecoration(
                  labelText: "الصف",
                  icon: Icon(Icons.school),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty ||
                  userCtrl.text.isEmpty ||
                  passCtrl.text.isEmpty)
                return;

              Navigator.pop(ctx); // إغلاق الديالوج
              setState(() => _isLoading = true);

              final res = await _api.createChildAccount(
                parentId: _parentId,
                fullName: nameCtrl.text.trim(),
                username: userCtrl.text.trim(),
                password: passCtrl.text.trim(),
                gradeLevel: selectedGrade,
              );

              if (res['status'] == 'success') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("تمت إضافة الابن بنجاح ✅"),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadData(); // تحديث القائمة
              } else {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? "خطأ"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("إضـافـة"),
          ),
        ],
      ),
    );
  }

  // 👇 دالة طرد الابن (موجودة سابقاً ولكن نعيدها للاكتمال)
  Future<void> _confirmLogoutChild(dynamic childIdRaw, String childName) async {
    final int childId = int.parse(childIdRaw.toString());

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الخروج"),
        content: Text("هل تريد تسجيل خروج '$childName' من جهازه؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("نعم", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      bool success = await _api.remoteLogoutChild(_parentId, childId);
      await _loadData();
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "تم الخروج بنجاح" : "حدث خطأ"),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("مرحباً $_parentName"),
        centerTitle: true,
        backgroundColor: Colors.teal,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      // 👇 زر الإضافة العائم
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddChildDialog,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add),
        label: const Text("إضافة ابن"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _children.isEmpty
          ? _buildEmptyView()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _children.length,
              itemBuilder: (context, index) {
                final child = _children[index];
                return _buildChildCard(child);
              },
            ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.family_restroom, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            "لا يوجد أبناء حالياً",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 10),
          Text(
            "اضغط على زر (+ إضافة ابن) في الأسفل",
            style: TextStyle(fontSize: 14, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    String name = child['full_name'] ?? "بدون اسم";
    String grade = child['grade_level'] ?? "-";
    int childId = int.parse(child['id'].toString());
    bool loggedToday = (child['logged_today'].toString() == '1');
    String lastScore = child['last_score']?.toString() ?? "لا يوجد";

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.withOpacity(0.2),
                  child: const Icon(Icons.person, color: Colors.teal),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(grade, style: const TextStyle(color: Colors.grey)),
                      Text(
                        "user: ${child['username']}",
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      margin: const EdgeInsets.only(bottom: 5),
                      decoration: BoxDecoration(
                        color: loggedToday
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: loggedToday ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Text(
                        loggedToday ? "دخل اليوم" : "غائب",
                        style: TextStyle(
                          fontSize: 10,
                          color: loggedToday ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _confirmLogoutChild(childId, name),
                      child: const Tooltip(
                        message: "طرد",
                        child: Icon(
                          Icons.power_settings_new,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text("آخر درجة: $lastScore"),
                TextButton.icon(
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text("تجربة"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LockScreen(
                          studentId: childId,
                          gradeLevel: grade,
                          isParentPreview: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
