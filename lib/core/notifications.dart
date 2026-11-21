import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// خدمة الإشعارات: إشعار فوري عند نشر نشاط + منبّه في اليوم والوقت المحدّد
class Notifications {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static void Function(String)? onActivityTap;
  static String? launchActivityId;
  static bool get ready => _ready;

  static const String channelId = 'epc_activities';
  static const String channelName = 'نشاطات النادي';
  static const String channelDesc = 'إشعارات النشاطات والفعاليات الخاصة بنادي رواد الاقتصاد';

  /// تهيئة الخدمة (تُستدعى مرة واحدة عند الإقلاع)
  static Future<void> init({bool requestPermission = true}) async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Africa/Algiers'));
      } catch (_) {
        // يبقى التوقيت المحلي للجهاز
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      );
      const settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) onActivityTap?.call(payload);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        launchActivityId = launch?.notificationResponse?.payload;
      }
      _ready = true;
      if (requestPermission) await requestPermissions();
    } catch (_) {
      _ready = false;
    }
  }

  /// طلب صلاحيات الإشعارات والمنبّه الدقيق
  static Future<void> requestPermissions() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  static NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList(const [0, 500, 220, 500]),
          styleInformation: const BigTextStyleInformation(''),
          color: const Color(0xFF80620F),
          ticker: 'نادي رواد الاقتصاد',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

  /// إشعار منبّه مستمر على أندرويد، مع زر لإيقافه.
  /// دعم تكرار الصوت تحدده سياسة الإشعارات والشركة المصنّعة للجهاز.
  static NotificationDetails get _alarmDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      'epc_activity_alarm_v1', 'منبّهات النشاطات',
      channelDescription: 'تذكير النشاط في موعده',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(const [0, 800, 300, 800, 300]),
      ongoing: true,
      autoCancel: false,
      additionalFlags: Int32List.fromList(const [4]),
      actions: const [AndroidNotificationAction('stop_alarm', 'إيقاف المنبّه', cancelNotification: true)],
      color: const Color(0xFF80620F),
    ),
    iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  /// إشعار فوري
  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? activityId,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details,
        payload: activityId,
      );
    } catch (_) {}
  }

  /// جدولة منبّه في وقت محدّد (مع اهتزاز)
  static Future<bool> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? activityId,
  }) async {
    if (!_ready) return false;
    final at = tz.TZDateTime.from(when, tz.local);
    if (!at.isAfter(tz.TZDateTime.now(tz.local))) return false;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: at,
        notificationDetails: _alarmDetails,
        payload: activityId,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return true;
    } catch (_) {
      // بعض الأجهزة تمنع المنبّه الدقيق — نستخدم الوضع التقريبي
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: at,
          notificationDetails: _alarmDetails,
          payload: activityId,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  static Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// رقم إشعار ثابت مبني على معرّف النشاط (FNV-1a)
  static int idFor(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
