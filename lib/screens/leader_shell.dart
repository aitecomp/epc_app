import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';
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

  Future<void> _openForm({Member? member}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MemberFormScreen(member: member)),
    );
    if (saved == true && mounted) {
      setState(() {});
      toast(context, member == null ? 'تمت إضافة العضو بنجاح' : 'تم حفظ التعديلات');
    }
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
        onSeeAll: () => setState(() => _index = 1),
      ),
      MembersTab(
        store: store,
        onAddMember: () => _openForm(),
        onOpenMember: _openMember,
        onEditMember: (m) => _openForm(member: m),
        onDeleteMember: _confirmDelete,
      ),
      SettingsTab(store: store, onLogout: widget.onLogout),
    ];

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(_index), child: tabs[_index]),
      ),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.person_add_alt_1, size: 20),
              label: const Text('عضو جديد',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.plum.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            height: 66,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            indicatorColor: AppColors.softViolet,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, color: AppColors.muted),
                selectedIcon: Icon(Icons.dashboard, color: AppColors.purple),
                label: 'لوحة القيادة',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_2_outlined, color: AppColors.muted),
                selectedIcon: Icon(Icons.groups_2, color: AppColors.purple),
                label: 'الأعضاء',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined, color: AppColors.muted),
                selectedIcon: Icon(Icons.settings, color: AppColors.purple),
                label: 'الإعدادات',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
