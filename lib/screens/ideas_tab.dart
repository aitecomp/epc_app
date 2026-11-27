import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/cloud_sync.dart';
import '../core/club_api.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/member_card.dart';

const List<String> kIdeaCategories = [
  'مبادرة اقتصادية',
  'مشروع تقني',
  'ورشة تدريبية',
  'نشاط ثقافي',
  'تطوير النادي',
];

/// قسم الأفكار والاستطلاعات (قبول الفكرة / رفض الفكرة + نسب مئوية + صورة واسم العضو — للأعضاء فقط)
class IdeasTab extends StatefulWidget {
  final MemberStore store;
  final bool isLeader;

  const IdeasTab({
    super.key,
    required this.store,
    required this.isLeader,
  });

  @override
  State<IdeasTab> createState() => _IdeasTabState();
}

class _IdeasTabState extends State<IdeasTab> {
  late final ClubApi _api = ClubApi(widget.store);
  List<IdeaItem> _ideas = [];
  bool _loading = true;
  String _sortMode = 'votes'; // votes | newest | approved
  final Set<String> _votingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!CloudSync.enabled) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted && _ideas.isEmpty) setState(() => _loading = true);
    try {
      final list = await _api.fetchIdeas();
      if (!mounted) return;
      setState(() {
        _ideas = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<IdeaItem> get _displayed {
    final list = _sortMode == 'approved'
        ? _ideas.where((i) => i.status == 'approved' || i.status == 'completed').toList()
        : List<IdeaItem>.from(_ideas);
    if (_sortMode == 'votes') {
      list.sort((a, b) => b.agreeCount.compareTo(a.agreeCount));
    } else {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<IdeaItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateIdeaSheet(api: _api),
    );
    if (created != null && mounted) {
      setState(() => _ideas = [created, ..._ideas]);
      toast(context, 'تم نشر الاستطلاع للتصويت بنجاح ✓');
    }
  }

  Future<void> _vote(IdeaItem idea, String choice) async {
    if (_votingIds.contains(idea.id)) return;
    setState(() => _votingIds.add(idea.id));
    try {
      final res = await _api.voteIdea(idea.id, choice);
      if (!mounted) return;
      setState(() {
        idea.myVote = res.myVote;
        idea.agreeCount = res.agreeCount;
        idea.disagreeCount = res.disagreeCount;
        idea.totalVotes = res.totalVotes;
        idea.agreePercent = res.agreePercent;
        idea.disagreePercent = res.disagreePercent;
        _votingIds.remove(idea.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _votingIds.remove(idea.id));
      toast(context, 'تعذّر تسجيل التصويت', error: true);
    }
  }

  Future<void> _changeStatus(IdeaItem idea) async {
    if (!widget.isLeader) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const Text('تحديث حالة الفكرة / المشروع',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final entry in const [
              ('proposed', 'مقترحة', Icons.lightbulb_outline),
              ('reviewing', 'قيد الدراسة', Icons.manage_search_rounded),
              ('approved', 'معتمدة للتنفيذ', Icons.rocket_launch_outlined),
              ('completed', 'مكتملة', Icons.verified_outlined),
            ])
              ListTile(
                dense: true,
                leading: Icon(entry.$3, color: AppColors.purple, size: 20),
                title: Text(entry.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                trailing: idea.status == entry.$1
                    ? const Icon(Icons.check_circle, color: AppColors.gold, size: 20)
                    : null,
                onTap: () => Navigator.pop(ctx, entry.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked == idea.status) return;
    try {
      await _api.updateIdeaStatus(idea.id, picked);
      if (!mounted) return;
      setState(() => idea.status = picked);
      toast(context, 'تم تحديث حالة المشروع');
    } catch (_) {}
  }

  Future<void> _deleteIdea(IdeaItem idea) async {
    try {
      await _api.deleteIdea(idea.id);
      if (!mounted) return;
      setState(() => _ideas.removeWhere((i) => i.id == idea.id));
      toast(context, 'تم حذف الفكرة');
    } catch (_) {}
  }

  Future<void> _openDiscussion(IdeaItem idea) async {
    final ctrl = TextEditingController();
    bool sending = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottom = MediaQuery.viewInsetsOf(ctx).bottom + MediaQuery.paddingOf(ctx).bottom;
          return Container(
            height: MediaQuery.sizeOf(ctx).height * 0.68,
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 10),
                Text('مناقشة: ${idea.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const Divider(height: 18),
                Expanded(
                  child: idea.comments.isEmpty
                      ? const Center(
                          child: Text('لا توجد نقاشات بعد. شارك رأيك في هذه الفكرة!',
                              style: TextStyle(color: AppColors.muted, fontSize: 13)),
                        )
                      : ListView.separated(
                          itemCount: idea.comments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final c = idea.comments[i];
                            final member = findMemberByReg(widget.store, c.authorId);
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.cream,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (member != null)
                                    MemberAvatar(member: member, size: 28)
                                  else
                                    const CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.softViolet,
                                      child: Icon(Icons.person_outline, size: 15, color: AppColors.purple),
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(c.authorName,
                                                style: const TextStyle(
                                                    fontSize: 12, fontWeight: FontWeight.w800)),
                                            const Spacer(),
                                            Text(relativeTimeAr(c.createdAt),
                                                style: const TextStyle(
                                                    fontSize: 10, color: AppColors.muted)),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(c.text, style: const TextStyle(fontSize: 12.5, height: 1.45)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(hintText: 'أضف ملاحظة أو مقترح تطوير...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: AppColors.purple,
                      child: IconButton(
                        icon: sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        onPressed: sending
                            ? null
                            : () async {
                                final txt = ctrl.text.trim();
                                if (txt.isEmpty) return;
                                setSheetState(() => sending = true);
                                try {
                                  final c = await _api.addIdeaComment(idea.id, txt);
                                  idea.comments = [...idea.comments, c];
                                  idea.commentsCount = idea.comments.length;
                                  ctrl.clear();
                                  if (mounted) setState(() {});
                                } catch (_) {}
                                setSheetState(() => sending = false);
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final list = _displayed;

    return RefreshIndicator(
      color: AppColors.purple,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _header(top),
          _sortBar(),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, bottomInset(context)),
            child: Column(
              children: [
                PrimaryButton(
                  label: 'طرح فكرة أو استطلاع جديد',
                  icon: Icons.lightbulb_outline_rounded,
                  gold: true,
                  onPressed: _openCreateSheet,
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 46),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.purple, strokeWidth: 2.4),
                        SizedBox(height: 10),
                        Text('جاري تحميل الأفكار والاستطلاعات...',
                            style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                      ],
                    ),
                  )
                else if (list.isEmpty)
                  const EmptyState(
                    icon: Icons.poll_outlined,
                    title: 'لا توجد أفكار أو استطلاعات بعد',
                    subtitle: 'اقترح فكرة أو مشروعاً ليصوّت الأعضاء بقبولها أو رفضها مع نسب فورية.',
                  )
                else
                  for (var i = 0; i < list.length; i++) ...[
                    FadeSlideIn(
                      delayMs: (i * 45).clamp(0, 220),
                      child: _ideaCard(list[i], rank: _sortMode == 'votes' ? i + 1 : null),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(double top) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 16),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.poll_rounded, color: AppColors.plum, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الأفكار والاستطلاعات',
                    style: TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                Text('صوّت بقبول أو رفض الأفكار والمشاريع • خاص بالأعضاء',
                    style: TextStyle(
                        color: AppColors.goldSoft.withValues(alpha: 0.9), fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Row(
        children: [
          _sortChip('votes', 'الأكثر قبولاً 🔥'),
          const SizedBox(width: 7),
          _sortChip('newest', 'الأحدث'),
          const SizedBox(width: 7),
          _sortChip('approved', 'معتمدة'),
        ],
      ),
    );
  }

  Widget _sortChip(String mode, String label) {
    final active = _sortMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _sortMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            gradient: active ? AppColors.headerGradient : null,
            color: active ? null : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? AppColors.purple : AppColors.line),
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

  Widget _ideaCard(IdeaItem idea, {int? rank}) {
    final statusInfo = _statusStyle(idea.status);
    final author = findMemberByReg(widget.store, idea.authorId);
    final voting = _votingIds.contains(idea.id);
    final agreeFlex = idea.totalVotes > 0 ? idea.agreePercent.clamp(0, 100) : 50;
    final disagreeFlex = idea.totalVotes > 0 ? idea.disagreePercent.clamp(0, 100) : 50;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: rank == 1 ? AppColors.gold.withValues(alpha: 0.55) : Colors.white,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.plum.withValues(alpha: 0.045),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── صورة واسم صاحب الفكرة + التصنيف والحالة ──
              Row(
                children: [
                  if (author != null)
                    MemberAvatar(member: author, size: 34)
                  else
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: AppColors.softViolet,
                      child: Icon(Icons.person_outline, size: 17, color: AppColors.purple),
                    ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(idea.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                        Text('${idea.authorRole} • ${relativeTimeAr(idea.createdAt)}',
                            style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.isLeader ? () => _changeStatus(idea) : null,
                    child: ChipTag(text: statusInfo.$1, color: statusInfo.$2, icon: statusInfo.$3),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChipTag(text: idea.category, color: AppColors.purple),
                  if (rank != null && rank <= 3 && idea.agreeCount > 0)
                    ChipTag(text: '#$rank الأعلى قبولاً', color: AppColors.gold),
                ],
              ),
              const SizedBox(height: 8),
              Text(idea.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(idea.description,
                  style: const TextStyle(
                      fontSize: 12.8, color: Color(0xFF475569), height: 1.5)),
              if (idea.expectedImpact.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.softViolet,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_graph_rounded, size: 15, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('الأثر المتوقع: ${idea.expectedImpact}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],

              // ── شريط نسب التصويت (قبول / رفض) ──
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('قبول ${idea.agreePercent}% (${idea.agreeCount})',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF15803D))),
                  const Spacer(),
                  Text('إجمالي الأصوات: ${idea.totalVotes}',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                  const Spacer(),
                  Text('رفض ${idea.disagreePercent}% (${idea.disagreeCount})',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB91C1C))),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 8,
                  child: idea.totalVotes == 0
                      ? Container(color: AppColors.line)
                      : Row(
                          children: [
                            if (agreeFlex > 0)
                              Expanded(
                                flex: agreeFlex,
                                child: Container(color: const Color(0xFF16A34A)),
                              ),
                            if (disagreeFlex > 0)
                              Expanded(
                                flex: disagreeFlex,
                                child: Container(color: const Color(0xFFDC2626)),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // ── أزرار التصويت بقبول الفكرة أو رفضها ──
              Row(
                children: [
                  Expanded(
                    child: _VoteChoiceButton(
                      label: 'قبول الفكرة',
                      icon: Icons.thumb_up_alt_rounded,
                      active: idea.myVote == 'agree',
                      loading: voting,
                      color: const Color(0xFF15803D),
                      onTap: () => _vote(idea, 'agree'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _VoteChoiceButton(
                      label: 'رفض الفكرة',
                      icon: Icons.thumb_down_alt_rounded,
                      active: idea.myVote == 'disagree',
                      loading: voting,
                      color: const Color(0xFFB91C1C),
                      onTap: () => _vote(idea, 'disagree'),
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _openDiscussion(idea),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.forum_outlined, size: 16),
                    label: Text('نقاش (${idea.commentsCount})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  if (widget.isLeader || idea.isMine)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFB91C1C)),
                      onPressed: () => _deleteIdea(idea),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color, IconData) _statusStyle(String status) {
    switch (status) {
      case 'reviewing':
        return ('قيد الدراسة', const Color(0xFF0E7490), Icons.manage_search_rounded);
      case 'approved':
        return ('معتمدة للتنفيذ', const Color(0xFF15803D), Icons.rocket_launch_outlined);
      case 'completed':
        return ('مكتملة', AppColors.gold, Icons.verified_outlined);
      default:
        return ('مقترحة', AppColors.muted, Icons.lightbulb_outline);
    }
  }
}

class _VoteChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool loading;
  final Color color;
  final VoidCallback onTap;

  const _VoteChoiceButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.loading,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? color : color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateIdeaSheet extends StatefulWidget {
  final ClubApi api;
  const _CreateIdeaSheet({required this.api});

  @override
  State<_CreateIdeaSheet> createState() => _CreateIdeaSheetState();
}

class _CreateIdeaSheetState extends State<_CreateIdeaSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _impactCtrl = TextEditingController();
  String _category = kIdeaCategories.first;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _impactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      toast(context, 'أدخل عنوان الفكرة وشرحها', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final idea = await widget.api.createIdea(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        expectedImpact: _impactCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, idea);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      toast(context, e.toString().replaceFirst('Bad state: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, bottom + 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('طرح فكرة أو استطلاع جديد',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
            const Text('سيصوّت الأعضاء بقبول الفكرة أو رفضها مع ظهور النسب.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in kIdeaCategories)
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(c, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    selected: _category == c,
                    selectedColor: AppColors.purple,
                    labelStyle: TextStyle(color: _category == c ? Colors.white : AppColors.ink),
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: 'عنوان الفكرة أو المشروع',
                prefixIcon: Icon(Icons.lightbulb_outline, color: AppColors.purple, size: 19),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'اشرح الفكرة وأهدافها وكيف يمكن تنفيذها...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _impactCtrl,
              decoration: const InputDecoration(
                hintText: 'الأثر المتوقع (اختياري)',
                prefixIcon: Icon(Icons.auto_graph_rounded, color: AppColors.gold, size: 19),
              ),
            ),
            if (_saving) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(color: AppColors.gold, backgroundColor: AppColors.softViolet),
            ],
            const SizedBox(height: 14),
            PrimaryButton(
              label: _saving ? 'جاري النشر...' : 'نشر للاستطلاع',
              icon: Icons.rocket_launch_outlined,
              loading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
