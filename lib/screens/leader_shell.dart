import 'package:flutter/material.dart';

import '../core/cloud_sync.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/glass_nav.dart';
import 'leader_profile_tab.dart';
import 'member_detail_screen.dart';
import 'member_form_screen.dart';
import 'members_tab.dart';
import 'overview_tab.dart';
import 'settings_tab.dart';

class LeaderShell extends StatefulWidget {
  final MemberStore store;
  final VoidCallback onLogout;

  const LeaderShell({super.key, required this.store, required this.onLogout});

  @override
  State<LeaderShell> createState() => _LeaderShellState();
}

class _LeaderShellState extends State<LeaderShell> {
  int _index = 0;

  MemberStore get store => widget.store;

  Future<void> _openForm({Member? member, bool leaderMode = false}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MemberFormScreen(member: member, leaderMode: leaderMode),
      ),
    );
    if (saved == true && mounted) {
      setState(() {});
      if (!leaderMode) CloudSync.pushInBackground(store);
      toast(
        context,
        leaderMode
            ? 'تم تحديث بطاقتك'
            : (member == null ? 'تمت إضافة العضو بنجاح' : 'تم حفظ التعديلات'),
      );
    }
  }

  void _openMembers() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.cream,
          body: MembersTab(
            store: store,
            onBack: () => Navigator.pop(context),
            onAddMember: () => _openForm(),
            onOpenMember: _openMember,
            onEditMember: (m) => _openForm(member: m),
            onDeleteMember: _confirmDelete,
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.cream,
          body: SettingsTab(
            store: store,
            onBack: () => Navigator.pop(context),
            onLogout: widget.onLogout,
          ),
        ),
      ),
    );
  }

  void _openMember(Member member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemberDetailScreen(
          member: member,
          onEdit: () {
            Navigator.pop(context);
            _openForm(member: member);
          },
          onDelete: () {
            Navigator.pop(context);
            _confirmDelete(member);
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف العضو', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('هل تريد حذف « ${member.fullName} » من النادي؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await store.deleteMember(member.id);
    CloudSync.pushInBackground(store);
    if (mounted) {
      setState(() {});
      toast(context, 'تم حذف العضو');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      OverviewTab(
        store: store,
        onAddMember: () => _openForm(),
        onOpenMember: _openMember,
        onSeeAll: _openMembers,
        onOpenMembers: _openMembers,
        onOpenSettings: _openSettings,
      ),
      LeaderProfileTab(
        store: store,
        onEditProfile: () => _openForm(member: store.leaderMember, leaderMode: true),
        onOpenSettings: _openSettings,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.cream,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(_index), child: tabs[_index]),
      ),
      bottomNavigationBar: GlassNavBar(
        index: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          GlassNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'الرئيسية',
          ),
          GlassNavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person_rounded,
            label: 'البروفيل',
          ),
        ],
      ),
    );
  }
}
