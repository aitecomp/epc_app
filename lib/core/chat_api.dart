import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'cloud_sync.dart';
import 'store.dart';

class ChatApi {
  static const int maxMediaBytes = 95 * 1024 * 1024; // 95 MB

  final MemberStore store;
  ChatApi(this.store);

  Map<String, String> get _headers {
    final reg = store.sessionReg ?? '';
    final password = store.isLeaderSession ? store.leaderPassword : (store.currentMember?.password ?? '');
    return {
      'x-sync-key': CloudSync.key,
      'x-chat-auth': base64Encode(utf8.encode(jsonEncode({'reg': reg, 'password': password}))),
    };
  }

  Uri _uri(String path) => Uri.parse('${CloudSync.url.replaceAll(RegExp(r'/+$'), '')}$path');

  dynamic _result(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('تعذّر الاتصال بالدردشة (${response.statusCode})');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<List<Map<String, dynamic>>> messages() async {
    if (!CloudSync.enabled) throw StateError('المزامنة غير مفعّلة');
    final result = _result(await http.get(_uri('/chat/messages'), headers: _headers).timeout(const Duration(seconds: 25))) as Map;
    return (result['messages'] as List).map((m) => Map<String, dynamic>.from(m as Map)).toList();
  }

  Future<String> upload(Uint8List bytes, String mime, {String kind = ''}) async {
    if (bytes.isEmpty || bytes.length > maxMediaBytes) {
      throw StateError('الملف فارغ أو يتجاوز 95 ميغابايت');
    }
    final q = kind.isNotEmpty ? '?kind=$kind' : '';
    final result = _result(await http
        .post(_uri('/chat/media$q'), headers: {..._headers, 'content-type': mime}, body: bytes)
        .timeout(const Duration(minutes: 5))) as Map;
    return result['id'] as String;
  }

  /// رفع الملفات الكبيرة بالبث المباشر دون استهلاك الذاكرة (حتى 95 ميغابايت)
  Future<String> uploadStream(
    Stream<List<int>> stream,
    int length,
    String mime, {
    String kind = '',
  }) async {
    if (length <= 0 || length > maxMediaBytes) {
      throw StateError('الملف فارغ أو يتجاوز 95 ميغابايت');
    }
    final q = kind.isNotEmpty ? '?kind=$kind' : '';
    final req = http.StreamedRequest('POST', _uri('/chat/media$q'))
      ..headers.addAll({..._headers, 'content-type': mime})
      ..contentLength = length;
    final sentFuture = req.send().timeout(const Duration(minutes: 5));
    await for (final chunk in stream) {
      req.sink.add(chunk);
    }
    await req.sink.close();
    final streamed = await sentFuture;
    final response = await http.Response.fromStream(streamed);
    final result = _result(response) as Map;
    return result['id'] as String;
  }

  Future<void> send({String text = '', String media = '', Map<String, dynamic>? reply}) async {
    _result(await http.post(_uri('/chat/messages'), headers: {..._headers, 'content-type': 'application/json'}, body: jsonEncode({
      'text': text,
      'media': media,
      'replyId': reply?['id'] ?? '',
      'replyName': reply?['authorName'] ?? '',
      'replyText': reply?['text'] ?? '',
    })).timeout(const Duration(seconds: 25)));
  }

  Future<void> deleteMessage(String id) async {
    _result(await http.delete(_uri('/chat/messages/${Uri.encodeComponent(id)}'), headers: _headers).timeout(const Duration(seconds: 25)));
  }

  Future<void> react(String id, String emoji) async {
    _result(await http.post(_uri('/chat/react'), headers: {..._headers, 'content-type': 'application/json'}, body: jsonEncode({'id': id, 'emoji': emoji})).timeout(const Duration(seconds: 25)));
  }
}
