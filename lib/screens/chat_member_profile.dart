import 'package:flutter/material.dart';
import '../core/store.dart';
import 'profile_screen.dart';

/// يعرض نفس بطاقة العضو ومعلوماته دون إجراءات تعديل الحساب.
class ChatMemberProfile extends StatelessWidget {
  final Member member;
  const ChatMemberProfile({super.key, required this.member});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الملف الشخصي')),
        body: ProfileScreen(member: member, readOnly: true, onLogout: () {}),
      );
}
