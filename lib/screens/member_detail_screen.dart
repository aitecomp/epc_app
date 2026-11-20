import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/member_card.dart';

class MemberDetailScreen extends StatelessWidget {
  final Member member;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MemberDetailScreen({
    super.key,
    required this.member,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text('بطاقة العضو', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          if (onEdit != null)
            IconButton(
              tooltip: 'تعديل',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: AppColors.purple),
            ),
          if (onDelete != null)
            IconButton(
              tooltip: 'حذف',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          MemberCardFlip(member: member),
          const SizedBox(height: 22),
          _InfoRow(icon: Icons.badge_outlined, label: 'رقم التسجيل', value: member.regNumber),
          _InfoRow(icon: Icons.school_outlined, label: 'التخصص', value: member.specialization),
          _InfoRow(icon: Icons.trending_up, label: 'المستوى الدراسي', value: member.level),
          _InfoRow(icon: Icons.calendar_month_outlined, label: 'السنة الجامعية', value: member.year),
          _InfoRow(icon: Icons.phone_outlined, label: 'الهاتف', value: member.phone.isEmpty ? '—' : member.phone),
          _InfoRow(icon: Icons.mail_outline, label: 'البريد الإلكتروني', value: member.email.isEmpty ? '—' : member.email),
          _InfoRow(icon: Icons.workspace_premium_outlined, label: 'الصفة', value: member.role),
          _InfoRow(icon: Icons.event_available_outlined, label: 'تاريخ الانضمام', value: member.joinedLabel),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.purple),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
