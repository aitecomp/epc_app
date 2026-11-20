import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:epc_app/core/store.dart';
import 'package:epc_app/core/theme.dart';
import 'package:epc_app/widgets/member_card.dart';

Future<void> loadFonts() async {
  for (final entry in {
    'Tajawal': [
      'assets/fonts/Tajawal-Regular.ttf',
      'assets/fonts/Tajawal-Bold.ttf',
      'assets/fonts/Tajawal-ExtraBold.ttf',
    ],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

void main() {
  testWidgets('golden: بطاقة العضو', (tester) async {
    await loadFonts();
    final member = Member(
      id: '1',
      firstName: 'محمد',
      lastName: 'بن عيسى',
      specialization: 'اقتصاد',
      level: 'ليسانس 3',
      year: 'السنة الثالثة',
      regNumber: '20260001',
      password: 'x',
      phone: '0551234567',
      email: 'mohamed@epc.dz',
      role: 'عضو أساسي',
    );

    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Scaffold(
          backgroundColor: AppColors.cream,
          body: RepaintBoundary(
            key: const ValueKey('card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: MemberCardFlip(member: member)),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/member_card.png'),
        tester.element(find.byType(MemberCardFlip)),
      );
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('card')),
      matchesGoldenFile('golden/card_front.png'),
    );
  });

  testWidgets('golden: الوجه الخلفي للبطاقة', (tester) async {
    await loadFonts();
    final member = Member(
      id: '1',
      firstName: 'محمد',
      lastName: 'بن عيسى',
      specialization: 'اقتصاد نقدي وبنكي',
      level: 'السنة الثالثة (L3)',
      year: '2026/2027',
      regNumber: '20260001',
      password: 'x',
      phone: '0551234567',
      email: 'mohamed@epc.dz',
      role: 'عضو أساسي',
    );

    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Scaffold(
          backgroundColor: AppColors.cream,
          body: RepaintBoundary(
            key: const ValueKey('cardback'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: MemberCardFlip(member: member, initiallyFlipped: true)),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/member_card.png'),
        tester.element(find.byType(MemberCardFlip)),
      );
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('cardback')),
      matchesGoldenFile('golden/card_back.png'),
    );
  });
}
