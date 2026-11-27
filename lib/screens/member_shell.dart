import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/activity_notifier.dart';
import '../core/chat_unread.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/glass_nav.dart';
import 'activities_tab.dart';
import 'chat_screen.dart';
import 'club_feed_tab.dart';
import 'ideas_tab.dart';
import 'profile_screen.dart';

/// واجهة العضو: الفعاليات (مع المنبهات) + نشاطات النادي + الأفكار والمشاريع بالتصويت + الدردشة + البروفيل
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
    ChatUnread.count.addListener(_chatChanged);
    ChatUnread.openRequested.addListener(_openChatFromNotification);
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
    widget.store.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ActivityNotifier.scheduleUpcoming(widget.store);
    });
  }

  @override
  void dispose() {
    ChatUnread.count.removeListener(_chatChanged);
    ChatUnread.openRequested.removeListener(_openChatFromNotification);
    _clockTimer?.cancel();
    widget.store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _chatChanged() {
    if (mounted) setState(() {});
  }

  void _openChatFromNotification() {
    if (mounted) setState(() => _index = 3);
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
              onOpenProfile: () => setState(() => _index = 4),
            ),
            ClubFeedTab(
              store: widget.store,
              isLeader: false,
            ),
            IdeasTab(
              store: widget.store,
              isLeader: false,
            ),
            ChatScreen(store: widget.store, isActive: _index == 3),
            ProfileScreen(member: member, onLogout: widget.onLogout),
          ],
        ),
        bottomNavigationBar: GlassNavBar(
          index: _index,
          onTap: (i) => setState(() => _index = i),
          items: [
            GlassNavItem(
              badge: unseen,
              icon: Icons.event_note_outlined,
              activeIcon: Icons.event_note_rounded,
              label: 'الفعاليات',
            ),
            const GlassNavItem(
              icon: Icons.photo_library_outlined,
              activeIcon: Icons.photo_library_rounded,
              label: 'النادي',
            ),
            const GlassNavItem(
              icon: Icons.tips_and_updates_outlined,
              activeIcon: Icons.tips_and_updates_rounded,
              label: 'الأفكار',
            ),
            GlassNavItem(
              badge: ChatUnread.count.value,
              messenger: true,
              icon: Icons.forum_outlined,
              activeIcon: Icons.forum_rounded,
              label: 'الدردشة',
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
