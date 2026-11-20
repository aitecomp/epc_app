import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/member_card.dart';

class OverviewTab extends StatelessWidget {
  final MemberStore store;
  final VoidCallback onAddMember;
  final void Function(Member) onOpenMember;
  final VoidCallback onSeeAll;

  const OverviewTab({
    super.key,
    required this.store,
    required this.onAddMember,
    required this.onOpenMember,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final members = store.members;
    final recent = members.reversed.take(4).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _header(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  _StatTile(
                    icon: Icons.groups_2_outlined,
                    label: 'الأعضاء',
                    value: '${store.totalMembers}',
                    tint: AppColors.purple,
                  ),
                  _StatTile(
                    icon: Icons.account_tree_outlined,
                    label: 'التخصصات',
                    value: '${store.specializationsCount}',
                    tint: const Color(0xFF0E7490),
                  ),
                  _StatTile(
                    icon: Icons.workspace_premium_outlined,
                    label: 'الصفات القيادية',
                    value: '${store.leadersCount}',
                    tint: AppColors.gold,
                  ),
                  _StatTile(
                    icon: Icons.photo_camera_outlined,
                    label: 'صور مكتملة',
                    value: '${store.withPhotoCount}',
                    tint: const Color(0xFF15803D),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (members.isEmpty)
                EmptyState(
                  icon: Icons.group_add_outlined,
                  title: 'النادي جاهز لاستقبال أعضائه',
                  subtitle: 'لا يوجد أعضاء بعد. ابدأ بإضافة أول عضو في النادي\nوسيظهر هنا فوراً.',
                  action: SizedBox(
                    width: 200,
                    child: PrimaryButton(
                      label: 'إضافة عضو',
                      icon: Icons.person_add_alt_1,
                      onPressed: onAddMember,
                    ),
                  ),
                )
              else ...[
                SectionCard(
                  title: 'التوزيع حسب التخصص',
                  trailing: ChipTag(text: '${store.specializationsCount} تخصصاً'),
                  child: _bars(store.bySpecialization, AppColors.purple),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'التوزيع حسب السنة الجامعية',
                  child: _bars(store.byYear, AppColors.gold),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'أحدث الأعضاء',
                  trailing: TextButton(
                    onPressed: onSeeAll,
                    child: const Text('عرض الكل', style: TextStyle(fontSize: 12.5)),
                  ),
                  child: Column(
                    children: [
                      for (final m in recent)
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => onOpenMember(m),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                MemberAvatar(member: m, size: 42),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m.fullName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13.5, fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 2),
                                      Text('${m.specialization} • ${m.level}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 11.5, color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_left, color: AppColors.muted, size: 20),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _bars(Map<String, int> data, Color tint) {
    if (data.isEmpty) {
      return const Text('لا توجد بيانات', style: TextStyle(color: AppColors.muted, fontSize: 13));
    }
    final total = data.values.fold<int>(0, (sum, v) => sum + v);
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                    Text('${e.value}',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w800, color: tint)),
                    Text('  •  ${(e.value / total * 100).round()}%',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: e.value / total,
                    minHeight: 7,
                    backgroundColor: AppColors.softViolet,
                    valueColor: AlwaysStoppedAnimation(tint),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 58, 20, 24),
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
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.75), width: 1.5),
                ),
                child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('لوحة القيادة',
                        style: TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Economics Pioneers Club',
                        style: TextStyle(color: AppColors.goldSoft, fontSize: 9.5, letterSpacing: 1.3)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium, size: 13, color: AppColors.goldSoft),
                    SizedBox(width: 4),
                    Text('قائد النادي',
                        style: TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('نظرة عامة على النادي',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'تابع أعضاءك، تخصصاتهم، وتوزيعهم الدراسي من مكان واحد.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12.5, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.1)),
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
