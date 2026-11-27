import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/glass_nav.dart';
import 'club_feed_tab.dart';
import 'join_request_tab.dart';

/// واجهة الضيف / العامة:
/// يمكن للضيف فقط مشاهدة نشاطات النادي المنشورة وتقديم طلب الانضمام للنادي
class GuestShell extends StatefulWidget {
  final MemberStore store;
  final VoidCallback onExitGuest;

  const GuestShell({
    super.key,
    required this.store,
    required this.onExitGuest,
  });

  @override
  State<GuestShell> createState() => _GuestShellState();
}

class _GuestShellState extends State<GuestShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kSystemUiOnLight,
      child: Scaffold(
        extendBody: true,
        backgroundColor: AppColors.cream,
        body: IndexedStack(
          index: _index,
          children: [
            ClubFeedTab(
              store: widget.store,
              isLeader: false,
              isGuest: true,
              onSwitchToLogin: widget.onExitGuest,
              onSwitchToJoin: () => setState(() => _index = 1),
            ),
            JoinRequestTab(
              store: widget.store,
              onSwitchToLogin: widget.onExitGuest,
            ),
          ],
        ),
        bottomNavigationBar: GlassNavBar(
          index: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            GlassNavItem(
              icon: Icons.photo_library_outlined,
              activeIcon: Icons.photo_library_rounded,
              label: 'نشاطات النادي',
            ),
            GlassNavItem(
              icon: Icons.how_to_reg_outlined,
              activeIcon: Icons.how_to_reg_rounded,
              label: 'طلب الانضمام',
            ),
          ],
        ),
      ),
    );
  }
}
