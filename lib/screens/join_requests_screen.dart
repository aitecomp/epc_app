import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/cloud_sync.dart';
import '../core/club_api.dart';
import '../core/store.dart';
import '../core/theme.dart';

/// شاشة إدارة طلبات الانضمام (خاصة بالقائد فقط)
class JoinRequestsScreen extends StatefulWidget {
  final MemberStore store;
  const JoinRequestsScreen({super.key, required this.store});

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  late final ClubApi _api = ClubApi(widget.store);
  List<JoinRequestItem> _requests = [];
  bool _loading = true;
  String _filter = 'pending'; // pending | approved | rejected

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchJoinRequests();
      if (!mounted) return;
      setState(() {
        _requests = res.requests;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      toast(context, 'تعذّر تحميل طلبات الانضمام', error: true);
    }
  }

  Future<void> _decide(JoinRequestItem item, String decision) async {
    final approved = decision == 'approved';
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          approved ? 'قبول طلب ${item.fullName}' : 'رفض طلب ${item.fullName}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approved
                  ? 'سيتم تفعيل حسابه كعضو تلقائياً وإرسال رسالة القبول إلى بريده (${item.email}).'
                  : 'سيتم رفض الطلب وإرسال رسالة اعتذار إلى بريده (${item.email}).',
              style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: approved ? 'رسالة ترحيب (اختياري)' : 'سبب الرفض أو ملاحظة (اختياري)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: approved ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approved ? 'تأكيد القبول' : 'تأكيد الرفض'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await _api.decideJoinRequest(item.id, decision, note: noteCtrl.text.trim());
      if (approved) {
        await CloudSync.syncNow(widget.store);
      }
      if (!mounted) return;
      setState(() {
        item.status = decision;
        item.leaderNote = noteCtrl.text.trim();
      });

      final emailSent = result['emailSent'] == true;
      final subject = (result['emailSubject'] ?? '').toString();
      final bodyText = (result['emailText'] ?? '').toString();

      if (emailSent) {
        toast(
          context,
          approved
              ? 'تم قبول العضو وإرسال رسالة القبول إلى بريده الإلكتروني'
              : 'تم رفض الطلب وإرسال الإشعار إلى بريده الإلكتروني',
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Text(
              approved ? 'تم قبول العضو بنجاح' : 'تم تسجيل رفض الطلب',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Text(
              'تم حفظ القرار${approved ? ' وإضافة العضو لقاعدة النادي' : ''}، لكن خدمة البريد التلقائي غير مضبوطة بعد على الخادم. يمكنك إرسال الرسالة الجاهزة مباشرة عبر تطبيق البريد.',
              style: const TextStyle(fontSize: 13.5, height: 1.5),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri(
                    scheme: 'mailto',
                    path: item.email,
                    queryParameters: {'subject': subject, 'body': bodyText},
                  );
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                label: const Text('إرسال البريد الآن'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) toast(context, 'تعذّر تنفيذ القرار', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _requests.where((r) => r.status == 'pending').length;
    final filtered = _requests.where((r) => r.status == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.plum,
        foregroundColor: Colors.white,
        title: const Text('طلبات الانضمام للنادي',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            color: Colors.white,
            child: Row(
              children: [
                _tabPill('pending', 'قيد المراجعة ($pendingCount)'),
                const SizedBox(width: 8),
                _tabPill('approved', 'المقبولون'),
                const SizedBox(width: 8),
                _tabPill('rejected', 'المرفوضون'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
                : filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'لا توجد طلبات في هذا القسم',
                        subtitle: 'ستظهر هنا طلبات الضيوف الراغبين في الانضمام للنادي.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (_, i) => _requestCard(filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tabPill(String key, String label) {
    final active = _filter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: active ? AppColors.headerGradient : null,
            color: active ? null : AppColors.softViolet,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _requestCard(JoinRequestItem r) {
    return FadeSlideIn(
      child: SectionCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.softViolet,
                  backgroundImage: r.photoBase64.isNotEmpty
                      ? MemoryImage(base64Decode(r.photoBase64))
                      : null,
                  child: r.photoBase64.isEmpty
                      ? Text(
                          r.firstName.isNotEmpty ? r.firstName[0] : '؟',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: AppColors.purple, fontSize: 18),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.fullName,
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('رقم التسجيل: ${r.regNumber}',
                          style: const TextStyle(fontSize: 12, color: AppColors.purple, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Text(relativeTimeAr(r.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
            const Divider(height: 22),
            _infoRow(Icons.mail_outline_rounded, r.email),
            const SizedBox(height: 6),
            _infoRow(Icons.phone_outlined, r.phone),
            const SizedBox(height: 6),
            _infoRow(Icons.school_outlined, '${r.specialization} • ${r.level}'),
            if (r.motivation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الدافع والمهارات:',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Text(r.motivation, style: const TextStyle(fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
            ],
            if (r.status == 'pending') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _decide(r, 'approved'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('قبول وإرسال بريد',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _decide(r, 'rejected'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB91C1C),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('رفض وإرسال بريد',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
            ] else if (r.leaderNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('ملاحظتك: ${r.leaderNote}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.ink)),
        ),
      ],
    );
  }
}
