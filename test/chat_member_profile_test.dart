import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:epc_app/core/store.dart';
import 'package:epc_app/screens/chat_member_profile.dart';
import 'package:epc_app/widgets/member_card.dart';

void main() {
  testWidgets('ملف عضو الدردشة يعرض الصورة والبيانات العامة فقط', (tester) async {
    final member = Member(
      id: 'm1', firstName: 'سالم', lastName: 'أحمد',
      specialization: 'إدارة أعمال', level: 'السنة الأولى (L1)',
      year: '2026/2027', regNumber: 'secret-reg', password: 'secret-pass',
      phone: 'secret-phone', email: 'secret-email',
    );
    await tester.pumpWidget(MaterialApp(home: ChatMemberProfile(member: member)));
    await tester.pump();
    expect(find.text('سالم أحمد'), findsWidgets);
    expect(find.byType(MemberCardFlip), findsOneWidget);
    expect(find.byType(MemberAvatar), findsOneWidget);
    expect(find.text('إدارة أعمال'), findsWidgets);
    expect(find.text('secret-phone'), findsNothing);
    expect(find.text('secret-email'), findsNothing);
    expect(find.text('secret-pass'), findsNothing);
    expect(find.text('secret-reg'), findsNothing);
    await tester.tap(find.byType(MemberCardFlip));
    await tester.pumpAndSettle();
    expect(find.text('secret-reg'), findsNothing);
    expect(find.text('secret-phone'), findsNothing);
    expect(find.byType(QrBlock), findsNothing);
    expect(find.text('بطاقة العضوية'), findsWidgets);
  });
}
