import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/member_card.dart';

class LeaderProfileTab extends StatelessWidget {
  final MemberStore store;
  final int pendingJoinCount;
  final VoidCallback? onOpenJoinRequests;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;
  final VoidCallback? onOpenDashboard;

  const LeaderProfileTab({
    super.key,
    required this.store,
    this.pendingJoinCount = 0,
    this.onOpenJoinRequests,
    required this.onEditProfile,
    required this.onOpenSettings,
    required this.onLogout,
    this.onOpenDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final leader = store.leaderMember;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(20, topInset(context) + 4, 20, 26),
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
                    ),
                    child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('بطاقتي',
                            style: TextStyle(
                                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                        Text('Economics Pioneers Club',
                            style: TextStyle(
                                color: AppColors.goldSoft, fontSize: 10, letterSpacing: 1.2)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.workspace_premium, size: 13, color: AppColors.goldSoft),
                        SizedBox(width: 4),
                        Text('القائد',
                            style: TextStyle(
                                color: AppColors.goldSoft,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'مرحباً، ${leader.fullName}',
                style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${leader.displaySpecialization} • ${leader.level} • ${leader.year}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12.5),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset(context)),
          child: Column(
            children: [
              MemberCardFlip(member: leader),
              const SizedBox(height: 20),
              SectionCard(
                title: 'إدارة الحساب والنادي',
                child: Column(
                  children: [
                    if (onOpenJoinRequests != null)
                      _tile(
                        icon: Icons.how_to_reg_rounded,
                        title: 'طلبات الانضمام للنادي',
                        subtitle: pendingJoinCount > 0
                            ? 'لديك $pendingJoinCount طلبات جديدة بانتظار قرارك'
                            : 'مراجعة وقبول أو رفض طلبات العضوية',
                        color: AppColors.gold,
                        badge: pendingJoinCount,
                        onTap: onOpenJoinRequests!,
                      ),
                    if (onOpenDashboard != null)
                      _tile(
                        icon: Icons.dashboard_customize_outlined,
                        title: 'لوحة القيادة',
                        subtitle: 'إحصاءات النادي وإدارة الأعضاء',
                        onTap: onOpenDashboard!,
                      ),
                    _tile(
                      icon: Icons.edit_outlined,
                      title: 'تعديل بطاقتي',
                      subtitle: 'الاسم، التخصص، المستوى والصورة',
                      onTap: onEditProfile,
                    ),
                    _tile(
                      icon: Icons.settings_outlined,
                      title: 'الإعدادات',
                      subtitle: 'بيانات الدخول والبيانات العامة',
                      onTap: onOpenSettings,
                    ),
                    _tile(
                      icon: Icons.logout,
                      title: 'تسجيل الخروج',
                      subtitle: 'الخروج من لوحة القيادة',
                      color: const Color(0xFFB91C1C),
                      onTap: onLogout,
                      last: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
    int badge = 0,
    bool last = false,
  }) {
    final tint = color ?? AppColors.purple;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ],
              ),
            ),
            if (badge > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_left, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
