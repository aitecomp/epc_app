import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/activity_notifier.dart';
import '../core/chat_unread.dart';
import '../core/cloud_sync.dart';
import '../core/club_api.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/glass_nav.dart';
import 'activities_tab.dart';
import 'chat_screen.dart';
import 'club_feed_tab.dart';
import 'ideas_tab.dart';
import 'join_requests_screen.dart';
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
  int _pendingJoinCount = 0;
  Timer? _clockTimer;

  MemberStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    ChatUnread.count.addListener(_chatChanged);
    ChatUnread.openRequested.addListener(_openChatFromNotification);
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ActivityNotifier.scheduleUpcoming(store);
      _refreshPendingRequests();
    });
  }

  @override
  void dispose() {
    ChatUnread.count.removeListener(_chatChanged);
    ChatUnread.openRequested.removeListener(_openChatFromNotification);
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPendingRequests() async {
    if (!CloudSync.enabled) return;
    try {
      final res = await ClubApi(store).fetchJoinRequests();
      if (mounted) setState(() => _pendingJoinCount = res.pendingCount);
    } catch (_) {}
  }

  Future<void> _openForm({Member? member, bool leaderMode = false}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MemberFormScreen(member: member, leaderMode: leaderMode),
      ),
    );
    if (saved == true && mounted) {
      setState(() {});
      CloudSync.pushInBackground(store);
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

  void _openDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.cream,
          body: OverviewTab(
            store: store,
            onAddMember: () => _openForm(),
            onOpenMember: _openMember,
            onSeeAll: _openMembers,
            onOpenMembers: _openMembers,
            onOpenSettings: _openSettings,
          ),
        ),
      ),
    );
  }

  Future<void> _openJoinRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JoinRequestsScreen(store: store)),
    );
    await _refreshPendingRequests();
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

  void _chatChanged() {
    if (mounted) setState(() {});
  }

  void _openChatFromNotification() {
    if (mounted) setState(() => _index = 3);
  }

  @override
  Widget build(BuildContext context) {
    final leader = store.leaderMember;
    final tabs = [
      ActivitiesTab(
        store: store,
        isLeader: true,
        memberName: leader.fullName,
        onOpenProfile: () => setState(() => _index = 4),
      ),
      ClubFeedTab(
        store: store,
        isLeader: true,
      ),
      IdeasTab(
        store: store,
        isLeader: true,
      ),
      ChatScreen(store: store, isActive: _index == 3),
      LeaderProfileTab(
        store: store,
        pendingJoinCount: _pendingJoinCount,
        onOpenJoinRequests: _openJoinRequests,
        onEditProfile: () => _openForm(member: store.leaderMember, leaderMode: true),
        onOpenSettings: _openSettings,
        onLogout: widget.onLogout,
        onOpenDashboard: _openDashboard,
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kSystemUiOnLight,
      child: Scaffold(
        extendBody: true,
        backgroundColor: AppColors.cream,
        body: IndexedStack(
          index: _index,
          children: tabs,
        ),
        bottomNavigationBar: GlassNavBar(
          index: _index,
          onTap: (i) {
            setState(() => _index = i);
            if (i == 4) _refreshPendingRequests();
          },
          items: [
            const GlassNavItem(
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
            GlassNavItem(
              badge: _pendingJoinCount,
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
