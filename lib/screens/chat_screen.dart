import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../core/chat_api.dart';
import '../core/chat_unread.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/member_card.dart';
import 'chat_member_profile.dart';

class ChatScreen extends StatefulWidget {
  final MemberStore store;
  final bool isActive;
  const ChatScreen({super.key, required this.store, this.isActive = false});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatApi api = ChatApi(widget.store);
  final text = TextEditingController();
  final recorder = AudioRecorder();
  Timer? poll;
  List<Map<String, dynamic>> messages = [];
  Map<String, dynamic>? reply;
  bool loading = true, sending = false, recording = false, fetching = false;
  String? error;

  @override
  void initState() {
    super.initState();
    refresh();
    poll = Timer.periodic(const Duration(seconds: 8), (_) => refresh());
  }
  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      unawaited(ChatUnread.update(messages, widget.store.sessionReg, active: true));
      unawaited(refresh());
    }
  }
  @override
  void dispose() { poll?.cancel(); text.dispose(); recorder.dispose(); super.dispose(); }
  void fail(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
  }
  Future<void> refresh() async {
    if (fetching) return;
    fetching = true;
    try {
      final next = await api.messages();
      if (mounted) {
        // Polling should not rebuild every image when no message changed.
        if (loading || error != null || jsonEncode(messages) != jsonEncode(next)) {
          setState(() { messages = next; loading = false; error = null; });
        }
        await ChatUnread.update(next, widget.store.sessionReg, active: widget.isActive);
      }
    } catch (e) { if (mounted) setState(() { loading = false; error = e.toString().replaceFirst('Bad state: ', ''); }); }
    finally { fetching = false; }
  }
  Future<void> send({String media = ''}) async {
    final value = text.text.trim();
    if (sending || (value.isEmpty && media.isEmpty)) return;
    setState(() => sending = true);
    try { await api.send(text: value, media: media, reply: reply); text.clear(); reply = null; await refresh(); }
    catch (e) { fail(e); }
    finally { if (mounted) setState(() => sending = false); }
  }
  String mimeFor(XFile f, bool video) {
    final name = f.name.toLowerCase();
    if (video) return name.endsWith('.webm') ? 'video/webm' : name.endsWith('.mov') ? 'video/quicktime' : 'video/mp4';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
  Future<void> attach(bool video) async {
    try {
      final picker = ImagePicker();
      final file = video ? await picker.pickVideo(source: ImageSource.gallery) : await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      if (mounted) setState(() => sending = true);
      final id = await api.upload(await file.readAsBytes(), mimeFor(file, video));
      if (mounted) setState(() => sending = false);
      await send(media: id);
    } catch (e) { if (mounted) setState(() => sending = false); fail(e); }
  }
  Future<void> toggleRecording() async {
    try {
      if (recording) {
        final path = await recorder.stop();
        if (mounted) setState(() { recording = false; sending = true; });
        if (path != null) {
          const mime = kIsWeb ? 'audio/webm' : 'audio/mp4';
          final id = await api.upload(await XFile(path).readAsBytes(), mime);
          if (mounted) setState(() => sending = false);
          await send(media: id);
        }
        if (mounted) setState(() => sending = false);
      } else {
        if (!await recorder.hasPermission()) throw StateError('لم يُسمح باستخدام الميكروفون');
        final path = kIsWeb ? 'epc-voice' : '${(await getTemporaryDirectory()).path}/epc-${DateTime.now().microsecondsSinceEpoch}.m4a';
        await recorder.start(RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc), path: path);
        if (mounted) setState(() => recording = true);
      }
    } catch (e) { if (mounted) setState(() { recording = false; sending = false; }); fail(e); }
  }
  Future<void> _react(Map<String, dynamic> m, String emoji) async {
    try { await api.react(m['id'] as String, emoji); await refresh(); }
    catch (e) { fail(e); }
  }
  Future<void> _deleteMessage(Map<String, dynamic> m) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('حذف الرسالة؟'),
      content: const Text('ستختفي الرسالة من المحادثة لدى الجميع.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red)))],
    ));
    if (confirmed != true) return;
    try {
      await api.deleteMessage(m['id'] as String);
      if (mounted) setState(() { messages.removeWhere((item) => item['id'] == m['id']); if (reply?['id'] == m['id']) reply = null; });
      await refresh();
    } catch (e) { fail(e); }
  }
  Future<void> chooseReaction(Map<String, dynamic> m) async {
    final own = m['authorId'] == widget.store.sessionReg;
    final action = await showModalBottomSheet<String>(context: context, showDragHandle: true,
      backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('التفاعل مع الرسالة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final e in ['❤️','👍','😂','🎉','😮'])
          InkResponse(onTap: () => Navigator.pop(sheetContext, 'reaction:$e'), radius: 26, child: Padding(padding: const EdgeInsets.all(8), child: Text(e, style: const TextStyle(fontSize: 25))))]),
        const Divider(height: 18),
        ListTile(leading: const Icon(Icons.reply_rounded, color: AppColors.purple), title: const Text('الرد على الرسالة'), onTap: () => Navigator.pop(sheetContext, 'reply')),
        ListTile(leading: const Icon(Icons.heart_broken_outlined, color: AppColors.muted), title: const Text('إزالة تفاعلي'), onTap: () => Navigator.pop(sheetContext, 'remove')),
        if (own) ListTile(leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB91C1C)), title: const Text('حذف الرسالة', style: TextStyle(color: Color(0xFFB91C1C))), onTap: () => Navigator.pop(sheetContext, 'delete')),
      ]))));
    if (!mounted || action == null) return;
    if (action == 'reply') { setState(() => reply = m); return; }
    if (action == 'delete') { await _deleteMessage(m); return; }
    await _react(m, action == 'remove' ? '' : action.substring('reaction:'.length));
  }
  Member? _memberFor(String? reg) {
    if (reg == null) return null;
    if (reg == widget.store.leaderReg) return widget.store.leaderMember;
    for (final member in widget.store.members) { if (member.regNumber == reg) return member; }
    return null;
  }
  void _openMember(Member? member) {
    if (member == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ملف العضو غير متاح حالياً'))); return; }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatMemberProfile(member: member)));
  }
  Future<void> saveMedia(String url) async {
    final uri = Uri.parse('$url&download=1');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw StateError('تعذّر فتح رابط التنزيل');
  }
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Column(children: [
      Container(padding: EdgeInsets.fromLTRB(16, top + 12, 16, 14), decoration: const BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        child: const Row(children: [CircleAvatar(radius: 18, backgroundColor: Colors.white24, child: Icon(Icons.forum_rounded, color: AppColors.goldSoft, size: 19)), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('دردشة النادي', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)), Text('مساحة تواصل أعضاء نادي رواد الاقتصاد', style: TextStyle(color: Colors.white70, fontSize: 11))]))])),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : error != null && messages.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: refresh, child: const Text('إعادة المحاولة'))])) : messages.isEmpty ? const Center(child: Text('ابدأ المحادثة مع أعضاء النادي')) : RefreshIndicator(onRefresh: refresh, child: ListView.builder(reverse: true, padding: const EdgeInsets.all(14), itemCount: messages.length, itemBuilder: (context, index) => messageBubble(messages[messages.length - index - 1])))),
      if (reply != null) Container(color: AppColors.softViolet, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: [Expanded(child: Text('رد على ${reply!['authorName']}: ${reply!['text']}', maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(onPressed: () => setState(() => reply = null), icon: const Icon(Icons.close))])),
      Padding(padding: EdgeInsets.fromLTRB(10, 4, 10, keyboard > 0 ? 8 : bottomInset(context, extra: 4)), child: Row(children: [
        PopupMenuButton<String>(tooltip: 'إرفاق', onSelected: (v) => attach(v == 'video'), itemBuilder: (_) => const [PopupMenuItem(value: 'image', child: Text('صورة')), PopupMenuItem(value: 'video', child: Text('فيديو'))], icon: const Icon(Icons.attach_file_rounded)),
        Expanded(child: TextField(controller: text, maxLines: 4, minLines: 1, textInputAction: TextInputAction.newline, decoration: const InputDecoration(hintText: 'اكتب رسالة…', border: OutlineInputBorder(), isDense: true))),
        IconButton(tooltip: recording ? 'إيقاف التسجيل وإرساله' : 'تسجيل رسالة صوتية', onPressed: sending ? null : toggleRecording, icon: Icon(recording ? Icons.stop_circle : Icons.mic_none_rounded, color: recording ? Colors.red : AppColors.purple)),
        IconButton.filled(tooltip: 'إرسال', style: IconButton.styleFrom(backgroundColor: AppColors.purple, foregroundColor: Colors.white, minimumSize: const Size(40, 40)), onPressed: sending ? null : () => send(), icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_upward_rounded, size: 20)),
      ])),
    ]);
  }
  Widget messageBubble(Map<String, dynamic> m) {
    final own = m['authorId'] == widget.store.sessionReg;
    final member = _memberFor(m['authorId'] as String?);
    final mediaUrl = m['mediaUrl'] as String? ?? '';
    final type = m['mediaType'] as String? ?? '';
    final reactions = (m['reactions'] as List? ?? []).whereType<Map>().toList();
    final date = DateTime.tryParse(m['createdAt'] as String? ?? '')?.toLocal();
    final maxBubble = math.min(315.0, math.max(130.0, MediaQuery.sizeOf(context).width - 104));
    final avatar = GestureDetector(onTap: () => _openMember(member), child: member != null
      ? MemberAvatar(member: member, size: 34)
      : const CircleAvatar(radius: 17, backgroundColor: AppColors.softViolet, child: Icon(Icons.person_outline, size: 19, color: AppColors.purple)));
    final content = Container(
      constraints: BoxConstraints(maxWidth: maxBubble),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
      decoration: BoxDecoration(
        color: own ? const Color(0xFFF1F5F8) : Colors.white,
        borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(own ? 6 : 18), bottomRight: Radius.circular(own ? 18 : 6)),
        border: Border.all(color: own ? const Color(0xFFDDE5EB) : const Color(0xFFE5E9ED)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (!own) Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(m['authorName'] as String? ?? 'عضو', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w800, fontSize: 11))), if (m['authorId'] == widget.store.leaderReg) ...[const SizedBox(width: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(8)), child: const Text('القائد', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.plum)))]])),
        if ((m['replyId'] as String? ?? '').isNotEmpty) Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .04), borderRadius: BorderRadius.circular(9)), child: Text('${m['replyName']}  ·  ${m['replyText']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.muted))),
        if (mediaUrl.isNotEmpty && type.startsWith('image/'))
          _MediaFrame(url: mediaUrl, child: GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ImageScreen(url: mediaUrl))), child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 290, maxWidth: 270, minWidth: 130), child: Image.network(mediaUrl, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, error, stack) => const SizedBox(height: 110, child: Center(child: Text('تعذّر تحميل الصورة')))))), onSave: () => saveMedia(mediaUrl)),
        if (mediaUrl.isNotEmpty && type.startsWith('video/'))
          _MediaFrame(url: mediaUrl, child: _VideoPreview(url: mediaUrl), onSave: () => saveMedia(mediaUrl)),
        if (mediaUrl.isNotEmpty && type.startsWith('audio/'))
          _VoiceMessage(key: ValueKey('voice_${m['id']}'), url: mediaUrl, own: own),
        if (mediaUrl.isNotEmpty && type.startsWith('audio/'))
          Align(alignment: Alignment.centerLeft, child: InkWell(onTap: () async { try { await saveMedia(mediaUrl); } catch (e) { fail(e); } }, child: const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.download_rounded, size: 17, color: AppColors.muted)))),
        if ((m['text'] as String? ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(m['text'] as String, style: const TextStyle(fontSize: 14, height: 1.48, color: AppColors.ink))),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (date != null) Text('${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          if (reactions.isNotEmpty) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .8), borderRadius: BorderRadius.circular(20)), child: Text(reactions.take(5).map((r) => r['emoji']).join(' '), style: const TextStyle(fontSize: 12)))],
        ]),
      ]),
    );
    return _SwipeReply(key: ValueKey(m['id']), onReply: () => setState(() => reply = m),
      child: Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(
        textDirection: own ? TextDirection.ltr : TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.end, children: [
          avatar, const SizedBox(width: 7),
          Flexible(child: _HeartReaction(key: ValueKey('heart_${m['id']}'), onDoubleTap: () => _react(m, '❤️'), onLongPress: () => chooseReaction(m), child: content)),
          const Spacer(),
        ],
      )));
  }

}

class _HeartReaction extends StatefulWidget {
  final Widget child;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  const _HeartReaction({super.key, required this.child, required this.onDoubleTap, required this.onLongPress});
  @override State<_HeartReaction> createState() => _HeartReactionState();
}
class _HeartReactionState extends State<_HeartReaction> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => GestureDetector(
    onLongPress: widget.onLongPress,
    onDoubleTap: () { HapticFeedback.lightImpact(); controller.forward(from: 0); widget.onDoubleTap(); },
    child: Stack(alignment: Alignment.center, children: [
      widget.child,
      IgnorePointer(child: AnimatedBuilder(animation: controller, builder: (context, child) {
        final t = controller.value;
        final opacity = t == 0 ? 0.0 : (t < .7 ? 1.0 : ((1-t)/.3).clamp(0.0, 1.0));
        final scale = t < .30 ? Curves.elasticOut.transform((t/.30).clamp(0.0, 1.0)) : 1.0;
        return Opacity(opacity: opacity, child: Transform.scale(scale: scale, child: child));
      }, child: const Icon(Icons.favorite_rounded, size: 64, color: Color(0xFFE53159), shadows: [Shadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))]))),
    ]),
  );
}

class _MediaFrame extends StatelessWidget {
  final String url;
  final Widget child;
  final Future<void> Function() onSave;
  const _MediaFrame({required this.url, required this.child, required this.onSave});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5, bottom: 3),
    child: ClipRRect(borderRadius: BorderRadius.circular(13), child: Stack(children: [
      child,
      PositionedDirectional(top: 6, end: 6, child: Material(color: Colors.black54, shape: const CircleBorder(), child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async { try { await onSave(); } catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر فتح رابط الحفظ'))); } },
        child: const Padding(padding: EdgeInsets.all(7), child: Icon(Icons.download_rounded, color: Colors.white, size: 18)),
      ))),
    ])),
  );
}
class _ImageScreen extends StatelessWidget {
  final String url;
  const _ImageScreen({required this.url});
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('الصورة')),
    body: Center(child: InteractiveViewer(minScale: .7, maxScale: 5, child: Image.network(url, fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, error, stack) => const Text('تعذّر تحميل الصورة', style: TextStyle(color: Colors.white))))),
  );
}
class _VideoPreview extends StatefulWidget {
  final String url;
  const _VideoPreview({required this.url});
  @override State<_VideoPreview> createState() => _VideoPreviewState();
}
class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController video;
  late Future<void> loading;
  @override void initState() { super.initState(); _load(); }
  void _load() { video = VideoPlayerController.networkUrl(Uri.parse(widget.url)); loading = video.initialize(); }
  @override void didUpdateWidget(covariant _VideoPreview oldWidget) { super.didUpdateWidget(oldWidget); if (Uri.tryParse(oldWidget.url)?.path != Uri.tryParse(widget.url)?.path) { video.dispose(); _load(); } }
  @override void dispose() { video.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => SizedBox(width: 260, height: 160, child: InkWell(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _VideoScreen(url: widget.url))),
    child: Stack(fit: StackFit.expand, alignment: Alignment.center, children: [
      Container(color: const Color(0xFF101D30)),
      FutureBuilder<void>(future: loading, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || snapshot.hasError) return const SizedBox.shrink();
        return FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: video.value.size.width, height: video.value.size.height, child: VideoPlayer(video)));
      }),
      Center(child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30))),
    ]),
  ));
}

class _SwipeReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  const _SwipeReply({super.key, required this.child, required this.onReply});
  @override State<_SwipeReply> createState() => _SwipeReplyState();
}
class _SwipeReplyState extends State<_SwipeReply> {
  double dx = 0;
  bool dragging = false;
  @override Widget build(BuildContext context) => GestureDetector(
    onHorizontalDragStart: (_) => setState(() => dragging = true),
    onHorizontalDragUpdate: (event) => setState(() => dx = (dx + event.delta.dx).clamp(-68.0, 68.0)),
    onHorizontalDragCancel: () => setState(() { dragging = false; dx = 0; }),
    onHorizontalDragEnd: (_) {
      if (dx.abs() > 38) { HapticFeedback.selectionClick(); widget.onReply(); }
      setState(() { dragging = false; dx = 0; });
    },
    child: Stack(alignment: dx < 0 ? Alignment.centerRight : Alignment.centerLeft, children: [
      if (dx.abs() > 5) Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Opacity(opacity: (dx.abs()/48).clamp(0.0,1.0), child: const CircleAvatar(radius: 15, child: Icon(Icons.reply_rounded, size: 17)))),
      AnimatedContainer(duration: dragging ? Duration.zero : const Duration(milliseconds: 220), curve: Curves.easeOutCubic, transform: Matrix4.translationValues(dx, 0, 0), child: widget.child),
    ]),
  );
}

class _VoiceMessage extends StatefulWidget {
  final String url;
  final bool own;
  const _VoiceMessage({super.key, required this.url, required this.own});
  @override State<_VoiceMessage> createState() => _VoiceMessageState();
}
class _VoiceMessageState extends State<_VoiceMessage> {
  final AudioPlayer audio = AudioPlayer();
  final List<StreamSubscription<dynamic>> subscriptions = [];
  Duration position = Duration.zero, duration = Duration.zero;
  bool playing = false, loaded = false;
  @override void initState() {
    super.initState();
    subscriptions.add(audio.onPositionChanged.listen((v) { if (mounted) setState(() => position=v); }));
    subscriptions.add(audio.onDurationChanged.listen((v) { if (mounted) setState(() => duration=v); }));
    subscriptions.add(audio.onPlayerStateChanged.listen((v) { if (mounted) setState(() => playing=v==PlayerState.playing); }));
    subscriptions.add(audio.onPlayerComplete.listen((_) { if (mounted) setState(() { playing=false; position=Duration.zero; }); }));
  }
  @override void dispose() { for (final s in subscriptions) { s.cancel(); } audio.dispose(); super.dispose(); }
  String time(Duration v) => '${v.inMinutes.toString().padLeft(2,'0')}:${(v.inSeconds%60).toString().padLeft(2,'0')}';
  Future<void> toggle() async {
    try {
      if (playing) { await audio.pause(); }
      else if (loaded) { await audio.resume(); }
      else { await audio.play(UrlSource(widget.url)); loaded = true; }
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر تشغيل الرسالة الصوتية'))); }
  }
  @override Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0 ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0) : 0.0;
    return Padding(padding: const EdgeInsets.only(top: 8, bottom: 3), child: ClipRRect(borderRadius: BorderRadius.circular(22), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12,sigmaY: 12), child: Container(
      width: 245, padding: const EdgeInsets.symmetric(horizontal: 8,vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: widget.own ? .58 : .85), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha:.8))),
      child: Row(children: [
        Material(color: AppColors.purple, shape: const CircleBorder(), child: InkWell(onTap: toggle, customBorder: const CircleBorder(), child: Padding(padding: const EdgeInsets.all(8),child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 21)))),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(behavior: HitTestBehavior.opaque, onTapDown: (d) { if (duration.inMilliseconds>0) { final w=context.size?.width ?? 200; audio.seek(Duration(milliseconds: (duration.inMilliseconds*(d.localPosition.dx/w).clamp(0.0,1.0)).round())); } },
            child: SizedBox(height: 26, width: double.infinity, child: CustomPaint(painter: _WavePainter(progress)))),
          Text(duration == Duration.zero ? 'رسالة صوتية' : '${time(position)} / ${time(duration)}', style: const TextStyle(fontSize: 10,color: AppColors.muted)),
        ])),
        const SizedBox(width: 4), const Icon(Icons.graphic_eq_rounded,size: 18,color: AppColors.purple),
      ]),
    ))));
  }
}
class _WavePainter extends CustomPainter {
  final double progress;
  _WavePainter(this.progress);
  @override void paint(Canvas canvas, Size size) {
    const count=34;
    final spacing=size.width/count;
    for(var i=0;i<count;i++) {
      final amp=0.22+0.78*(math.sin(i*2.2).abs()*math.sin(i*.31+1).abs());
      final h=4+(size.height-4)*amp;
      final paint=Paint()..color=(i/count<=progress ? AppColors.purple : AppColors.purple.withValues(alpha:.24))..strokeWidth=math.max(1.5,spacing*.43)..strokeCap=StrokeCap.round;
      canvas.drawLine(Offset(i*spacing,size.height/2-h/2),Offset(i*spacing,size.height/2+h/2),paint);
    }
  }
  @override bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.progress != progress;
}

class _VideoScreen extends StatefulWidget {
  final String url;
  const _VideoScreen({required this.url});
  @override State<_VideoScreen> createState() => _VideoScreenState();
}
class _VideoScreenState extends State<_VideoScreen> {
  late final VideoPlayerController controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  late final Future<void> ready = controller.initialize();
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('الفيديو')), body: Center(child: FutureBuilder<void>(future: ready, builder: (context, snapshot) {
    if (snapshot.hasError) return const Text('تعذّر تشغيل الفيديو');
    if (snapshot.connectionState != ConnectionState.done) return const CircularProgressIndicator();
    return Column(mainAxisSize: MainAxisSize.min, children: [AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)), IconButton(iconSize: 44, onPressed: () => setState(() { controller.value.isPlaying ? controller.pause() : controller.play(); }), icon: Icon(controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle))]);
  })));
}
