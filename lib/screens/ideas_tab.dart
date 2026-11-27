import 'package:flutter/material.dart';

import '../core/cloud_sync.dart';
import '../core/club_api.dart';
import '../core/store.dart';
import '../core/theme.dart';

const List<String> kIdeaCategories = [
  'مبادرة اقتصادية',
  'مشروع تقني',
  'ورشة تدريبية',
  'نشاط ثقافي',
  'تطوير النادي',
];

/// قسم الأفكار والمشاريع بالتصويت (خاص بأعضاء النادي والقائد فقط — لا يظهر للضيوف)
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
      list.sort((a, b) => b.votesCount.compareTo(a.votesCount));
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
      toast(context, 'تم نشر فكرتك بنجاح للتصويت!');
    }
  }

  Future<void> _vote(IdeaItem idea) async {
    final prevVoted = idea.votedByMe;
    final prevCount = idea.votesCount;
    setState(() {
      idea.votedByMe = !prevVoted;
      idea.votesCount = (prevCount + (idea.votedByMe ? 1 : -1)).clamp(0, 999999);
    });
    try {
      final res = await _api.toggleIdeaVote(idea.id);
      if (!mounted) return;
      setState(() {
        idea.votedByMe = res.voted;
        idea.votesCount = res.votesCount;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        idea.votedByMe = prevVoted;
        idea.votesCount = prevCount;
      });
    }
  }

  Future<void> _changeStatus(IdeaItem idea) async {
    if (!widget.isLeader) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('تحديث حالة المشروع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final entry in const [
              ('proposed', 'مقترحة', Icons.lightbulb_outline),
              ('reviewing', 'قيد الدراسة', Icons.manage_search_rounded),
              ('approved', 'معتمدة للتنفيذ', Icons.rocket_launch_outlined),
              ('completed', 'مكتملة', Icons.verified_outlined),
            ])
              ListTile(
                leading: Icon(entry.$3, color: AppColors.purple),
                title: Text(entry.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: idea.status == entry.$1
                    ? const Icon(Icons.check_circle, color: AppColors.gold)
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
          return Container(
            height: MediaQuery.sizeOf(ctx).height * 0.68,
            padding: EdgeInsets.fromLTRB(18, 12, 18, bottom + 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.line, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 12),
                Text('مناقشة: ${idea.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Divider(height: 20),
                Expanded(
                  child: idea.comments.isEmpty
                      ? const Center(
                          child: Text('لا توجد نقاشات بعد. شارك رأيك في هذه الفكرة!',
                              style: TextStyle(color: AppColors.muted)),
                        )
                      : ListView.separated(
                          itemCount: idea.comments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final c = idea.comments[i];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.cream,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(c.authorName,
                                          style: const TextStyle(
                                              fontSize: 12.5, fontWeight: FontWeight.w800)),
                                      const Spacer(),
                                      Text(relativeTimeAr(c.createdAt),
                                          style: const TextStyle(
                                              fontSize: 10.5, color: AppColors.muted)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(c.text, style: const TextStyle(fontSize: 13, height: 1.5)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 10),
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
                      radius: 24,
                      backgroundColor: AppColors.purple,
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: () async {
                          final txt = ctrl.text.trim();
                          if (txt.isEmpty) return;
                          try {
                            final c = await _api.addIdeaComment(idea.id, txt);
                            idea.comments = [...idea.comments, c];
                            idea.commentsCount = idea.comments.length;
                            ctrl.clear();
                            setSheetState(() {});
                            if (mounted) setState(() {});
                          } catch (_) {}
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
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset(context)),
            child: Column(
              children: [
                PrimaryButton(
                  label: 'اقترح فكرة أو مشروعاً جديداً',
                  icon: Icons.lightbulb_outline_rounded,
                  gold: true,
                  onPressed: _openCreateSheet,
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 50),
                    child: Center(child: CircularProgressIndicator(color: AppColors.purple)),
                  )
                else if (list.isEmpty)
                  const EmptyState(
                    icon: Icons.tips_and_updates_outlined,
                    title: 'مساحة الإبداع بانتظار أفكارك',
                    subtitle: 'اقترح مشروعاً أو مبادرة للنادي ليصوّت عليها الأعضاء وتدخل حيّز التنفيذ.',
                  )
                else
                  for (var i = 0; i < list.length; i++) ...[
                    FadeSlideIn(
                      delayMs: (i * 55).clamp(0, 260),
                      child: _ideaCard(list[i], rank: _sortMode == 'votes' ? i + 1 : null),
                    ),
                    const SizedBox(height: 14),
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
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 22),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.tips_and_updates_rounded, color: AppColors.plum, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الأفكار والمشاريع',
                    style: TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                Text('مختبر أفكار أعضاء النادي • صوّت لأفضل المشاريع',
                    style: TextStyle(
                        color: AppColors.goldSoft.withValues(alpha: 0.9), fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Row(
        children: [
          _sortChip('votes', 'الأعلى تصويتاً 🔥'),
          const SizedBox(width: 8),
          _sortChip('newest', 'الأحدث'),
          const SizedBox(width: 8),
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
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            gradient: active ? AppColors.headerGradient : null,
            color: active ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? AppColors.purple : AppColors.line),
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

  Widget _ideaCard(IdeaItem idea, {int? rank}) {
    final statusInfo = _statusStyle(idea.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: rank == 1 ? AppColors.gold.withValues(alpha: 0.6) : AppColors.line,
          width: rank == 1 ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChipTag(text: idea.category, color: AppColors.purple),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: widget.isLeader ? () => _changeStatus(idea) : null,
                child: ChipTag(text: statusInfo.$1, color: statusInfo.$2, icon: statusInfo.$3),
              ),
              const Spacer(),
              if (rank != null && rank <= 3 && idea.votesCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('#$rank',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.plum)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(idea.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(idea.description,
                        style: const TextStyle(
                            fontSize: 13.2, color: Color(0xFF475569), height: 1.55)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ── زر التصويت التفاعلي ──
              GestureDetector(
                onTap: () => _vote(idea),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 58,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: idea.votedByMe ? AppColors.goldGradient : null,
                    color: idea.votedByMe ? null : AppColors.softViolet,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: idea.votedByMe ? AppColors.gold : AppColors.line,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        idea.votedByMe
                            ? Icons.keyboard_double_arrow_up_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: idea.votedByMe ? AppColors.plum : AppColors.purple,
                        size: 24,
                      ),
                      Text(
                        '${idea.votesCount}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: idea.votedByMe ? AppColors.plum : AppColors.purple,
                        ),
                      ),
                      Text(
                        'صوت',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: idea.votedByMe ? AppColors.plum : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (idea.expectedImpact.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.softViolet,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_graph_rounded, size: 16, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('الأثر المتوقع: ${idea.expectedImpact}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 22),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 15, color: AppColors.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${idea.authorName} • ${relativeTimeAr(idea.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openDiscussion(idea),
                icon: const Icon(Icons.forum_outlined, size: 16),
                label: Text('نقاش (${idea.commentsCount})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              if (widget.isLeader || idea.isMine)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFB91C1C)),
                  onPressed: () => _deleteIdea(idea),
                ),
            ],
          ),
        ],
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottom + 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('طرح فكرة أو مشروع جديد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Text('سيتمكن أعضاء النادي من التصويت ومناقشة فكرتك.',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in kIdeaCategories)
                  ChoiceChip(
                    label: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    selected: _category == c,
                    selectedColor: AppColors.purple,
                    labelStyle: TextStyle(color: _category == c ? Colors.white : AppColors.ink),
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: 'عنوان الفكرة أو المشروع',
                prefixIcon: Icon(Icons.lightbulb_outline, color: AppColors.purple),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'اشرح الفكرة، أهدافها، وكيف يمكن تنفيذها داخل النادي...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _impactCtrl,
              decoration: const InputDecoration(
                hintText: 'الأثر المتوقع (اختياري — مثال: تدريب 50 طالباً)',
                prefixIcon: Icon(Icons.auto_graph_rounded, color: AppColors.gold),
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'نشر الفكرة للتصويت',
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
