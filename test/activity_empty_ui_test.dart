import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epc_app/core/store.dart';
import 'package:epc_app/screens/activities_tab.dart';

void main() {
  testWidgets('بطاقة النشاطات الفارغة تملأ عرض المحتوى للعضو والقائد', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await MemberStore.instance.init();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final leader in [false, true]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ActivitiesTab(
          store: MemberStore.instance,
          isLeader: leader,
          memberName: 'عضو',
          onOpenProfile: () {},
        )),
      ));
      await tester.pump();
      final card = find.byKey(const ValueKey('empty-activities-card'));
      expect(card, findsOneWidget);
      expect(tester.getSize(card).width, closeTo(328, 0.1));
    }
  });
}
