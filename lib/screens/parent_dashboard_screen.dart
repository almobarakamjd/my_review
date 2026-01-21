import 'package:flutter/material.dart';
import 'dart:async';
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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateManager.checkForUpdate(context);
    });
    // تحديث دوري كل 10 ثواني (Live)
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    final prefs = await SharedPreferences.getInstance();
    _parentId = prefs.getInt('student_id') ?? 0; // student_id هنا يحمل رقم الأب
    _parentName = prefs.getString('student_name') ?? "ولي الأمر";

    if (_parentId != 0) {
      if (showLoading && mounted) setState(() => _isLoading = true);

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
                  passCtrl.text.isEmpty) {
                return;
              }

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
      String? error = await _api.remoteLogoutChild(_parentId, childId);
      await _loadData();
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error == null ? "تم الخروج بنجاح" : "حدث خطأ: $error",
            ),
            backgroundColor: error == null ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectDialog(int childId, String type) {
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'exit' ? "رفض الخروج" : "رفض فتح القفل"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("هل تريد إرسال رسالة للابن؟ (اختياري)"),
            TextField(
              controller: msgCtrl,
              decoration: const InputDecoration(hintText: "الرسالة..."),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              String? error;
              if (type == 'exit') {
                error = await _api.rejectExitRequest(
                  _parentId,
                  childId,
                  msgCtrl.text,
                );
              } else {
                error = await _api.rejectUnlockRequest(
                  _parentId,
                  childId,
                  msgCtrl.text,
                );
              }
              await _loadData();
              setState(() => _isLoading = false);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error == null ? "تم الرفض بنجاح" : "حدث خطأ: $error",
                    ),
                    backgroundColor: error == null ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text("رفض الطلب"),
          ),
        ],
      ),
    );
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
          : RefreshIndicator(
              onRefresh: () => _loadData(showLoading: false),
              child: _children.isEmpty
                  ? ListView(
                      children: [_buildEmptyView()],
                    ) // Wrap empty view in ListView required for RefreshIndicator
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _children.length,
                      itemBuilder: (context, index) {
                        final child = _children[index];
                        return _buildChildCard(child);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyView() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: const Center(
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
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    String name = child['full_name'] ?? "بدون اسم";
    String grade = child['grade_level'] ?? "-";
    int childId = int.parse(child['id'].toString());
    bool loggedToday = (child['logged_today'].toString() == '1');
    String lastScore = child['last_score']?.toString() ?? "لا يوجد";
    String requestStatus = child['request_status']?.toString() ?? 'none';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (requestStatus == 'exit_pending')
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                color: Colors.orange.withOpacity(0.2),
                child: const Text(
                  "🔴 يطلب الخروج",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (requestStatus == 'unlock_pending')
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                color: Colors.blue.withOpacity(0.2),
                child: const Text(
                  "🟡 يطلب فتح القفل",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
            // أزرار التحكم الأبوي الجديدة
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              alignment: WrapAlignment.spaceEvenly,
              children: [
                // --- طلب الخروج ---
                if (requestStatus == 'exit_pending') ...[
                  ElevatedButton(
                    onPressed: () async {
                      String? error = await _api.approveExitRequest(
                        _parentId,
                        childId,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            error == null ? "تم السماح بالخروج" : "فشل: $error",
                          ),
                          backgroundColor: error == null
                              ? Colors.green
                              : Colors.red,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text("موقافة خروج"),
                  ),
                  ElevatedButton(
                    onPressed: () => _showRejectDialog(childId, 'exit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text("رفض خروج"), // زر الرفض
                  ),
                ],

                // --- طلب فتح القفل ---
                if (requestStatus == 'unlock_pending') ...[
                  ElevatedButton(
                    onPressed: () async {
                      String? error = await _api.approveUnlockRequest(
                        _parentId,
                        childId,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            error == null
                                ? "تم السماح بفتح القفل"
                                : "فشل: $error",
                          ),
                          backgroundColor: error == null
                              ? Colors.green
                              : Colors.red,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text("موقافة فتح"),
                  ),
                  ElevatedButton(
                    onPressed: () => _showRejectDialog(childId, 'unlock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text("رفض فتح"), // زر الرفض
                  ),
                ],

                // --- فتح القفل دائماً ---
                ElevatedButton(
                  onPressed: () async {
                    String? error = await _api.remoteUnlockChild(
                      _parentId,
                      childId,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          error == null ? "تم فتح القفل فوراً" : "فشل: $error",
                        ),
                        backgroundColor: error == null
                            ? Colors.teal
                            : Colors.red,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text("فتح القفل فوراً"),
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
