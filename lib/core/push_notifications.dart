import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_notifier.dart';
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

  /// رمز الجهاز لإرسال إشعارات مخصّصة لصاحب طلب الانضمام فقط
  static Future<String> getDeviceToken() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return '';
    try {
      return (await FirebaseMessaging.instance.getToken()) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> handle(RemoteMessage message) async {
    final data = message.data;
    final id = data['id']?.toString() ?? '';
    final kind = data['kind']?.toString() ?? '';
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final sessionReg = prefs.getString('epc_session_v2');
    final isLoggedInMember = sessionReg != null && sessionReg.isNotEmpty;

    // 1) إشعار قرار طلب الانضمام -> يصل حصراً للضيف صاحب الطلب فقط
    if (kind == 'join_decision') {
      final savedReqId = prefs.getString('epc_last_join_req_id') ?? '';
      final savedGuestId = prefs.getString('epc_guest_id_v1') ?? '';
      final reqId = data['requestId']?.toString() ?? id;
      final targetGuest = data['guestId']?.toString() ?? '';
      final isMyRequest = (savedReqId.isNotEmpty && savedReqId == reqId) ||
          (savedGuestId.isNotEmpty && targetGuest.isNotEmpty && savedGuestId == targetGuest);
      if (!isMyRequest) return;

      final approved = data['status'] == 'approved';
      final note = (data['note'] ?? '').toString().trim();
      final reg = (data['regNumber'] ?? '').toString();
      await Notifications.showNow(
        id: Notifications.idFor('join_dec_$reqId'),
        title: approved
            ? '🎉 تم قبول طلب انضمامك لنادي رواد الاقتصاد!'
            : 'بخصوص طلب انضمامك لنادي رواد الاقتصاد',
        body: approved
            ? 'أصبحت عضواً رسمياً! سجّل الدخول برقم التسجيل ($reg)${note.isNotEmpty ? ' • $note' : ''}'
            : (note.isNotEmpty ? 'نعتذر لعدم قبول الطلب حالياً: $note' : 'نعتذر لعدم قبول طلبك في هذه الدورة.'),
      );
      return;
    }

    // 2) إشعار طلب انضمام جديد -> يصل للقائد فقط
    if (kind == 'join_request_new') {
      if (!isLoggedInMember) return;
      final storedLeader = prefs.getString('epc_leader_reg');
      final leaderReg = (storedLeader != null && storedLeader.isNotEmpty)
          ? storedLeader
          : MemberStore.instance.leaderReg;
      if (sessionReg != leaderReg) return;
      final applicant = data['applicantName']?.toString() ?? 'متقدم جديد';
      final spec = data['specialization']?.toString() ?? '';
      await Notifications.showNow(
        id: Notifications.idFor('join_new_$id'),
        title: 'طلب انضمام جديد للنادي',
        body: spec.isNotEmpty ? '$applicant — $spec' : applicant,
      );
      return;
    }

    // 3) إشعار الدردشة -> للأعضاء والقائد فقط (وليس للضيوف ولا للمرسِل)
    if (kind == 'chat') {
      if (!isLoggedInMember) return;
      final hash = base64Url.encode(sha256.convert(utf8.encode(sessionReg)).bytes).replaceAll('=', '');
      if (hash == data['senderHash']) return;
      final senderName = data['senderName']?.toString() ?? '';
      await Notifications.showNow(
        id: Notifications.idFor('chat_$id'),
        activityId: 'chat',
        title: senderName.isNotEmpty ? 'رسالة من $senderName' : 'رسالة جديدة',
        body: 'رسالة جديدة في دردشة أعضاء النادي',
      );
      return;
    }

    // 4) إشعارات النشاطات المجدولة والمنبّهات -> للأعضاء والقائد فقط (لا تصل للضيوف)
    if (!isLoggedInMember) return;

    final reminderId = Notifications.idFor('activity_$id');
    if (data['operation'] == 'delete') {
      await Notifications.cancel(reminderId);
      return;
    }
    final title = data['title']?.toString() ?? 'نشاط النادي';
    final date = DateTime.tryParse(data['at']?.toString() ?? '')?.toLocal();
    final place = data['place']?.toString() ?? '';
    final updated = data['operation'] == 'update';
    await Notifications.showNow(
      id: Notifications.idFor('new_$id'),
      activityId: id,
      title: updated ? 'تحديث نشاط النادي' : 'نشاط جديد في النادي',
      body: title,
    );
    if (MemberStore.instance.ready) await CloudSync.syncNow(MemberStore.instance);
    await Notifications.cancel(reminderId);
    if (date != null) {
      final alarmWhen = ActivityNotifier.alarmTimeFor(date);
      if (alarmWhen != null) {
        await Notifications.scheduleAt(
          id: reminderId,
          activityId: id,
          when: alarmWhen,
          title: 'منبّه قبل 10 دقائق: $title',
          body: place.isEmpty ? 'النشاط يبدأ بعد 10 دقائق' : '$place • يبدأ بعد 10 دقائق',
        );
      }
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
