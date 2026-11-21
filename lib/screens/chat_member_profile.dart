import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/member_card.dart';

/// ملف عام للعضو داخل الدردشة؛ لا يعرض رقم الهاتف أو بيانات الدخول.
class ChatMemberProfile extends StatelessWidget {
  final Member member;
  const ChatMemberProfile({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const SizedBox(height: 12),
        Center(child: MemberAvatar(member: member, size: 96)),
        const SizedBox(height: 14),
        Text(member.fullName, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 4),
        Text(member.role, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.purple, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        const Text('بطاقة العضوية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 12),
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: MemberCardFlip(member: member, publicView: true))),
        const SizedBox(height: 8),
        const Text('اضغط على البطاقة لقلبها', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 24),
        SectionCard(title: 'معلومات العضو', child: Column(children: [
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.school_outlined), title: const Text('التخصص'), subtitle: Text(member.displaySpecialization)),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.account_tree_outlined), title: const Text('الكلية'), subtitle: Text(member.branch)),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.trending_up), title: const Text('المستوى الدراسي'), subtitle: Text(member.level)),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.badge_outlined), title: const Text('الصفة'), subtitle: Text(member.role)),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today_outlined), title: const Text('تاريخ الانضمام'), subtitle: Text(member.joinedLabel)),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_month_outlined), title: const Text('السنة الجامعية'), subtitle: Text(member.year)),
        ])),
      ]),
    );
  }
}
