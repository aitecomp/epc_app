import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync.dart';
import 'push_notifications.dart';
import 'store.dart';

class PostComment {
  final String id;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String text;
  final DateTime createdAt;

  const PostComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.text,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> j) => PostComment(
        id: (j['id'] ?? '').toString(),
        authorId: (j['authorId'] ?? '').toString(),
        authorName: (j['authorName'] ?? 'مستخدم').toString(),
        authorRole: (j['authorRole'] ?? 'ضيف').toString(),
        text: (j['text'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal() ?? DateTime.now(),
      );
}

class ClubPost {
  final String id;
  final String title;
  final String caption;
  final String category;
  final String location;
  final String mediaId;
  final String mediaType;
  final String mediaUrl;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  int likesCount;
  bool likedByMe;
  int commentsCount;
  List<PostComment> comments;
  int sharesCount;

  ClubPost({
    required this.id,
    required this.title,
    required this.caption,
    required this.category,
    required this.location,
    required this.mediaId,
    required this.mediaType,
    required this.mediaUrl,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.likesCount,
    required this.likedByMe,
    required this.commentsCount,
    required this.comments,
    required this.sharesCount,
  });

  bool get isVideo => mediaType.toLowerCase().startsWith('video/');
  bool get isImage => mediaUrl.isNotEmpty && !isVideo;
  bool get hasMedia => mediaUrl.isNotEmpty;

  factory ClubPost.fromJson(Map<String, dynamic> j) {
    final rawComments = (j['comments'] as List? ?? const [])
        .whereType<Map>()
        .map((c) => PostComment.fromJson(Map<String, dynamic>.from(c)))
        .toList();
    return ClubPost(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      caption: (j['caption'] ?? '').toString(),
      category: (j['category'] ?? 'فعالية').toString(),
      location: (j['location'] ?? '').toString(),
      mediaId: (j['mediaId'] ?? '').toString(),
      mediaType: (j['mediaType'] ?? '').toString(),
      mediaUrl: (j['mediaUrl'] ?? '').toString(),
      authorId: (j['authorId'] ?? '').toString(),
      authorName: (j['authorName'] ?? 'قائد النادي').toString(),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal() ?? DateTime.now(),
      likesCount: (j['likesCount'] as num?)?.toInt() ?? 0,
      likedByMe: j['likedByMe'] == true,
      commentsCount: (j['commentsCount'] as num?)?.toInt() ?? rawComments.length,
      comments: rawComments,
      sharesCount: (j['sharesCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class JoinRequestItem {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String branch;
  final String specialization;
  final String level;
  final String year;
  final String regNumber;
  final String motivation;
  final String photoBase64;
  String status; // pending | approved | rejected
  String leaderNote;
  final DateTime createdAt;
  final String reviewedAt;

  JoinRequestItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.branch,
    required this.specialization,
    required this.level,
    required this.year,
    required this.regNumber,
    required this.motivation,
    required this.photoBase64,
    required this.status,
    required this.leaderNote,
    required this.createdAt,
    required this.reviewedAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory JoinRequestItem.fromJson(Map<String, dynamic> j) => JoinRequestItem(
        id: (j['id'] ?? '').toString(),
        firstName: (j['firstName'] ?? '').toString(),
        lastName: (j['lastName'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        branch: (j['branch'] ?? '').toString(),
        specialization: (j['specialization'] ?? '').toString(),
        level: (j['level'] ?? '').toString(),
        year: (j['year'] ?? kAcademicYear).toString(),
        regNumber: (j['regNumber'] ?? '').toString(),
        motivation: (j['motivation'] ?? '').toString(),
        photoBase64: (j['photo'] ?? '').toString(),
        status: (j['status'] ?? 'pending').toString(),
        leaderNote: (j['leaderNote'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        reviewedAt: (j['reviewedAt'] ?? '').toString(),
      );
}

class IdeaItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final String expectedImpact;
  String status; // proposed | reviewing | approved | completed
  final String authorId;
  final String authorName;
  final String authorRole;
  int agreeCount;
  int disagreeCount;
  int totalVotes;
  int agreePercent;
  int disagreePercent;
  String myVote; // 'agree' | 'disagree' | ''
  int commentsCount;
  List<PostComment> comments;
  final bool isMine;
  final DateTime createdAt;

  IdeaItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.expectedImpact,
    required this.status,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.agreeCount,
    required this.disagreeCount,
    required this.totalVotes,
    required this.agreePercent,
    required this.disagreePercent,
    required this.myVote,
    required this.commentsCount,
    required this.comments,
    required this.isMine,
    required this.createdAt,
  });

  factory IdeaItem.fromJson(Map<String, dynamic> j) {
    final rawComments = (j['comments'] as List? ?? const [])
        .whereType<Map>()
        .map((c) => PostComment.fromJson(Map<String, dynamic>.from(c)))
        .toList();
    final agree = (j['agreeCount'] as num?)?.toInt() ?? (j['votesCount'] as num?)?.toInt() ?? 0;
    final disagree = (j['disagreeCount'] as num?)?.toInt() ?? 0;
    final total = (j['totalVotes'] as num?)?.toInt() ?? (agree + disagree);
    final aPct = (j['agreePercent'] as num?)?.toInt() ?? (total > 0 ? ((agree / total) * 100).round() : 0);
    final dPct = (j['disagreePercent'] as num?)?.toInt() ?? (total > 0 ? 100 - aPct : 0);
    return IdeaItem(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      category: (j['category'] ?? 'مشروع').toString(),
      expectedImpact: (j['expectedImpact'] ?? '').toString(),
      status: (j['status'] ?? 'proposed').toString(),
      authorId: (j['authorId'] ?? '').toString(),
      authorName: (j['authorName'] ?? 'عضو').toString(),
      authorRole: (j['authorRole'] ?? 'عضو').toString(),
      agreeCount: agree,
      disagreeCount: disagree,
      totalVotes: total,
      agreePercent: aPct,
      disagreePercent: dPct,
      myVote: (j['myVote'] ?? (j['votedByMe'] == true ? 'agree' : '')).toString(),
      commentsCount: (j['commentsCount'] as num?)?.toInt() ?? rawComments.length,
      comments: rawComments,
      isMine: j['isMine'] == true,
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal() ?? DateTime.now(),
    );
  }
}

class ClubApi {
  static const _kGuestIdKey = 'epc_guest_id_v1';
  static const _kLastJoinReqKey = 'epc_last_join_req_id';
  static const _kLastNotifiedDecisionKey = 'epc_last_notified_join_decision';

  final MemberStore store;
  ClubApi(this.store);

  Uri _uri(String path) => Uri.parse('${CloudSync.url.replaceAll(RegExp(r'/+$'), '')}$path');

  static Future<String> getOrCreateGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kGuestIdKey);
    if (id == null || id.isEmpty) {
      final rand = Random.secure();
      final bytes = List<int>.generate(12, (_) => rand.nextInt(256));
      id = base64UrlEncode(bytes).replaceAll('=', '');
      await prefs.setString(_kGuestIdKey, id);
    }
    return id;
  }

  static Future<String?> getSavedJoinRequestId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastJoinReqKey);
  }

  static Future<void> saveJoinRequestId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastJoinReqKey, id);
  }

  static Future<void> clearSavedJoinRequestId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastJoinReqKey);
    await prefs.remove(_kLastNotifiedDecisionKey);
  }

  static Future<bool> shouldNotifyDecision(String requestId, String status) async {
    if (status != 'approved' && status != 'rejected') return false;
    final prefs = await SharedPreferences.getInstance();
    final token = '$requestId:$status';
    if (prefs.getString(_kLastNotifiedDecisionKey) == token) return false;
    await prefs.setString(_kLastNotifiedDecisionKey, token);
    return true;
  }

  Future<Map<String, String>> _headers({bool includeAuth = true}) async {
    final guestId = await getOrCreateGuestId();
    final map = <String, String>{
      'x-sync-key': CloudSync.key,
      'x-guest-id': guestId,
    };
    if (includeAuth && store.sessionReg != null) {
      final reg = store.sessionReg!;
      final password = store.isLeaderSession ? store.leaderPassword : (store.currentMember?.password ?? '');
      if (password.isNotEmpty) {
        map['x-chat-auth'] = base64Encode(utf8.encode(jsonEncode({'reg': reg, 'password': password})));
      }
    }
    return map;
  }

  dynamic _parse(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = (decoded is Map && decoded['error'] != null)
          ? decoded['error'].toString()
          : 'تعذّر الاتصال بالخادم (${response.statusCode})';
      throw StateError(msg);
    }
    return decoded;
  }

  // ── 1) منشورات نشاطات النادي (Club Feed) ────────────────────────────────
  Future<List<ClubPost>> fetchPosts() async {
    if (!CloudSync.enabled) return const [];
    final res = _parse(await http
        .get(_uri('/feed/posts'), headers: await _headers())
        .timeout(const Duration(seconds: 25))) as Map;
    return (res['posts'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => ClubPost.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<({String id, String type})> uploadFeedMedia(
    Uint8List bytes,
    String mime, {
    required bool isVideo,
  }) async {
    if (!CloudSync.enabled) throw StateError('المزامنة السحابية غير مفعّلة');
    if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) {
      throw StateError('حجم الملف يتجاوز 25 ميغابايت');
    }
    final h = await _headers();
    final kind = isVideo ? 'video' : 'image';
    final res = _parse(await http
        .post(
          _uri('/feed/media?kind=$kind'),
          headers: {...h, 'content-type': mime},
          body: bytes,
        )
        .timeout(const Duration(seconds: 120))) as Map;
    return (id: res['id'].toString(), type: (res['type'] ?? mime).toString());
  }

  Future<ClubPost> createPost({
    required String title,
    required String caption,
    required String category,
    String location = '',
    String mediaId = '',
    String mediaType = '',
  }) async {
    final h = await _headers();
    final res = _parse(await http
        .post(
          _uri('/feed/posts'),
          headers: {...h, 'content-type': 'application/json'},
          body: jsonEncode({
            'title': title,
            'caption': caption,
            'category': category,
            'location': location,
            'mediaId': mediaId,
            'mediaType': mediaType,
          }),
        )
        .timeout(const Duration(seconds: 25))) as Map;
    return ClubPost.fromJson(Map<String, dynamic>.from(res['post'] as Map));
  }

  Future<void> deletePost(String postId) async {
    _parse(await http
        .delete(_uri('/feed/posts/${Uri.encodeComponent(postId)}'), headers: await _headers())
        .timeout(const Duration(seconds: 25)));
  }

  Future<({bool liked, int likesCount})> toggleLike(String postId) async {
    final res = _parse(await http
        .post(_uri('/feed/posts/${Uri.encodeComponent(postId)}/like'), headers: await _headers())
        .timeout(const Duration(seconds: 20))) as Map;
    return (
      liked: res['liked'] == true,
      likesCount: (res['likesCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<PostComment> addPostComment(String postId, String text, {String guestName = ''}) async {
    final h = await _headers();
    final res = _parse(await http
        .post(
          _uri('/feed/posts/${Uri.encodeComponent(postId)}/comments'),
          headers: {...h, 'content-type': 'application/json'},
          body: jsonEncode({'text': text, 'authorName': guestName}),
        )
        .timeout(const Duration(seconds: 20))) as Map;
    return PostComment.fromJson(Map<String, dynamic>.from(res['comment'] as Map));
  }

  Future<void> deletePostComment(String postId, String commentId) async {
    _parse(await http
        .delete(
          _uri('/feed/posts/${Uri.encodeComponent(postId)}/comments/${Uri.encodeComponent(commentId)}'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20)));
  }

  Future<int> recordShare(String postId) async {
    final res = _parse(await http
        .post(_uri('/feed/posts/${Uri.encodeComponent(postId)}/share'), headers: await _headers())
        .timeout(const Duration(seconds: 15))) as Map;
    return (res['sharesCount'] as num?)?.toInt() ?? 0;
  }

  // ── 2) طلبات الانضمام للنادي (إشعار فوري موجه، بدون بريد إلكتروني) ──────
  Future<String> submitJoinRequest({
    required String firstName,
    required String lastName,
    String email = '',
    required String phone,
    required String branch,
    required String specialization,
    required String level,
    required String year,
    required String regNumber,
    required String password,
    required String motivation,
    String photoBase64 = '',
  }) async {
    if (!CloudSync.enabled) throw StateError('المزامنة السحابية غير مفعّلة');
    final h = await _headers(includeAuth: false);
    final fcmToken = await PushNotifications.getDeviceToken();
    final res = _parse(await http
        .post(
          _uri('/join-requests'),
          headers: {...h, 'content-type': 'application/json'},
          body: jsonEncode({
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
            'phone': phone,
            'branch': branch,
            'specialization': specialization,
            'level': level,
            'year': year,
            'regNumber': regNumber,
            'password': password,
            'motivation': motivation,
            'photo': photoBase64,
            'fcmToken': fcmToken,
          }),
        )
        .timeout(const Duration(seconds: 30))) as Map;
    final id = (res['request'] as Map)['id'].toString();
    await saveJoinRequestId(id);
    return id;
  }

  Future<Map<String, dynamic>?> fetchJoinRequestStatus(String id) async {
    if (!CloudSync.enabled) return null;
    try {
      final res = await http
          .get(_uri('/join-requests/status/${Uri.encodeComponent(id)}'), headers: await _headers(includeAuth: false))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<({List<JoinRequestItem> requests, int pendingCount})> fetchJoinRequests() async {
    if (!CloudSync.enabled) return (requests: const <JoinRequestItem>[], pendingCount: 0);
    final res = _parse(await http
        .get(_uri('/join-requests'), headers: await _headers())
        .timeout(const Duration(seconds: 25))) as Map;
    final list = (res['requests'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => JoinRequestItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    return (requests: list, pendingCount: (res['pendingCount'] as num?)?.toInt() ?? 0);
  }

  Future<Map<String, dynamic>> decideJoinRequest(
    String id,
    String decision, {
    String note = '',
  }) async {
    final h = await _headers();
    final res = _parse(await http
        .post(
          _uri('/join-requests/${Uri.encodeComponent(id)}/decide'),
          headers: {...h, 'content-type': 'application/json'},
          body: jsonEncode({'decision': decision, 'note': note}),
        )
        .timeout(const Duration(seconds: 30))) as Map;
    return Map<String, dynamic>.from(res);
  }

  // ── 3) الأفكار والاستطلاعات (قبول / رفض + نسب مئوية، للأعضاء فقط) ───────
  Future<List<IdeaItem>> fetchIdeas() async {
    if (!CloudSync.enabled) return const [];
    final res = _parse(await http
        .get(_uri('/ideas'), headers: await _headers())
        .timeout(const Duration(seconds: 25))) as Map;
    return (res['ideas'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => IdeaItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<IdeaItem> createIdea({
    required String title,
    required String description,
    required String category,
    String expectedImpact = '',
  }) async {
    final h = await _headers();
    final res = _parse(await http
        .post(
          _uri('/ideas'),
          headers: {...h, 'content-type': 'application/json'},
          body: jsonEncode({
            'title': title,
            'description': description,
            'category': category,
            'expectedImpact': expectedImpact,
          }),
        )
        .timeout(const Duration(seconds: 25))) as Map;
    return IdeaItem.fromJson(Map<String, dynamic>.from(res['idea'] as Map));
  }

  Future<({
    String myVote,
    int agreeCount,
    int disagreeCount,
    int totalVotes,
    int agreePercent,
    int disagreePercent,
  })> voteIdea(String id, String choice) async {
    final h = await _headers();
    final res = _parse(await http
        .post(
          _uri('/ideas/${Uri.encodeComponent(id)}/vote'),
          headers: {...h, 'content-type': 'application/json'},
          body: jsonEncode({'choice': choice}),
        )
        .timeout(const Duration(seconds: 20))) as Map;
    return (
      myVote: (res['myVote'] ?? '').toString(),
      agreeCount: (res['agreeCount'] as num?)?.toInt() ?? 0,
      disagreeCount: (res['disagreeCount'] as num?)?.toInt() ?? 0,
      totalVotes: (res['totalVotes'] as num?)?.toInt() ?? 0,
      agreePercent: (res['agreePercent'] as num?)?.toInt() ?? 0,
      disagreePercent: (res['disagreePercent'] as num?)?.toInt() ?? 0,
    );
  }

  Future<PostComment> addIdeaComment(String ideaId, String text) async {
    final h = await _headers();
    final res = _parse(await http
        .post(
          _uri('/ideas/${Uri.encodeComponent(ideaId)}/comments'),
          headers: {...h, 'content-type': 'application/json'},
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 20))) as Map;
    return PostComment.fromJson(Map<String, dynamic>.from(res['comment'] as Map));
  }

  Future<void> updateIdeaStatus(String ideaId, String status) async {
    final h = await _headers();
    _parse(await http
        .patch(
          _uri('/ideas/${Uri.encodeComponent(ideaId)}/status'),
          headers: {...h, 'content-type': 'application/json'},
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 20)));
  }

  Future<void> deleteIdea(String ideaId) async {
    _parse(await http
        .delete(_uri('/ideas/${Uri.encodeComponent(ideaId)}'), headers: await _headers())
        .timeout(const Duration(seconds: 20)));
  }
}

/// البحث عن عضو بالمعرّف لعرض صورته واسمه في المنشورات والاستطلاعات
Member? findMemberByReg(MemberStore store, String? reg) {
  if (reg == null || reg.isEmpty) return null;
  if (reg == store.leaderReg) return store.leaderMember;
  for (final m in store.members) {
    if (m.regNumber == reg) return m;
  }
  return null;
}

/// تنسيق الوقت النسبي بالعربية
String relativeTimeAr(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} ي';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
