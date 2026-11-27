import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../core/cloud_sync.dart';
import '../core/club_api.dart';
import '../core/store.dart';
import '../core/theme.dart';

const List<String> kFeedCategories = [
  'الكل',
  'فعالية',
  'ورشة عمل',
  'إنجاز',
  'تغطية',
  'إعلان',
];

/// فرع نشاطات النادي المصوّرة (صور وفيديوهات)
/// القائد فقط يمكنه النشر والحذف، بينما يمكن للأعضاء والضيوف المشاهدة والتفاعل (إعجاب، تعليق، مشاركة)
class ClubFeedTab extends StatefulWidget {
  final MemberStore store;
  final bool isLeader;
  final bool isGuest;
  final VoidCallback? onSwitchToLogin;
  final VoidCallback? onSwitchToJoin;

  const ClubFeedTab({
    super.key,
    required this.store,
    required this.isLeader,
    this.isGuest = false,
    this.onSwitchToLogin,
    this.onSwitchToJoin,
  });

  @override
  State<ClubFeedTab> createState() => _ClubFeedTabState();
}

class _ClubFeedTabState extends State<ClubFeedTab> {
  late final ClubApi _api = ClubApi(widget.store);
  List<ClubPost> _posts = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'الكل';

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
    if (mounted && _posts.isEmpty) setState(() => _loading = true);
    try {
      final list = await _api.fetchPosts();
      if (!mounted) return;
      setState(() {
        _posts = list;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<ClubPost> get _filteredPosts {
    if (_selectedCategory == 'الكل') return _posts;
    return _posts.where((p) => p.category == _selectedCategory).toList();
  }

  Future<void> _openComposer() async {
    if (!widget.isLeader) return;
    final created = await showModalBottomSheet<ClubPost>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(api: _api),
    );
    if (created != null && mounted) {
      setState(() => _posts = [created, ..._posts]);
      toast(context, 'تم نشر نشاط النادي بنجاح');
    }
  }

  Future<void> _toggleLike(ClubPost post) async {
    // تحديث متفائل فوري لتجربة سلسة
    final prevLiked = post.likedByMe;
    final prevCount = post.likesCount;
    setState(() {
      post.likedByMe = !prevLiked;
      post.likesCount = (prevCount + (post.likedByMe ? 1 : -1)).clamp(0, 999999);
    });
    try {
      final res = await _api.toggleLike(post.id);
      if (!mounted) return;
      setState(() {
        post.likedByMe = res.liked;
        post.likesCount = res.likesCount;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        post.likedByMe = prevLiked;
        post.likesCount = prevCount;
      });
    }
  }

  Future<void> _openComments(ClubPost post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostCommentsSheet(
        api: _api,
        post: post,
        isLeader: widget.isLeader,
        isGuest: widget.isGuest,
        onChanged: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _sharePost(ClubPost post) async {
    final shareText = StringBuffer()
      ..writeln('🌟 نادي رواد الاقتصاد — EPC')
      ..writeln(post.title.isNotEmpty ? '📌 ${post.title}' : '')
      ..writeln(post.caption)
      ..writeln(post.location.isNotEmpty ? '📍 ${post.location}' : '')
      ..writeln(post.mediaUrl.isNotEmpty ? '🔗 ${post.mediaUrl}' : '');

    final formatted = shareText.toString().trim();

    unawaited(_api.recordShare(post.id).then((count) {
      if (mounted) setState(() => post.sharesCount = count);
    }).catchError((_) {}));

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('مشاركة المنشور',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ShareActionTile(
                      icon: Icons.copy_rounded,
                      label: 'نسخ النص',
                      color: AppColors.purple,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: formatted));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) toast(context, 'تم نسخ تفاصيل المنشور');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ShareActionTile(
                      icon: Icons.send_rounded,
                      label: 'واتساب',
                      color: const Color(0xFF15803D),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final uri = Uri.parse(
                            'https://wa.me/?text=${Uri.encodeComponent(formatted)}');
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePost(ClubPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف المنشور', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('هل تريد حذف هذا المنشور نهائياً من نشاطات النادي؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deletePost(post.id);
      if (!mounted) return;
      setState(() => _posts.removeWhere((p) => p.id == post.id));
      toast(context, 'تم حذف المنشور');
    } catch (e) {
      if (mounted) toast(context, 'تعذّر حذف المنشور', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final items = _filteredPosts;

    return RefreshIndicator(
      color: AppColors.purple,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _header(context, top),
          if (widget.isGuest) _guestJoinBanner(),
          _categoryBar(),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset(context)),
            child: Column(
              children: [
                if (widget.isLeader) ...[
                  _leaderPublishButton(),
                  const SizedBox(height: 16),
                ],
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 56),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.purple),
                    ),
                  )
                else if (_error != null && _posts.isEmpty)
                  EmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'تعذّر تحميل نشاطات النادي',
                    subtitle: 'اسحب للأسفل لإعادة المحاولة وتحديث المنشورات.',
                    action: SizedBox(
                      width: 180,
                      child: PrimaryButton(label: 'إعادة المحاولة', onPressed: _load),
                    ),
                  )
                else if (items.isEmpty)
                  EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: 'لا توجد منشورات بعد',
                    subtitle: widget.isLeader
                        ? 'ابدأ بنشر أول تغطية مصورة أو فيديو لنشاطات النادي لتظهر للأعضاء والضيوف.'
                        : 'سيظهر هنا أرشيف صور وفيديوهات نشاطات نادي رواد الاقتصاد فور نشرها من القائد.',
                  )
                else
                  for (var i = 0; i < items.length; i++) ...[
                    FadeSlideIn(
                      delayMs: (i * 55).clamp(0, 280),
                      child: _ClubPostCard(
                        post: items[i],
                        isLeader: widget.isLeader,
                        onLike: () => _toggleLike(items[i]),
                        onComment: () => _openComments(items[i]),
                        onShare: () => _sharePost(items[i]),
                        onDelete: () => _deletePost(items[i]),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, double top) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 22),
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
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.75)),
                ),
                child: ClipOval(
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'نشاطات النادي',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      widget.isGuest
                          ? 'مرحباً بك كضيف • استكشف إنجازاتنا'
                          : 'معرض صور وفيديوهات نادي رواد الاقتصاد',
                      style: TextStyle(
                        color: AppColors.goldSoft.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isGuest && widget.onSwitchToLogin != null)
                TextButton.icon(
                  onPressed: widget.onSwitchToLogin,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: AppColors.gold.withValues(alpha: 0.55)),
                    ),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 15, color: AppColors.goldSoft),
                  label: const Text('دخول الأعضاء',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guestJoinBanner() {
    return FadeSlideIn(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF132A43), Color(0xFF203C55)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.plum.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.plum, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'هل تريد الانضمام لنادي رواد الاقتصاد؟',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'قدّم طلبك الآن للوصول إلى الدردشة والأفكار والفعاليات الخاصة بالأعضاء.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (widget.onSwitchToJoin != null)
              FilledButton(
                onPressed: widget.onSwitchToJoin,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.plum,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('انضم الآن',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _categoryBar() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        scrollDirection: Axis.horizontal,
        itemCount: kFeedCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = kFeedCategories[i];
          final active = cat == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: active ? AppColors.headerGradient : null,
                color: active ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? AppColors.purple : AppColors.line),
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _leaderPublishButton() {
    return PrimaryButton(
      label: 'نشر منشور نشاط جديد (صور / فيديو)',
      icon: Icons.add_photo_alternate_outlined,
      gold: true,
      onPressed: _openComposer,
    );
  }
}

class _ClubPostCard extends StatefulWidget {
  final ClubPost post;
  final bool isLeader;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _ClubPostCard({
    required this.post,
    required this.isLeader,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onDelete,
  });

  @override
  State<_ClubPostCard> createState() => _ClubPostCardState();
}

class _ClubPostCardState extends State<_ClubPostCard> {
  bool _showBurst = false;

  void _handleDoubleTap() {
    if (!widget.post.likedByMe) {
      widget.onLike();
    }
    setState(() => _showBurst = true);
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showBurst = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── رأس المنشور ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.softViolet,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'القائد',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.plum,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            relativeTimeAr(post.createdAt),
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                          if (post.location.isNotEmpty) ...[
                            const Text(' • ', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                            const Icon(Icons.place_outlined, size: 12, color: AppColors.muted),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                post.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AppColors.muted),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                ChipTag(text: post.category, color: AppColors.purple),
                if (widget.isLeader)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 20, color: Color(0xFFB91C1C)),
                    onPressed: widget.onDelete,
                    tooltip: 'حذف المنشور',
                  ),
              ],
            ),
          ),

          // ── العنوان والوصف ──
          if (post.title.isNotEmpty || post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.title.isNotEmpty)
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  if (post.title.isNotEmpty && post.caption.isNotEmpty)
                    const SizedBox(height: 5),
                  if (post.caption.isNotEmpty)
                    Text(
                      post.caption,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: Color(0xFF334155),
                      ),
                    ),
                ],
              ),
            ),

          // ── الوسائط (صورة أو فيديو) مع نقر مزدوج للقلب ──
          if (post.hasMedia)
            GestureDetector(
              onDoubleTap: _handleDoubleTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: post.isVideo
                            ? _FeedVideoPlayer(url: post.mediaUrl)
                            : Image.network(
                                post.mediaUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    height: 220,
                                    color: AppColors.softViolet,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: AppColors.purple,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  height: 180,
                                  color: AppColors.softViolet,
                                  child: const Center(
                                    child: Icon(Icons.broken_image_outlined,
                                        size: 38, color: AppColors.muted),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  AnimatedScale(
                    scale: _showBurst ? 1.15 : 0.0,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.elasticOut,
                    child: AnimatedOpacity(
                      opacity: _showBurst ? 0.95 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 86,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 20)],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── شريط التفاعل (قلب + تعليق + مشاركة) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Row(
              children: [
                BouncyIconButton(
                  active: post.likedByMe,
                  activeIcon: Icons.favorite_rounded,
                  inactiveIcon: Icons.favorite_border_rounded,
                  activeColor: const Color(0xFFE11D48),
                  label: '${post.likesCount}',
                  onTap: widget.onLike,
                ),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: widget.onComment,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded,
                            size: 20, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Text(
                          '${post.commentsCount}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: widget.onShare,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.share_outlined, size: 19, color: AppColors.purple),
                        const SizedBox(width: 6),
                        Text(
                          post.sharesCount > 0 ? 'مشاركة (${post.sharesCount})' : 'مشاركة',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedVideoPlayer extends StatefulWidget {
  final String url;
  const _FeedVideoPlayer({required this.url});

  @override
  State<_FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<_FeedVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.setLooping(true);
      setState(() => _ready = true);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Container(
        height: 220,
        color: AppColors.plum,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.goldSoft, strokeWidth: 2.4),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            _controller.play();
          }
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio > 0
                ? _controller.value.aspectRatio
                : 16 / 9,
            child: VideoPlayer(_controller),
          ),
          if (!_controller.value.isPlaying)
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.plum.withValues(alpha: 0.72),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldSoft, width: 1.6),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
            ),
          Positioned(
            bottom: 10,
            left: 10,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _muted = !_muted;
                  _controller.setVolume(_muted ? 0 : 1);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  final ClubApi api;
  const _CreatePostSheet({required this.api});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _titleCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _picker = ImagePicker();
  String _category = 'فعالية';
  Uint8List? _mediaBytes;
  String _mediaMime = '';
  String _mediaName = '';
  bool _publishing = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 84);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _mediaBytes = bytes;
      _mediaMime = file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      _mediaName = file.name;
    });
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 25 * 1024 * 1024) {
      if (mounted) toast(context, 'حجم الفيديو يتجاوز 25 ميغابايت', error: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _mediaBytes = bytes;
      _mediaMime = 'video/mp4';
      _mediaName = file.name;
    });
  }

  Future<void> _publish() async {
    if (_titleCtrl.text.trim().isEmpty && _captionCtrl.text.trim().isEmpty && _mediaBytes == null) {
      toast(context, 'أضف عنواناً أو وصفاً أو صورة/فيديو للنشر', error: true);
      return;
    }
    setState(() => _publishing = true);
    try {
      String mediaId = '';
      if (_mediaBytes != null) {
        mediaId = await widget.api.uploadFeedMedia(_mediaBytes!, _mediaMime);
      }
      final post = await widget.api.createPost(
        title: _titleCtrl.text.trim(),
        caption: _captionCtrl.text.trim(),
        category: _category,
        location: _locationCtrl.text.trim(),
        mediaId: mediaId,
      );
      if (!mounted) return;
      Navigator.pop(context, post);
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
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
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('نشر نشاط للنادي',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Text('سيظهر هذا المنشور للأعضاء وللضيوف في معرض نشاطات النادي.',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in kFeedCategories.where((c) => c != 'الكل'))
                  ChoiceChip(
                    label: Text(cat, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    selected: _category == cat,
                    selectedColor: AppColors.purple,
                    labelStyle: TextStyle(color: _category == cat ? Colors.white : AppColors.ink),
                    onSelected: (_) => setState(() => _category = cat),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: 'عنوان النشاط (مثال: تغطية اليوم الدراسي حول الريادة)',
                prefixIcon: Icon(Icons.title_rounded, color: AppColors.purple),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'اكتب تفاصيل النشاط أو قصة التغطية...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                hintText: 'المكان (اختياري — مثال: قاعة المحاضرات الكبرى)',
                prefixIcon: Icon(Icons.place_outlined, color: AppColors.purple),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'إرفاق صورة',
                    icon: Icons.image_outlined,
                    onPressed: _publishing ? null : _pickImage,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GhostButton(
                    label: 'إرفاق فيديو',
                    icon: Icons.videocam_outlined,
                    onPressed: _publishing ? null : _pickVideo,
                  ),
                ),
              ],
            ),
            if (_mediaBytes != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.softViolet,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Icon(
                      _mediaMime.startsWith('video/')
                          ? Icons.video_file_rounded
                          : Icons.photo_rounded,
                      color: AppColors.purple,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$_mediaName (${(_mediaBytes!.length / (1024 * 1024)).toStringAsFixed(1)} MB)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _mediaBytes = null;
                        _mediaMime = '';
                        _mediaName = '';
                      }),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'نشر الآن',
              icon: Icons.publish_rounded,
              loading: _publishing,
              onPressed: _publish,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCommentsSheet extends StatefulWidget {
  final ClubApi api;
  final ClubPost post;
  final bool isLeader;
  final bool isGuest;
  final VoidCallback onChanged;

  const _PostCommentsSheet({
    required this.api,
    required this.post,
    required this.isLeader,
    required this.isGuest,
    required this.onChanged,
  });

  @override
  State<_PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<_PostCommentsSheet> {
  final _textCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _guestNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment = await widget.api.addPostComment(
        widget.post.id,
        text,
        guestName: widget.isGuest ? _guestNameCtrl.text.trim() : '',
      );
      if (!mounted) return;
      setState(() {
        widget.post.comments = [...widget.post.comments, comment];
        widget.post.commentsCount = widget.post.comments.length;
        _textCtrl.clear();
        _sending = false;
      });
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      toast(context, 'تعذّر إرسال التعليق', error: true);
    }
  }

  Future<void> _deleteComment(PostComment c) async {
    try {
      await widget.api.deletePostComment(widget.post.id, c.id);
      if (!mounted) return;
      setState(() {
        widget.post.comments.removeWhere((x) => x.id == c.id);
        widget.post.commentsCount = widget.post.comments.length;
      });
      widget.onChanged();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final comments = widget.post.comments;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
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
              color: AppColors.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('التعليقات',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              ChipTag(text: '${comments.length}'),
            ],
          ),
          const Divider(height: 22),
          Expanded(
            child: comments.isEmpty
                ? const Center(
                    child: Text('لا توجد تعليقات بعد. كن أول من يعلّق!',
                        style: TextStyle(color: AppColors.muted)),
                  )
                : ListView.separated(
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final c = comments[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(c.authorName,
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w800)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: c.authorRole == 'القائد'
                                        ? AppColors.gold.withValues(alpha: 0.2)
                                        : AppColors.softViolet,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    c.authorRole,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: c.authorRole == 'القائد'
                                          ? AppColors.gold
                                          : AppColors.muted,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(relativeTimeAr(c.createdAt),
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                                if (widget.isLeader)
                                  GestureDetector(
                                    onTap: () => _deleteComment(c),
                                    child: const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: Icon(Icons.close, size: 16, color: AppColors.muted),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(c.text, style: const TextStyle(fontSize: 13, height: 1.5)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          if (widget.isGuest) ...[
            TextField(
              controller: _guestNameCtrl,
              decoration: const InputDecoration(
                hintText: 'اسمك (اختياري)',
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  decoration: const InputDecoration(
                    hintText: 'اكتب تعليقاً...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.purple,
                child: IconButton(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
