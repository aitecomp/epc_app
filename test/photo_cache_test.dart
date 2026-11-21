import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:epc_app/core/photo_cache.dart';
import 'package:epc_app/core/store.dart';
import 'package:epc_app/widgets/member_card.dart';

const photo = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPUCKhgYGBgYmBgYGBgAAALGgD0KRPd0QAAAABJRU5ErkJggg==';
void main() {
  test('decoded photo bytes are reused and changes are detected', () {
    expect(identical(PhotoBytesCache.decode(photo), PhotoBytesCache.decode(photo)), isTrue);
    final other = base64Encode([1, 2, 3]);
    expect(identical(PhotoBytesCache.decode(photo), PhotoBytesCache.decode(other)), isFalse);
    expect(() => PhotoBytesCache.decode('!invalid!'), throwsFormatException);
  });
  testWidgets('member avatar keeps the same image across rebuilds', (tester) async {
    final member = Member(id: '1', firstName: 'A', lastName: 'B', specialization: 'X',
        level: 'L1', year: '2026/2027', regNumber: '123', password: '', photoBase64: photo);
    Widget app() => MaterialApp(home: Scaffold(body: MemberAvatar(member: member)));
    await tester.pumpWidget(app());
    await tester.pump();
    final first = tester.widget<Image>(find.byType(Image)).image as MemoryImage;
    await tester.pumpWidget(app());
    final second = tester.widget<Image>(find.byType(Image)).image as MemoryImage;
    expect(identical(first.bytes, second.bytes), isTrue);
    expect(tester.widget<Image>(find.byType(Image)).gaplessPlayback, isTrue);
    member.photoBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGOs0AhgYGBgYmBgYGBgAAALkgD0DmG2vQAAAABJRU5ErkJggg==';
    await tester.pumpWidget(app());
    final updated = tester.widget<Image>(find.byType(Image)).image as MemoryImage;
    expect(identical(first.bytes, updated.bytes), isFalse);
  });
}
