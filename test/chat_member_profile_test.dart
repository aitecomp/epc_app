import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:epc_app/core/store.dart';
import 'package:epc_app/core/theme.dart';
import 'package:epc_app/screens/chat_member_profile.dart';
import 'package:epc_app/widgets/member_card.dart';

void main() {
  testWidgets('ملف عضو الدردشة يعرض البطاقة الحقيقية وQR والمعلومات دون إجراءات الحساب', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final member = Member(
      id: 'm1', firstName: 'سالم', lastName: 'أحمد',
      specialization: 'إدارة أعمال', level: 'السنة الأولى (L1)',
      year: '2026/2027', regNumber: 'member-reg', password: 'secret-pass',
      phone: 'member-phone', email: 'member-email',
    );
    await tester.pumpWidget(MaterialApp(theme: AppTheme.build(), home: ChatMemberProfile(member: member)));
    await tester.pumpAndSettle();
    expect(find.byType(MemberCardFlip), findsOneWidget);
    expect(tester.widget<MemberCardFlip>(find.byType(MemberCardFlip)).publicView, isFalse);
    expect(find.text('secret-pass'), findsNothing);
    expect(find.text('تغيير الصورة'), findsNothing);
    expect(find.text('تسجيل الخروج'), findsNothing);
    await tester.ensureVisible(find.byType(MemberCardFlip));
    await tester.tap(find.byType(MemberCardFlip));
    await tester.pumpAndSettle();
    expect(find.byType(QrBlock), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.widget<QrBlock>(find.byType(QrBlock)).member.regNumber, 'member-reg');
    expect(find.text('member-reg'), findsWidgets);
    await tester.scrollUntilVisible(find.text('member-email').last, 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('member-phone'), findsWidgets);
    expect(find.text('member-email'), findsWidgets);
    expect(find.text('secret-pass'), findsNothing);
  });
}
