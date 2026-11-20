import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/cloud_sync.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/glass_nav.dart';
import '../widgets/member_card.dart';

class ProfileScreen extends StatefulWidget {
  final Member member;
  final VoidCallback onLogout;
  final bool isLeader;

  const ProfileScreen({
    super.key,
    required this.member,
    required this.onLogout,
    this.isLeader = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  bool _busy = false;
  int _index = 0;

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('تحديث الصورة الشخصية',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.purple),
              title: const Text('الكاميرا'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppColors.purple),
              title: const Text('المعرض'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (source == null) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1000, imageQuality: 78);
      if (file != null) {
        final bytes = await file.readAsBytes();
        final updated = widget.member;
        updated.photoBase64 = base64Encode(bytes);
        await MemberStore.instance.saveMember(updated);
        CloudSync.pushInBackground(MemberStore.instance);
        if (mounted) {
          setState(() {});
          toast(context, 'تم تحديث الصورة بنجاح');
        }
      }
    } catch (_) {
      if (mounted) toast(context, 'تعذّر تحديث الصورة', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.cream,
      body: IndexedStack(
        index: _index,
        children: [_homeTab(), _accountTab()],
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

  // ── الرئيسية: البطاقة ──
  Widget _homeTab() {
    final m = widget.member;
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(m),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
            child: Column(
              children: [
                MemberCardFlip(member: m),
                const SizedBox(height: 20),
                SectionCard(
                  title: 'معلومات العضوية',
                  child: Column(
                    children: [
                      _row(Icons.account_tree_outlined, 'الشعبة', m.branch),
                      _row(Icons.school_outlined, 'التخصص', m.displaySpecialization),
                      _row(Icons.trending_up, 'المستوى الدراسي', m.level),
                      _row(Icons.calendar_month_outlined, 'السنة الجامعية', m.year),
                      _row(Icons.badge_outlined, 'رقم التسجيل', m.regNumber),
                      _row(Icons.workspace_premium_outlined, 'الصفة', m.role, last: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── البروفيل: الحساب ──
  Widget _accountTab() {
    final m = widget.member;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _header(m),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
          child: Column(
            children: [
              SectionCard(
                title: 'بياناتي',
                child: Column(
                  children: [
                    Row(
                      children: [
                        MemberAvatar(member: m, size: 62),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.fullName,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text('${m.displaySpecialization} • ${m.level}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 22),
                    _row(Icons.badge_outlined, 'رقم التسجيل', m.regNumber),
                    _row(Icons.phone_outlined, 'الهاتف', m.phone.isEmpty ? '—' : m.phone),
                    _row(Icons.mail_outline, 'البريد',
                        m.email.isEmpty ? '—' : m.email),
                    _row(Icons.event_available_outlined, 'تاريخ الانضمام', m.joinedLabel, last: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GhostButton(
                label: _busy ? 'جارٍ...' : 'تغيير الصورة',
                icon: Icons.photo_camera_outlined,
                onPressed: _busy ? null : _changePhoto,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout, size: 19),
                  label: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    side: BorderSide(color: const Color(0xFFB91C1C).withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(Member m) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 58, 20, 26),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('بطاقة العضو',
                        style: TextStyle(
                            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    Text('Economics Pioneers Club',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 10,
                            letterSpacing: 1.2)),
                  ],
                ),
              ),
              if (widget.isLeader)
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
          const SizedBox(height: 22),
          Text('مرحباً، ${m.fullName}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${m.displaySpecialization} • ${m.level} • ${m.year}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.purple),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const Spacer(),
          Flexible(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
