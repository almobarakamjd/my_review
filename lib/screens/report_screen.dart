import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String _message = "جاري تحميل التقرير...";
  List<dynamic> _logs = [];
  String _period = 'month'; // 'week', 'month', 'year'

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getInt('student_id');

    if (studentId == null) {
      setState(() {
        _message = "لم يتم تسجيل الدخول";
        _isLoading = false;
      });
      return;
    }

    // تصحيح الخطأ هنا: استخدام الأسماء (Named Parameters)
    final res = await _api.getReport(studentId: studentId, period: _period);

    if (res['status'] == 'success') {
      setState(() {
        _logs = res['data'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _message = "فشل تحميل البيانات: ${res['message']}";
        _isLoading = false;
      });
    }
  }

  // Calculate stats
  Map<String, dynamic> _calculateStats() {
    if (_logs.isEmpty) return {};

    int totalScore = 0;
    int maxScore = _logs.length * 10;
    Map<String, int> subjectScores = {};

    for (var log in _logs) {
      totalScore += (log['score'] as int? ?? 0);

      if (log['details'] != null && log['details'] is Map) {
        Map details = log['details'];
        if (details.containsKey('breakdown')) {
          Map breakdown = details['breakdown'];
          breakdown.forEach((subj, count) {
            subjectScores[subj.toString()] =
                (subjectScores[subj.toString()] ?? 0) + (count as int);
          });
        }
      }
    }

    double percentage = maxScore == 0 ? 0 : (totalScore / maxScore * 100);

    return {
      "total": totalScore,
      "max": maxScore,
      "percentage": percentage,
      "subjects": subjectScores,
    };
  }

  String _getGrade(double percentage) {
    if (percentage >= 90) return "ممتاز";
    if (percentage >= 80) return "جيد جداً";
    if (percentage >= 70) return "جيد";
    if (percentage >= 50) return "مقبول";
    return "ضعيف";
  }

  Color _getGradeColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 80) return Colors.blue;
    if (percentage >= 70) return Colors.orange;
    if (percentage >= 50) return Colors.amber;
    return Colors.red;
  }

  String _getPeriodLabel() {
    switch (_period) {
      case 'week':
        return 'تقرير الأسبوع';
      case 'month':
        return 'تقرير الشهر';
      case 'year':
        return 'تقرير السنة';
      default:
        return 'التقرير';
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    final hasData = _logs.isNotEmpty;
    final double percentage = hasData ? (stats['percentage'] as double) : 0.0;
    final int total = hasData ? stats['total'] : 0;
    final int max = hasData ? stats['max'] : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("النتيجة"),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Filter Dropdown ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        "عرض خلال: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _period,
                        items: const [
                          DropdownMenuItem(value: 'week', child: Text("أسبوع")),
                          DropdownMenuItem(value: 'month', child: Text("شهر")),
                          DropdownMenuItem(value: 'year', child: Text("سنة")),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _period = val);
                            _fetchReport();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (!hasData)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30.0),
                        child: Text("لا توجد سجلات لهذه الفترة"),
                      ),
                    )
                  else ...[
                    // --- RESULT CARD (Certificate Style) ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(
                          color: _getGradeColor(percentage).withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _getPeriodLabel(),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _getGrade(percentage),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: _getGradeColor(percentage),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "الدرجة الكلية",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    "$total / $max",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              CircularProgressIndicator(
                                value: percentage / 100,
                                backgroundColor: Colors.grey[200],
                                color: _getGradeColor(percentage),
                                strokeWidth: 8,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    "النسبة المئوية",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    "${percentage.toInt()}%",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // --- PROGRESS CHART ---
                    const Text(
                      "التقدم الزمني",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      height: 220,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        reverse:
                            true, // Show newest on the right? No, standard is left-to-right but Arabic is RTL.
                        // In RTL context, list starts from right.
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final score = log['score'] as int? ?? 0;
                          final date = log['log_date'] as String? ?? "";
                          final shortDate = date.split('-').length > 2
                              ? "${date.split('-')[1]}/${date.split('-')[2]}"
                              : date;

                          final barHeight =
                              (score / 10) * 140; // Max height 140

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 30,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  "$score",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: barHeight.toDouble(),
                                  width: 12,
                                  decoration: BoxDecoration(
                                    color: score >= 7
                                        ? Colors.blue
                                        : (score >= 5
                                              ? Colors.orange
                                              : Colors.red),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  shortDate,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 25),

                    // --- SUBJECT BREAKDOWN ---
                    const Text(
                      "تفاصيل المواد",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (stats['subjects'] != null)
                      ...((stats['subjects'] as Map<String, int>).entries.map((
                        e,
                      ) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.menu_book,
                                color: Colors.blue,
                              ),
                            ),
                            title: Text(e.key),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${e.value} نقطة",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      })),
                  ],
                ],
              ),
            ),
    );
  }
}
