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

void main() {
  testWidgets('golden: بروفيل القائد', (tester) async {
    await loadFonts();
    SharedPreferences.setMockInitialValues({'epc_members_v2': jsonEncode([])});
    await MemberStore.instance.init();

    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      builder: (c, k) => Directionality(textDirection: TextDirection.rtl, child: k!),
      home: RepaintBoundary(
        key: const ValueKey('lp'),
        child: LeaderShell(store: MemberStore.instance, onLogout: () {}),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('البروفيل'));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const ValueKey('lp')), matchesGoldenFile('golden/leader_profile.png'));
  });
}
