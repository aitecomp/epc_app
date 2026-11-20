import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epc_app/core/store.dart';

Member m(String id, String reg, {DateTime? updatedAt}) => Member(
      id: id,
      firstName: 'عضو',
      lastName: id,
      specialization: 'اقتصاد',
      level: 'ليسانس 1',
      year: 'السنة الأولى',
      regNumber: reg,
      password: '1234',
      updatedAt: updatedAt,
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MemberStore.instance.init();
  });

  test('دمج نسخة السحابة: إضافة عضو جديد', () async {
    final store = MemberStore.instance;
    final changed = await store.applyRemotePayload({
      'members': [m('a', '20260001').toJson()],
      'deleted': [],
    });
    expect(changed, isTrue);
    expect(store.members.length, 1);
    expect(store.members.first.regNumber, '20260001');
  });

  test('دمج نسخة السحابة: الحذف ينتقل بين الأجهزة', () async {
    final store = MemberStore.instance;
    await store.saveMember(m('a', '20260001'));
    await store.saveMember(m('b', '20260002'));
    expect(store.members.length, 2);

    await store.applyRemotePayload({
      'members': [],
      'deleted': [
        {'id': 'a', 'at': DateTime.now().add(const Duration(minutes: 1)).toIso8601String()},
      ],
    });

    expect(store.members.length, 1);
    expect(store.members.first.id, 'b');
  });

  test('دمج نسخة السحابة: الأحدث يفوز', () async {
    final store = MemberStore.instance;
    await store.saveMember(m('a', '20260001'));

    final newer = m('a', '20260001', updatedAt: DateTime.now().add(const Duration(days: 1)))
      ..firstName = 'اسم محدّث';
    await store.applyRemotePayload({'members': [newer.toJson()], 'deleted': []});

    expect(store.members.first.firstName, 'اسم محدّث');
  });

  test('تصدير الحزمة يحتوي الأعضاء والمحذوفين', () async {
    final store = MemberStore.instance;
    await store.saveMember(m('a', '20260001'));
    await store.deleteMember('a');
    final payload = store.exportPayload();
    expect(payload['members'], isEmpty);
    expect((payload['deleted'] as List).length, 1);
  });
}
