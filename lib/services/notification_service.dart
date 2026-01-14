import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  // Singleton Pattern (نسخة واحدة مشتركة للتطبيق كله)
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 1. دالة التهيئة (تعمل عند تشغيل التطبيق)
  Future<void> init() async {
    // تهيئة بيانات التوقيت (مهم جداً للجدولة)
    tz.initializeTimeZones();

    // إعدادات الأندرويد (تأكد من وجود أيقونة باسم ic_launcher في مجلد mipmap)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // إعدادات iOS (طلب الأذونات المبدئية)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // 2. دالة طلب الإذن (مهمة لأندرويد 13 فما فوق)
  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  // 3. دالة جدولة التنبيه اليومي
  Future<void> scheduleDailyNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, // ID التنبيه (ثابت ليحل محله تنبيه اليوم التالي)
      'حان وقت المراجعة! 🚀', // العنوان
      'أسئلة اليوم بانتظارك، لا تتركها تتراكم عليك 💪', // المحتوى
      _nextInstanceOfThreePM(), // الوقت (3 عصراً)
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel', // ID القناة
          'تنبيهات المراجعة اليومية', // اسم القناة
          channelDescription: 'تذكير يومي لحل المسائل',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // هذا السطر هو التحديث الجديد للإصدارات الحديثة (بدلاً من androidAllowWhileIdle)
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // التكرار يومياً في نفس الوقت
    );
  }

  // 4. حساب الوقت (الساعة 3 عصراً القادمة)
  tz.TZDateTime _nextInstanceOfThreePM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // الساعة 15 تعني 3 عصراً بنظام 24 ساعة
    // الدقيقة 0، الثانية 0
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      15,
      0,
    );

    // إذا كانت الساعة 3 قد مرت اليوم، نجدولها لغد
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
