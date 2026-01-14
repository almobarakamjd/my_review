import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class LauncherHelper {
  static Future<void> launchPlatform() async {
    final Uri url = Uri.parse('https://amjd.law');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}
