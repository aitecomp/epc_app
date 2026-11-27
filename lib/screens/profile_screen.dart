import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/cloud_sync.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/member_card.dart';

/// تبويب البروفيل: البطاقة + معلومات العضوية + الحساب
class ProfileScreen extends StatefulWidget {
  final Member member;
  final VoidCallback onLogout;
  final bool isLeader;
  final Widget? extraActions;
  final bool readOnly;

  const ProfileScreen({
    super.key,
    required this.member,
    required this.onLogout,
    this.isLeader = false,
    this.extraActions,
    this.readOnly = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  bool _busy = false;

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

  Future<void> _openPrivacyPolicy() async {
    if (CloudSync.enabled) {
      final uri = Uri.parse('${CloudSync.url.replaceAll(RegExp(r'/+$'), '')}/privacy');
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('سياسة الخصوصية', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'تُستخدم بيانات عضويتك حصرياً لإدارة أنشطة نادي رواد الاقتصاد والتواصل الداخلي ولا تُشارك مع أي جهات إعلانية. يمكنك حذف حسابك في أي وقت من شاشة البروفيل.',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
      ),
    );
  }

  Future<void> _confirmDeleteOwnAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف حسابي وبياناتي', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB91C1C))),
        content: const Text(
          'سيتم حذف عضويتك وجميع بياناتك الشخصية نهائياً من النادي وتسجيل خروجك فوراً. هل أنت متأكد؟',
          style: TextStyle(fontSize: 13, height: 1.55),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    await MemberStore.instance.deleteMember(widget.member.id);
    await CloudSync.push(MemberStore.instance);
    if (mounted) {
      toast(context, 'تم حذف حسابك وبياناتك بنجاح');
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final top = widget.readOnly ? 0.0 : MediaQuery.paddingOf(context).top;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _header(m, top),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset(context)),
          child: Column(
            children: [
              MemberCardFlip(member: m),
              const SizedBox(height: 8),
              Text(
                'اضغط على البطاقة لعرض الوجه الخلفي',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.muted.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 18),
              SectionCard(
                title: 'معلومات العضوية',
                child: Column(
                  children: [
                    _row(Icons.account_tree_outlined, 'الكلية', m.branch),
                    _row(Icons.school_outlined, 'التخصص', m.displaySpecialization),
                    _row(Icons.trending_up, 'المستوى الدراسي', m.level),
                    _row(Icons.calendar_month_outlined, 'السنة الجامعية', m.year),
                    _row(Icons.badge_outlined, 'رقم التسجيل', m.regNumber),
                    _row(Icons.workspace_premium_outlined, 'الصفة', m.role, last: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'الحساب',
                child: Column(
                  children: [
                    Row(
                      children: [
                        MemberAvatar(member: m, size: 58),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text('${m.displaySpecialization} • ${m.level}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 20),
                    _row(Icons.phone_outlined, 'الهاتف', m.phone.isEmpty ? '—' : m.phone),
                    _row(Icons.mail_outline, 'البريد', m.email.isEmpty ? '—' : m.email),
                    _row(Icons.event_available_outlined, 'تاريخ الانضمام', m.joinedLabel,
                        last: true),
                  ],
                ),
              ),
              if (widget.extraActions != null) ...[
                const SizedBox(height: 16),
                widget.extraActions!,
              ],
              if (!widget.readOnly) ...[
              const SizedBox(height: 16),
              GhostButton(
                label: _busy ? 'جارٍ...' : 'تغيير الصورة',
                icon: Icons.photo_camera_outlined,
                onPressed: _busy ? null : _changePhoto,
              ),
              const SizedBox(height: 10),
              GhostButton(
                label: 'سياسة الخصوصية',
                icon: Icons.privacy_tip_outlined,
                onPressed: _openPrivacyPolicy,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('تسجيل الخروج',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    side: BorderSide(color: const Color(0xFFB91C1C).withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              if (!widget.isLeader) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _busy ? null : _confirmDeleteOwnAccount,
                  icon: const Icon(Icons.delete_forever_outlined, size: 17, color: Color(0xFFB91C1C)),
                  label: const Text('حذف حسابي وبياناتي نهائياً',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
                ),
              ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(Member m, double top) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 26),
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
                child: ClipOval(
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('بطاقة العضو',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    Text('Economics Pioneers Club',
                        style: TextStyle(
                            color: Color(0xFFE7CD98), fontSize: 10, letterSpacing: 1.2)),
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
          Text(widget.readOnly ? m.fullName : 'مرحباً، ${m.fullName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${m.displaySpecialization} • ${m.level} • ${m.year}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
