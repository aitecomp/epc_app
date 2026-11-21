import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/activity_notifier.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/glass_nav.dart';
import 'activities_tab.dart';
import 'profile_screen.dart';

/// واجهة العضو: الرئيسية (النشاطات) + البروفيل (البطاقة)
class MemberShell extends StatefulWidget {
  final MemberStore store;
  final Member member;
  final VoidCallback onLogout;

  const MemberShell({
    super.key,
    required this.store,
    required this.member,
    required this.onLogout,
  });

  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> {
  int _index = 0;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) { if (mounted) setState(() {}); });
    widget.store.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ActivityNotifier.scheduleUpcoming(widget.store);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    widget.store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.store.currentMember ?? widget.member;
    final unseen = widget.store.unseenActivitiesCount;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kSystemUiOnLight,
      child: Scaffold(
      extendBody: true,
      backgroundColor: AppColors.cream,
      body: IndexedStack(
        index: _index,
        children: [
          ActivitiesTab(
            store: widget.store,
            isLeader: false,
            memberName: member.fullName,
            onOpenProfile: () => setState(() => _index = 1),
          ),
          ProfileScreen(member: member, onLogout: widget.onLogout),
        ],
      ),
      bottomNavigationBar: GlassNavBar(
        index: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          GlassNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: unseen > 0 ? 'الرئيسية • $unseen' : 'الرئيسية',
          ),
          const GlassNavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person_rounded,
            label: 'البروفيل',
          ),
        ],
      ),
      ),
    );
  }
}
