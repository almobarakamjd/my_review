import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_service.dart';

class UpdateManager {
  static const String _skippedVersionKey = 'skipped_update_version';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final updateInfo = await ApiService().checkUpdate();

      if (updateInfo != null && updateInfo['url'] != null) {
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        String currentVersion = packageInfo.version;
        String remoteVersion = updateInfo['version'] ?? '0.0.0';

        // Check if user already skipped this version
        final prefs = await SharedPreferences.getInstance();
        final String? skippedVersion = prefs.getString(_skippedVersionKey);

        if (skippedVersion == remoteVersion) {
          // User skipped this exact version, do not show dialog
          return;
        }

        if (_isVersionGreaterThan(remoteVersion, currentVersion)) {
          if (context.mounted) {
            _showUpdateDialog(context, updateInfo, remoteVersion);
          }
        }
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  static bool _isVersionGreaterThan(String newVersion, String currentVersion) {
    try {
      List<String> newV = newVersion.split('.');
      List<String> currentV = currentVersion.split('.');

      for (int i = 0; i < newV.length && i < currentV.length; i++) {
        int n = int.parse(newV[i]);
        int c = int.parse(currentV[i]);
        if (n > c) return true;
        if (n < c) return false;
      }
      return newV.length > currentV.length;
    } catch (e) {
      return false;
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    Map<String, dynamic> updateInfo,
    String remoteVersion,
  ) {
    // We ignore the force flag for the UI controls to always allow exit
    // bool isForce = updateInfo['force'] == true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: Text("تحديث جديد متاح $remoteVersion"),
          content: Text(
            "يوجد تحديث جديد للتطبيق. هل ترغب بالتحديث الآن؟\n\n${updateInfo['url']}",
          ),
          actions: [
            // Always show Not Now button
            TextButton(
              onPressed: () async {
                // Save preference to skip this version
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(_skippedVersionKey, remoteVersion);

                Navigator.of(ctx).pop();
              },
              child: const Text("ليس الآن (تجاهل هذه النسخة)"),
            ),
            ElevatedButton(
              onPressed: () async {
                final Uri url = Uri.parse(updateInfo['url']);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text("تحديث الآن"),
            ),
          ],
        ),
      ),
    );
  }
}
