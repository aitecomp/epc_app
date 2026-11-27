import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/cloud_sync.dart';
import '../core/club_api.dart';
import '../core/store.dart';
import '../core/theme.dart';

/// شاشة إدارة طلبات الانضمام (خاصة بالقائد فقط — إشعار فوري لصاحب الطلب بدون بريد إلكتروني)
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
  String _filter = 'pending';
  final Set<String> _busyIds = {};

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
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      toast(context, 'تعذّر تحميل طلبات الانضمام', error: true);
    }
  }

  Future<void> _decide(JoinRequestItem item, String decision) async {
    if (_busyIds.contains(item.id)) return;
    final approved = decision == 'approved';
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          approved ? 'قبول ${item.fullName}' : 'رفض طلب ${item.fullName}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approved
                  ? 'سيتم تفعيل حسابه كعضو فوراً وإرسال إشعار بالقبول إلى جهازه فقط.'
                  : 'سيتم رفض الطلب وإرسال إشعار بالقرار إلى جهازه فقط.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: approved ? 'رسالة ترحيب (اختياري)' : 'ملاحظة أو سبب الرفض (اختياري)',
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

    setState(() => _busyIds.add(item.id));
    try {
      await _api.decideJoinRequest(item.id, decision, note: noteCtrl.text.trim());
      if (approved) {
        await CloudSync.syncNow(widget.store);
      }
      if (!mounted) return;
      setState(() {
        item.status = decision;
        item.leaderNote = noteCtrl.text.trim();
        _busyIds.remove(item.id);
      });
      toast(
        context,
        approved
            ? 'تم قبول العضو وإرسال إشعار فوري له ✓'
            : 'تم رفض الطلب وإرسال إشعار لصاحب الطلب',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyIds.remove(item.id));
      toast(context, 'تعذّر تنفيذ القرار', error: true);
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
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              color: Colors.white,
              child: Row(
                children: [
                  _tabPill('pending', 'قيد المراجعة ($pendingCount)'),
                  const SizedBox(width: 7),
                  _tabPill('approved', 'المقبولون'),
                  const SizedBox(width: 7),
                  _tabPill('rejected', 'المرفوضون'),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
                  : filtered.isEmpty
                      ? const EmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'لا توجد طلبات في هذا القسم',
                          subtitle: 'ستظهر هنا طلبات الضيوف الراغبين في الانضمام للنادي.',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _requestCard(filtered[i]),
                          ),
                        ),
            ),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: active ? AppColors.headerGradient : null,
            color: active ? null : AppColors.softViolet,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
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
    final busy = _busyIds.contains(r.id);
    return FadeSlideIn(
      child: SectionCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.softViolet,
                  backgroundImage: r.photoBase64.isNotEmpty
                      ? MemoryImage(base64Decode(r.photoBase64))
                      : null,
                  child: r.photoBase64.isEmpty
                      ? Text(
                          r.firstName.isNotEmpty ? r.firstName[0] : '؟',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: AppColors.purple, fontSize: 16),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.fullName,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                      Text('رقم التسجيل: ${r.regNumber}',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.purple, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Text(relativeTimeAr(r.createdAt),
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
              ],
            ),
            const Divider(height: 18),
            _infoRow(Icons.phone_outlined, r.phone),
            if (r.email.isNotEmpty) ...[
              const SizedBox(height: 5),
              _infoRow(Icons.mail_outline_rounded, r.email),
            ],
            const SizedBox(height: 5),
            _infoRow(Icons.school_outlined, '${r.specialization} • ${r.level}'),
            if (r.motivation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(r.motivation, style: const TextStyle(fontSize: 12.5, height: 1.45)),
              ),
            ],
            if (r.status == 'pending') ...[
              const SizedBox(height: 12),
              if (busy)
                const LinearProgressIndicator(
                    color: AppColors.gold, backgroundColor: AppColors.softViolet)
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _decide(r, 'approved'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF15803D),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 17),
                        label: const Text('قبول وإشعار',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _decide(r, 'rejected'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB91C1C),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 17),
                        label: const Text('رفض وإشعار',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
            ] else if (r.leaderNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('ملاحظتك: ${r.leaderNote}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.ink)),
        ),
      ],
    );
  }
}
