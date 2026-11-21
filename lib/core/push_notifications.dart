import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cloud_sync.dart';
import 'notifications.dart';
import 'store.dart';

@pragma('vm:entry-point')
Future<void> epcBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  await Notifications.init(requestPermission: false);
  await PushNotifications.handle(message);
}

class PushNotifications {
  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(epcBackgroundMessage);
      FirebaseMessaging.onMessage.listen(handle);
      await FirebaseMessaging.instance.subscribeToTopic('epc_activities');
      _initialized = true;
    } catch (e) {
      debugPrint('Firebase messaging initialization failed: $e');
    }
  }

  static Future<void> handle(RemoteMessage message) async {
    final data = message.data;
    final id = data['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final reminderId = Notifications.idFor('activity_$id');
    if (data['operation'] == 'delete') {
      await Notifications.cancel(reminderId);
      return;
    }
    final title = data['title']?.toString() ?? 'نشاط النادي';
    final date = DateTime.tryParse(data['at']?.toString() ?? '');
    final place = data['place']?.toString() ?? '';
    final updated = data['operation'] == 'update';
    await Notifications.showNow(
      id: Notifications.idFor('new_$id'),
      title: updated ? 'تحديث نشاط النادي' : 'نشاط جديد في النادي',
      body: title,
    );
    await Notifications.cancel(reminderId);
    if (date != null && date.isAfter(DateTime.now())) {
      await Notifications.scheduleAt(
        id: reminderId,
        when: date,
        title: 'تذكير: $title',
        body: place.isEmpty ? 'حان وقت النشاط' : place,
      );
    }
  }

  static Future<bool> publish(Activity activity, {bool updated = false, bool deleted = false}) async {
    if (!CloudSync.enabled) return false;
    try {
      final response = await http.post(
        Uri.parse('${CloudSync.url.replaceAll(RegExp(r'/+$'), '')}/notify'),
        headers: {'x-sync-key': CloudSync.key, 'content-type': 'application/json'},
        body: jsonEncode({
          'id': activity.id,
          'title': activity.title,
          'place': activity.place,
          'at': activity.at.toUtc().toIso8601String(),
          'operation': deleted ? 'delete' : (updated ? 'update' : 'create'),
        }),
      ).timeout(const Duration(seconds: 25));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
