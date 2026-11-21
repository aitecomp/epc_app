import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'cloud_sync.dart';
import 'store.dart';

class ChatApi {
  final MemberStore store;
  ChatApi(this.store);
  Map<String, String> get _headers {
    final reg = store.sessionReg ?? '';
    final password = store.isLeaderSession ? store.leaderPassword : (store.currentMember?.password ?? '');
    return {'x-sync-key': CloudSync.key, 'x-chat-auth': base64Encode(utf8.encode(jsonEncode({'reg': reg, 'password': password})))};
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
  Future<String> upload(Uint8List bytes, String mime) async {
    if (bytes.isEmpty || bytes.length > 15 * 1024 * 1024) throw StateError('الملف فارغ أو يتجاوز 15 ميغابايت');
    final result = _result(await http.post(_uri('/chat/media'), headers: {..._headers, 'content-type': mime}, body: bytes).timeout(const Duration(seconds: 90))) as Map;
    return result['id'] as String;
  }
  Future<void> send({String text = '', String media = '', Map<String, dynamic>? reply}) async {
    _result(await http.post(_uri('/chat/messages'), headers: {..._headers, 'content-type': 'application/json'}, body: jsonEncode({
      'text': text, 'media': media, 'replyId': reply?['id'] ?? '',
      'replyName': reply?['authorName'] ?? '', 'replyText': reply?['text'] ?? '',
    })).timeout(const Duration(seconds: 25)));
  }
  Future<void> react(String id, String emoji) async {
    _result(await http.post(_uri('/chat/react'), headers: {..._headers, 'content-type': 'application/json'}, body: jsonEncode({'id': id, 'emoji': emoji})).timeout(const Duration(seconds: 25)));
  }
}
