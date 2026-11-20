import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epc_app/core/notifications.dart';
import 'package:epc_app/core/store.dart';

Activity _activity({
  required String id,
  String title = 'ندوة',
  Duration offset = const Duration(days: 2),
  DateTime? updatedAt,
}) =>
    Activity(
      id: id,
      title: title,
      details: 'تفاصيل',
      place: 'قاعة المحاضرات',
      at: DateTime.now().add(offset),
      createdAt: DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MemberStore.instance.init();
  });

  test('حفظ النشاطات وترتيبها (القادمة أولاً)', () async {
    final store = MemberStore.instance;
    await store.saveActivity(_activity(id: 'past', offset: const Duration(days: -3)));
    await store.saveActivity(_activity(id: 'near', offset: const Duration(hours: 5)));
    await store.saveActivity(_activity(id: 'far', offset: const Duration(days: 9)));

    final ids = store.activities.map((a) => a.id).toList();
    expect(ids, ['near', 'far', 'past']);
    expect(store.upcomingActivities.length, 2);
    expect(store.pastActivities.length, 1);
  });

  test('النشاط يُحفظ ويُقرأ من التخزين', () async {
    final store = MemberStore.instance;
    await store.saveActivity(_activity(id: 'a1', title: 'ورشة'));
    // إعادة التهيئة من نفس التخزين
    await MemberStore.instance.init();
    final loaded = MemberStore.instance.activities.firstWhere((a) => a.id == 'a1');
    expect(loaded.title, 'ورشة');
    expect(loaded.place, 'قاعة المحاضرات');
  });

  test('دمج نشاط قادم من السحابة يُعلَن كنشاط جديد', () async {
    final store = MemberStore.instance;
    final remote = _activity(id: 'remote1', title: 'نشاط من السحابة');
    final changed = await store.applyRemotePayload({
      'members': [],
      'deleted': [],
      'activities': [remote.toJson()],
      'deletedActivities': [],
    });

    expect(changed, isTrue);
    expect(store.activities.any((a) => a.id == 'remote1'), isTrue);
    expect(store.lastSyncedNewActivities.map((a) => a.id), contains('remote1'));
    expect(store.unseenActivitiesCount, 1);

    store.markActivitiesSeen();
    expect(store.unseenActivitiesCount, 0);
  });

  test('حذف نشاط يُسجّل حذفه في الحزمة السحابية', () async {
    final store = MemberStore.instance;
    await store.saveActivity(_activity(id: 'a2'));
    await store.deleteActivity('a2');

    final payload = store.exportPayload();
    expect((payload['activities'] as List).any((a) => a['id'] == 'a2'), isFalse);
    expect(
      (payload['deletedActivities'] as List).any((d) => d['id'] == 'a2'),
      isTrue,
    );
  });

  test('حذف قادم من السحابة يزيل النشاط محلياً', () async {
    final store = MemberStore.instance;
    await store.saveActivity(_activity(id: 'a3'));
    await store.applyRemotePayload({
      'members': [],
      'deleted': [],
      'activities': [],
      'deletedActivities': [
        {'id': 'a3', 'at': DateTime.now().add(const Duration(minutes: 1)).toIso8601String()},
      ],
    });
    expect(store.activities.any((a) => a.id == 'a3'), isFalse);
  });

  test('معرّف الإشعار ثابت لكل نشاط', () {
    final a = Notifications.idFor('activity_x1');
    final b = Notifications.idFor('activity_x1');
    final c = Notifications.idFor('activity_x2');
    expect(a, b);
    expect(a, isNot(c));
    expect(a, greaterThan(0));
  });

  test('صيغة الوقت والتاريخ بالعربية', () {
    final activity = Activity(
      id: 'x',
      title: 't',
      at: DateTime(2026, 11, 21, 16, 5),
    );
    expect(activity.dateLabel, '21/11/2026');
    expect(activity.timeLabel, '16:05');
    expect(activity.monthLabel, 'نوفمبر');
    expect(activity.weekdayLabel, isNotEmpty);
    expect(jsonDecode(jsonEncode(activity.toJson()))['title'], 't');
  });
}
