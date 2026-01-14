import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api_service.dart';

class UpdateManager {
  // دالة ثابتة يمكن استدعاؤها من أي مكان
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final updateInfo = await ApiService().checkUpdate();

      // إذا وجدنا تحديث، والرابط موجود
      if (updateInfo != null && updateInfo['url'] != null) {
        _showUpdateDialog(context, updateInfo);
      }
    } catch (e) {
      print("Update check failed: $e");
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    Map<String, dynamic> updateInfo,
  ) {
    showDialog(
      context: context,
      barrierDismissible:
          !(updateInfo['force'] == true), // إذا إجباري نمنع الإغلاق
      builder: (ctx) => WillPopScope(
        onWillPop: () async => !(updateInfo['force'] == true),
        child: AlertDialog(
          title: Text("تحديث جديد متاح ${updateInfo['version']}"),
          content: Text(
            "يجب تحديث التطبيق للاستمرار.\n\n${updateInfo['url']}",
          ), // يعرض الرابط للتأكد
          actions: [
            ElevatedButton(
              onPressed: () async {
                final Uri url = Uri.parse(updateInfo['url']);
                if (await canLaunchUrl(url)) {
                  await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  ); // يفتح في المتصفح
                } else {
                  print("Could not launch $url");
                }
              },
              child: Text("تحديث الآن"),
            ),
          ],
        ),
      ),
    );
  }
}
