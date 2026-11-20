import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epc_app/core/store.dart';
import 'package:epc_app/core/theme.dart';
import 'package:epc_app/screens/leader_shell.dart';

Future<void> loadFonts() async {
  final loader = FontLoader('Tajawal');
  for (final p in [
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
    'assets/fonts/Tajawal-ExtraBold.ttf',
  ]) {
    loader.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer)));
  }
  await loader.load();
}

List<Map<String, dynamic>> _seed() => [
      {
        'id': '1', 'firstName': 'محمد', 'lastName': 'بن عيسى', 'specialization': 'اقتصاد',
        'level': 'ليسانس 3', 'year': 'السنة الثالثة', 'regNumber': '20260001', 'password': '1234',
        'phone': '0551234567', 'email': 'm@epc.dz', 'role': 'عضو أساسي', 'photo': '',
        'joinedAt': '2026-10-01T10:00:00.000',
      },
      {
        'id': '2', 'firstName': 'أمينة', 'lastName': 'قاسمي', 'specialization': 'تسيير مالي ومحاسبة',
        'level': 'ماستر 1', 'year': 'السنة الرابعة', 'regNumber': '20260002', 'password': '1234',
        'phone': '0552234567', 'email': 'a@epc.dz', 'role': 'نائب القائد', 'photo': '',
        'joinedAt': '2026-10-03T10:00:00.000',
      },
      {
        'id': '3', 'firstName': 'يوسف', 'lastName': 'مرابط', 'specialization': 'مالية وبنوك',
        'level': 'ليسانس 2', 'year': 'السنة الثانية', 'regNumber': '20260003', 'password': '1234',
        'phone': '', 'email': '', 'role': 'عضو', 'photo': '',
        'joinedAt': '2026-10-08T10:00:00.000',
      },
      {
        'id': '4', 'firstName': 'سارة', 'lastName': 'بلحاج', 'specialization': 'اقتصاد',
        'level': 'ماستر 2', 'year': 'السنة الخامسة', 'regNumber': '20260004', 'password': '1234',
        'phone': '', 'email': '', 'role': 'أمين عام', 'photo': '',
        'joinedAt': '2026-10-11T10:00:00.000',
      },
      {
        'id': '5', 'firstName': 'رياض', 'lastName': 'زروقي', 'specialization': 'تجارة دولية',
        'level': 'ليسانس 1', 'year': 'السنة الأولى', 'regNumber': '20260005', 'password': '1234',
        'phone': '', 'email': '', 'role': 'عضو', 'photo': '',
        'joinedAt': '2026-10-14T10:00:00.000',
      },
    ];

void main() {
  testWidgets('golden: لوحة القيادة', (tester) async {
    await loadFonts();
    SharedPreferences.setMockInitialValues({
      'epc_members_v2': jsonEncode(_seed()),
    });
    final store = MemberStore.instance;
    await store.init();

    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: RepaintBoundary(
          key: const ValueKey('dash'),
          child: LeaderShell(store: store, onLogout: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byKey(const ValueKey('dash')), matchesGoldenFile('golden/dashboard.png'));
  });
}
