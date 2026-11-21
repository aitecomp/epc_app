import 'dart:convert';

import 'package:http/http.dart' as http;

import 'activity_notifier.dart';
import 'store.dart';

/// مزامنة سحابية عبر Cloudflare R2 (Worker: /members)
///
/// تُمرَّر القيم عند البناء:
///   --dart-define=SYNC_URL=https://epc-sync.<subdomain>.workers.dev
///   --dart-define=SYNC_KEY=<المفتاح>
class CloudSync {
  static const String url = String.fromEnvironment('SYNC_URL', defaultValue: '');
  static const String key = String.fromEnvironment('SYNC_KEY', defaultValue: '');

  static bool get enabled => url.isNotEmpty && key.isNotEmpty;

  static Uri get _endpoint => Uri.parse('${url.replaceAll(RegExp(r'/+$'), '')}/members');

  static DateTime? lastSync;

  /// قراءة نسخة السحابة
  static Future<Map<String, dynamic>?> pull() async {
    if (!enabled) return null;
    try {
      final response = await http
          .get(_endpoint, headers: {'x-sync-key': key})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        lastSync = DateTime.now();
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// رفع النسخة الحالية
  static Future<bool> push(MemberStore store) async {
    if (!enabled) return false;
    try {
      final response = await http
          .put(
            _endpoint,
            headers: {'x-sync-key': key, 'content-type': 'application/json'},
            body: jsonEncode(store.exportPayload()),
          )
          .timeout(const Duration(seconds: 40));
      if (response.statusCode == 200) {
        lastSync = DateTime.now();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// مزامنة كاملة: سحب ← دمج ← رفع
  static Future<bool> syncNow(MemberStore store) async {
    if (!enabled) return false;
    final remote = await pull();
    if (remote == null) return false;
    final changed = await store.applyRemotePayload(remote);
    if (changed) store.notify();
    if (store.isLeaderSession && remote['leaderProfile'] == null && store.hasCustomLeaderProfile) {
      await push(store);
    }
    await ActivityNotifier.afterSync(store);
    return true;
  }

  /// رفع في الخلفية دون إعاقة الواجهة
  static void pushInBackground(MemberStore store) {
    if (!enabled) return;
    push(store);
  }
}
