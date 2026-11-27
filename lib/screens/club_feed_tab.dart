import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../core/cloud_sync.dart';
import '../core/club_api.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/member_card.dart';
import '../widgets/smart_text.dart';
import 'chat_member_profile.dart';

const List<String> kFeedCategories = [
  'الكل',
  'فعالية',
  'ورشة عمل',
  'إنجاز',
  'تغطية',
  'إعلان',
];

/// فرع نشاطات النادي المصوّرة (صور متعددة وفيديوهات)
/// القائد فقط ينشر ويحذف، والأعضاء والضيوف يشاهدون ويتفاعلون (قلب، تعليق، مشاركة)
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
  String? _activeHashtag;

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
    var list = _selectedCategory == 'الكل'
        ? _posts
        : _posts.where((p) => p.category == _selectedCategory).toList();
    if (_activeHashtag != null && _activeHashtag!.isNotEmpty) {
      final tag = _activeHashtag!.toLowerCase();
      list = list
          .where((p) =>
              p.caption.toLowerCase().contains(tag) || p.title.toLowerCase().contains(tag))
          .toList();
    }
    return list;
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
      toast(context, 'تم نشر نشاط النادي بنجاح ✓');
    }
  }

  Future<void> _toggleLike(ClubPost post) async {
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
        store: widget.store,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('مشاركة المنشور',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
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
                  const SizedBox(width: 10),
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
        title: const Text('حذف المنشور', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
    } catch (_) {
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
          if (_activeHashtag != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Row(
                children: [
                  ChipTag(text: 'تصفية: $_activeHashtag', color: AppColors.purple, icon: Icons.tag_rounded),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _activeHashtag = null),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('إلغاء', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, bottomInset(context)),
            child: Column(
              children: [
                if (widget.isLeader) ...[
                  PrimaryButton(
                    label: 'نشر منشور نشاط جديد (صور متعددة / فيديو)',
                    icon: Icons.add_photo_alternate_outlined,
                    gold: true,
                    onPressed: _openComposer,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.purple, strokeWidth: 2.4),
                        SizedBox(height: 10),
                        Text('جاري تحميل نشاطات النادي...',
                            style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                      ],
                    ),
                  )
                else if (_error != null && _posts.isEmpty)
                  EmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'تعذّر تحميل نشاطات النادي',
                    subtitle: 'اسحب للأسفل لإعادة المحاولة وتحديث المنشورات.',
                    action: SizedBox(
                      width: 170,
                      child: PrimaryButton(label: 'إعادة المحاولة', onPressed: _load),
                    ),
                  )
                else if (items.isEmpty)
                  EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: 'لا توجد منشورات بعد',
                    subtitle: widget.isLeader
                        ? 'انشر أول تغطية مصورة أو ألبوم صور أو فيديو لنشاطات النادي.'
                        : 'ستظهر هنا صور وفيديوهات نشاطات النادي فور نشرها من القائد.',
                  )
                else
                  for (var i = 0; i < items.length; i++) ...[
                    FadeSlideIn(
                      delayMs: (i * 45).clamp(0, 220),
                      child: _ClubPostCard(
                        store: widget.store,
                        post: items[i],
                        isLeader: widget.isLeader,
                        onLike: () => _toggleLike(items[i]),
                        onComment: () => _openComments(items[i]),
                        onShare: () => _sharePost(items[i]),
                        onDelete: () => _deletePost(items[i]),
                        onHashtagTap: (tag) => setState(() => _activeHashtag = tag),
                      ),
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

  Widget _header(BuildContext context, double top) {
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
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.75)),
            ),
            child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'نشاطات النادي',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  widget.isGuest ? 'بوابة الضيوف • معرض النادي' : 'صور وفيديوهات نادي رواد الاقتصاد',
                  style: TextStyle(
                    color: AppColors.goldSoft.withValues(alpha: 0.9),
                    fontSize: 10.5,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
              ),
              icon: const Icon(Icons.login_rounded, size: 14, color: AppColors.goldSoft),
              label: const Text('دخول الأعضاء',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _guestJoinBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.plum, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('انضم لنادي رواد الاقتصاد',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text('قدّم طلبك للوصول للدردشة والاستطلاعات والفعاليات.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (widget.onSwitchToJoin != null)
            FilledButton(
              onPressed: widget.onSwitchToJoin,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('انضم الآن',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _categoryBar() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
        scrollDirection: Axis.horizontal,
        itemCount: kFeedCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final cat = kFeedCategories[i];
          final active = cat == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: active ? AppColors.headerGradient : null,
                color: active ? null : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: active ? AppColors.purple : AppColors.line),
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 11.5,
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
}

class _ClubPostCard extends StatefulWidget {
  final MemberStore store;
  final ClubPost post;
  final bool isLeader;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final ValueChanged<String>? onHashtagTap;

  const _ClubPostCard({
    required this.store,
    required this.post,
    required this.isLeader,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onDelete,
    this.onHashtagTap,
  });

  @override
  State<_ClubPostCard> createState() => _ClubPostCardState();
}

class _ClubPostCardState extends State<_ClubPostCard> {
  bool _showBurst = false;
  int _imgRetry = 0;
  int _carouselIndex = 0;

  void _handleDoubleTap() {
    if (!widget.post.likedByMe) widget.onLike();
    setState(() => _showBurst = true);
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showBurst = false);
    });
  }

  void _openAuthorProfile(Member author) {
    if (widget.store.sessionReg == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatMemberProfile(member: author)),
    );
  }

  Widget _buildSingleMedia(PostMediaItem item, List<PostMediaItem> allImages, int imageIdx) {
    if (item.isVideo) {
      return _FeedVideoPlayer(url: item.url);
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _FullGalleryViewer(
            images: allImages,
            initialIndex: imageIdx,
            title: widget.post.title,
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360, minHeight: 160),
        child: Image.network(
          '${item.url}${_imgRetry > 0 ? '?r=$_imgRetry' : ''}',
          key: ValueKey('${item.id}_$_imgRetry'),
          width: double.infinity,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            final pct = progress.expectedTotalBytes != null && progress.expectedTotalBytes! > 0
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null;
            return Container(
              height: 210,
              color: AppColors.softViolet,
              child: Center(
                child: CircularProgressIndicator(
                    value: pct, strokeWidth: 2.4, color: AppColors.purple),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            height: 160,
            color: AppColors.softViolet,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined, size: 32, color: AppColors.muted),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => setState(() => _imgRetry++),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('إعادة تحميل الصورة', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = findMemberByReg(widget.store, post.authorId) ?? widget.store.leaderMember;
    final media = post.mediaItems;
    final imageItems = media.where((m) => m.isImage).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openAuthorProfile(author),
                      child: MemberAvatar(member: author, size: 36),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openAuthorProfile(author),
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
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.goldGradient,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'القائد',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.plum),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                Text(
                                  relativeTimeAr(post.createdAt),
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                                ),
                                if (post.location.isNotEmpty) ...[
                                  const Text(' • ',
                                      style: TextStyle(color: AppColors.muted, fontSize: 10.5)),
                                  const Icon(Icons.place_outlined, size: 11, color: AppColors.muted),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      post.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    ChipTag(text: post.category, color: AppColors.purple),
                    if (widget.isLeader)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Color(0xFFB91C1C)),
                        onPressed: widget.onDelete,
                      ),
                  ],
                ),
              ),
              if (post.title.isNotEmpty || post.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.title.isNotEmpty)
                        Text(
                          post.title,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                      if (post.title.isNotEmpty && post.caption.isNotEmpty)
                        const SizedBox(height: 4),
                      if (post.caption.isNotEmpty)
                        RichSmartText(
                          post.caption,
                          store: widget.store,
                          allowProfileNavigation: widget.store.sessionReg != null,
                          onHashtagTap: widget.onHashtagTap,
                          style: const TextStyle(
                              fontSize: 13, height: 1.55, color: Color(0xFF334155)),
                        ),
                    ],
                  ),
                ),

              // ── وسائط المنشور (صورة/فيديو واحد أو ألبوم منزلق لعدة صور وفيديوهات) ──
              if (media.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: GestureDetector(
                    onDoubleTap: _handleDoubleTap,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (media.length == 1)
                                _buildSingleMedia(media.first, imageItems, 0)
                              else
                                SizedBox(
                                  height: 300,
                                  child: PageView.builder(
                                    itemCount: media.length,
                                    onPageChanged: (idx) => setState(() => _carouselIndex = idx),
                                    itemBuilder: (_, idx) {
                                      final item = media[idx];
                                      final imgPos = imageItems.indexWhere((x) => x.id == item.id);
                                      return _buildSingleMedia(
                                          item, imageItems, imgPos < 0 ? 0 : imgPos);
                                    },
                                  ),
                                ),
                              if (media.length > 1)
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      '${_carouselIndex + 1} / ${media.length}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              AnimatedScale(
                                scale: _showBurst ? 1.15 : 0.0,
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.elasticOut,
                                child: AnimatedOpacity(
                                  opacity: _showBurst ? 0.95 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    size: 78,
                                    color: Colors.white,
                                    shadows: [Shadow(color: Colors.black45, blurRadius: 18)],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (media.length > 1) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < media.length; i++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: i == _carouselIndex ? 16 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: i == _carouselIndex ? AppColors.gold : AppColors.line,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // ── شريط التفاعل ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
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
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.onComment,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded,
                                size: 18, color: AppColors.muted),
                            const SizedBox(width: 5),
                            Text(
                              '${post.commentsCount}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.onShare,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.share_outlined, size: 17, color: AppColors.purple),
                            const SizedBox(width: 5),
                            Text(
                              post.sharesCount > 0 ? 'مشاركة (${post.sharesCount})' : 'مشاركة',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.purple),
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
        ),
      ),
    );
  }
}

class _FullGalleryViewer extends StatefulWidget {
  final List<PostMediaItem> images;
  final int initialIndex;
  final String title;

  const _FullGalleryViewer({
    required this.images,
    required this.initialIndex,
    required this.title,
  });

  @override
  State<_FullGalleryViewer> createState() => _FullGalleryViewerState();
}

class _FullGalleryViewerState extends State<_FullGalleryViewer> {
  late final PageController _ctrl = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.images.length > 1
              ? '${_index + 1} / ${widget.images.length}'
              : (widget.title.isEmpty ? 'عرض الصورة' : widget.title),
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: PageView.builder(
          controller: _ctrl,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.network(widget.images[i].url, fit: BoxFit.contain),
            ),
          ),
        ),
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
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _ready = false;
      _failed = false;
    });
    await _controller?.dispose();
    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: const {'Accept': '*/*'},
    );
    _controller = ctrl;
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        height: 190,
        color: AppColors.plum,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 32),
              const SizedBox(height: 6),
              const Text('تعذّر تحميل الفيديو',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              TextButton.icon(
                onPressed: _init,
                icon: const Icon(Icons.refresh, color: AppColors.goldSoft, size: 16),
                label: const Text('إعادة المحاولة',
                    style: TextStyle(color: AppColors.goldSoft, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }
    if (!_ready || _controller == null) {
      return Container(
        height: 200,
        color: AppColors.plum,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.goldSoft, strokeWidth: 2.3),
              SizedBox(height: 8),
              Text('جاري تجهيز الفيديو...',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5)),
            ],
          ),
        ),
      );
    }
    final ctrl = _controller!;
    final ratio = ctrl.value.aspectRatio > 0 ? ctrl.value.aspectRatio : 16 / 9;
    return GestureDetector(
      onTap: () {
        setState(() {
          ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(aspectRatio: ratio, child: VideoPlayer(ctrl)),
          if (!ctrl.value.isPlaying)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.plum.withValues(alpha: 0.72),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldSoft, width: 1.5),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              ctrl,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.gold,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.black26,
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _muted = !_muted;
                  ctrl.setVolume(_muted ? 0 : 1);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedMedia {
  final XFile file;
  final Uint8List? previewBytes;
  final int size;
  final String mime;
  final bool isVideo;

  const _PickedMedia({
    required this.file,
    required this.previewBytes,
    required this.size,
    required this.mime,
    required this.isVideo,
  });
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
  final List<_PickedMedia> _picked = [];
  bool _publishing = false;
  String _statusText = '';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 86);
    if (files.isEmpty) return;
    for (final file in files) {
      if (_picked.length >= 10) {
        if (mounted) toast(context, 'الحد الأقصى 10 صور/فيديوهات لكل منشور');
        break;
      }
      final size = await file.length();
      if (size > ClubApi.maxFeedMediaBytes) {
        if (mounted) toast(context, 'تم تخطي صورة تتجاوز 95 ميغابايت', error: true);
        continue;
      }
      final preview = size <= 10 * 1024 * 1024 ? await file.readAsBytes() : null;
      final lower = file.name.toLowerCase();
      final mime = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
              ? 'image/webp'
              : lower.endsWith('.gif')
                  ? 'image/gif'
                  : 'image/jpeg';
      _picked.add(_PickedMedia(
        file: file,
        previewBytes: preview,
        size: size,
        mime: mime,
        isVideo: false,
      ));
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickVideo() async {
    if (_picked.length >= 10) {
      toast(context, 'الحد الأقصى 10 وسائط لكل منشور');
      return;
    }
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    final size = await file.length();
    if (size > ClubApi.maxFeedMediaBytes) {
      if (mounted) toast(context, 'حجم الفيديو يتجاوز 95 ميغابايت', error: true);
      return;
    }
    final lower = file.name.toLowerCase();
    final mime = lower.endsWith('.webm')
        ? 'video/webm'
        : lower.endsWith('.mov')
            ? 'video/quicktime'
            : 'video/mp4';
    if (!mounted) return;
    setState(() {
      _picked.add(_PickedMedia(
        file: file,
        previewBytes: null,
        size: size,
        mime: mime,
        isVideo: true,
      ));
    });
  }

  Future<void> _publish() async {
    if (_titleCtrl.text.trim().isEmpty && _captionCtrl.text.trim().isEmpty && _picked.isEmpty) {
      toast(context, 'أضف عنواناً أو وصفاً أو صوراً/فيديو للنشر', error: true);
      return;
    }
    setState(() {
      _publishing = true;
      _statusText = _picked.isNotEmpty ? 'جاري تجهيز رفع الوسائط...' : 'جاري نشر المنشور...';
    });
    try {
      final uploadedItems = <Map<String, String>>[];
      for (var i = 0; i < _picked.length; i++) {
        final item = _picked[i];
        if (mounted) {
          setState(() {
            _statusText =
                'جاري رفع الملف ${i + 1} من ${_picked.length} (${(item.size / (1024 * 1024)).toStringAsFixed(1)} MB)...';
          });
        }
        final uploaded = kIsWeb
            ? await widget.api.uploadFeedMedia(
                await item.file.readAsBytes(),
                item.mime,
                isVideo: item.isVideo,
              )
            : await widget.api.uploadFeedMediaStream(
                item.file.openRead(),
                item.size,
                item.mime,
                isVideo: item.isVideo,
              );
        uploadedItems.add({'id': uploaded.id, 'type': uploaded.type});
      }
      if (mounted) setState(() => _statusText = 'جاري حفظ ونشر المنشور...');
      final post = await widget.api.createPost(
        title: _titleCtrl.text.trim(),
        caption: _captionCtrl.text.trim(),
        category: _category,
        location: _locationCtrl.text.trim(),
        mediaItems: uploadedItems,
      );
      if (!mounted) return;
      Navigator.pop(context, post);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _statusText = '';
      });
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
            const Text('نشر نشاط للنادي',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
            const Text('يمكنك إرفاق حتى 10 صور وفيديوهات، واستخدام #الهاشتاغات والروابط.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cat in kFeedCategories.where((c) => c != 'الكل'))
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(cat, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    selected: _category == cat,
                    selectedColor: AppColors.purple,
                    labelStyle: TextStyle(color: _category == cat ? Colors.white : AppColors.ink),
                    onSelected: (_) => setState(() => _category = cat),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: 'عنوان النشاط',
                prefixIcon: Icon(Icons.title_rounded, color: AppColors.purple, size: 19),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _captionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'تفاصيل النشاط (يدعم الروابط و #الهاشتاغات و @المنشن)...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                hintText: 'المكان (اختياري)',
                prefixIcon: Icon(Icons.place_outlined, color: AppColors.purple, size: 19),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: _picked.isEmpty ? 'إرفاق صور' : 'إضافة صور (${_picked.length}/10)',
                    icon: Icons.collections_outlined,
                    onPressed: _publishing ? null : _pickImages,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GhostButton(
                    label: 'إرفاق فيديو',
                    icon: Icons.videocam_outlined,
                    onPressed: _publishing ? null : _pickVideo,
                  ),
                ),
              ],
            ),
            if (_picked.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _picked.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final item = _picked[i];
                    return Stack(
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: AppColors.softViolet,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.line),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: (!item.isVideo && item.previewBytes != null)
                              ? Image.memory(item.previewBytes!, fit: BoxFit.cover)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      item.isVideo
                                          ? Icons.videocam_rounded
                                          : Icons.photo_rounded,
                                      color: AppColors.purple,
                                      size: 26,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(item.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                                      style: const TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                        ),
                        if (!_publishing)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _picked.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
            if (_publishing && _statusText.isNotEmpty) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                  color: AppColors.gold, backgroundColor: AppColors.softViolet),
              const SizedBox(height: 6),
              Text(_statusText,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.purple, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 14),
            PrimaryButton(
              label: _publishing ? 'جاري النشر...' : 'نشر الآن',
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
  final MemberStore store;
  final ClubApi api;
  final ClubPost post;
  final bool isLeader;
  final bool isGuest;
  final VoidCallback onChanged;

  const _PostCommentsSheet({
    required this.store,
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
    final comments = widget.post.comments;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.70,
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
          Row(
            children: [
              const Text('التعليقات', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              ChipTag(text: '${comments.length}'),
            ],
          ),
          const Divider(height: 18),
          Expanded(
            child: comments.isEmpty
                ? const Center(
                    child: Text('لا توجد تعليقات بعد. كن أول من يعلّق!',
                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  )
                : ListView.separated(
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = comments[i];
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
                              GestureDetector(
                                onTap: !widget.isGuest
                                    ? () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) => ChatMemberProfile(member: member)),
                                        )
                                    : null,
                                child: MemberAvatar(member: member, size: 30),
                              )
                            else
                              const CircleAvatar(
                                radius: 15,
                                backgroundColor: AppColors.softViolet,
                                child: Icon(Icons.person_outline, size: 16, color: AppColors.purple),
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: GestureDetector(
                                          onTap: (!widget.isGuest && member != null)
                                              ? () => Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            ChatMemberProfile(member: member)),
                                                  )
                                              : null,
                                          child: Text(c.authorName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 12.5, fontWeight: FontWeight.w800)),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: c.authorRole == 'القائد'
                                              ? AppColors.gold.withValues(alpha: 0.2)
                                              : AppColors.softViolet,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          c.authorRole,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: c.authorRole == 'القائد'
                                                ? AppColors.gold
                                                : AppColors.muted,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(relativeTimeAr(c.createdAt),
                                          style: const TextStyle(
                                              fontSize: 10, color: AppColors.muted)),
                                      if (widget.isLeader)
                                        GestureDetector(
                                          onTap: () => _deleteComment(c),
                                          child: const Padding(
                                            padding: EdgeInsets.only(right: 5),
                                            child:
                                                Icon(Icons.close, size: 15, color: AppColors.muted),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  RichSmartText(
                                    c.text,
                                    store: widget.store,
                                    allowProfileNavigation: !widget.isGuest,
                                    style: const TextStyle(fontSize: 12.5, height: 1.45),
                                  ),
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
          if (widget.isGuest) ...[
            TextField(
              controller: _guestNameCtrl,
              decoration: const InputDecoration(hintText: 'اسمك (اختياري)'),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  decoration: const InputDecoration(hintText: 'اكتب تعليقاً...'),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 21,
                backgroundColor: AppColors.purple,
                child: IconButton(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
