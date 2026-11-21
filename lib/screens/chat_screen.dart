import 'dart:async';
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
        setState(() { messages = next; loading = false; error = null; });
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
          final mime = kIsWeb ? 'audio/webm' : 'audio/mp4';
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
  Future<void> chooseReaction(Map<String, dynamic> m) async {
    final emoji = await showModalBottomSheet<String>(context: context, builder: (context) => SafeArea(child: Wrap(children: [
      for (final e in ['❤️', '👍', '😂', '🎉', '😮', 'إزالة'])
        TextButton(onPressed: () => Navigator.pop(context, e == 'إزالة' ? '' : e), child: Text(e, style: const TextStyle(fontSize: 24))),
      TextButton(onPressed: () { Navigator.pop(context); setState(() => reply = m); }, child: const Text('رد')),
    ])));
    if (emoji != null) { try { await api.react(m['id'] as String, emoji); await refresh(); } catch (e) { fail(e); } }
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
      Container(padding: EdgeInsets.fromLTRB(18, top + 14, 18, 18), decoration: const BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(26))),
        child: const Row(children: [CircleAvatar(child: Icon(Icons.groups_rounded)), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('دردشة النادي', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)), Text('مساحة أعضاء نادي رواد الاقتصاد', style: TextStyle(color: Colors.white70, fontSize: 12))]))])),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : error != null && messages.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: refresh, child: const Text('إعادة المحاولة'))])) : messages.isEmpty ? const Center(child: Text('ابدأ المحادثة مع أعضاء النادي')) : RefreshIndicator(onRefresh: refresh, child: ListView.builder(reverse: true, padding: const EdgeInsets.all(14), itemCount: messages.length, itemBuilder: (context, index) => messageBubble(messages[messages.length - index - 1])))),
      if (reply != null) Container(color: AppColors.softViolet, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: [Expanded(child: Text('رد على ${reply!['authorName']}: ${reply!['text']}', maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(onPressed: () => setState(() => reply = null), icon: const Icon(Icons.close))])),
      Padding(padding: EdgeInsets.fromLTRB(12, 4, 12, keyboard > 0 ? 8 : MediaQuery.paddingOf(context).bottom + 8), child: Row(children: [
        PopupMenuButton<String>(tooltip: 'إرفاق', onSelected: (v) => attach(v == 'video'), itemBuilder: (_) => const [PopupMenuItem(value: 'image', child: Text('صورة')), PopupMenuItem(value: 'video', child: Text('فيديو'))], icon: const Icon(Icons.attach_file_rounded)),
        Expanded(child: TextField(controller: text, maxLines: 4, minLines: 1, textInputAction: TextInputAction.newline, decoration: const InputDecoration(hintText: 'اكتب رسالة…', border: OutlineInputBorder(), isDense: true))),
        IconButton(tooltip: recording ? 'إيقاف التسجيل وإرساله' : 'تسجيل رسالة صوتية', onPressed: sending ? null : toggleRecording, icon: Icon(recording ? Icons.stop_circle : Icons.mic_none_rounded, color: recording ? Colors.red : AppColors.purple)),
        IconButton(tooltip: 'إرسال', onPressed: sending ? null : () => send(), icon: sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded, color: AppColors.purple)),
      ])),
    ]);
  }
  Widget messageBubble(Map<String, dynamic> m) {
    final own = m['authorId'] == widget.store.sessionReg;
    final mediaUrl = m['mediaUrl'] as String? ?? '';
    final type = m['mediaType'] as String? ?? '';
    final reactions = (m['reactions'] as List? ?? []).whereType<Map>().toList();
    final date = DateTime.tryParse(m['createdAt'] as String? ?? '')?.toLocal();
    return _SwipeReply(key: ValueKey(m['id']), onReply: () => setState(() => reply = m), child: Align(alignment: own ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(onLongPress: () => chooseReaction(m), child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), constraints: const BoxConstraints(maxWidth: 330), decoration: BoxDecoration(color: own ? AppColors.softViolet : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(m['authorName'] as String? ?? 'عضو', style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w800, fontSize: 12)),
        if ((m['replyId'] as String? ?? '').isNotEmpty) Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .04), borderRadius: BorderRadius.circular(8)), child: Text('رد على ${m['replyName']}: ${m['replyText']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
        if (mediaUrl.isNotEmpty && type.startsWith('image/')) GestureDetector(onTap: () => showDialog<void>(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(mediaUrl)))), child: Padding(padding: const EdgeInsets.only(top: 8), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(mediaUrl, height: 180, width: 260, fit: BoxFit.cover, errorBuilder: (_, error, stack) => const Text('تعذّر تحميل الصورة'))))),
        if (mediaUrl.isNotEmpty && type.startsWith('video/')) TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _VideoScreen(url: mediaUrl))), icon: const Icon(Icons.play_circle_outline), label: const Text('معاينة الفيديو')),
        if (mediaUrl.isNotEmpty && type.startsWith('audio/')) _VoiceMessage(key: ValueKey('voice_${m['id']}'), url: mediaUrl, own: own),
        if (mediaUrl.isNotEmpty) TextButton.icon(onPressed: () async { try { await saveMedia(mediaUrl); } catch (e) { fail(e); } }, icon: const Icon(Icons.download_rounded, size: 16), label: const Text('حفظ', style: TextStyle(fontSize: 12))),
        if ((m['text'] as String? ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text(m['text'] as String, style: const TextStyle(fontSize: 14, height: 1.5))),
        Row(mainAxisSize: MainAxisSize.min, children: [if (date != null) Text('${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 10, color: AppColors.muted)), const SizedBox(width: 8), for (final r in reactions.take(8)) Text('${r['emoji']} ', style: const TextStyle(fontSize: 13)), InkWell(onTap: () => chooseReaction(m), child: const Icon(Icons.add_reaction_outlined, size: 16, color: AppColors.muted))]),
      ])))));
  }
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
