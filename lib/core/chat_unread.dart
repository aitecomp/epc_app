import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatUnread {
  static final ValueNotifier<int> count = ValueNotifier<int>(0);
  static final ValueNotifier<int> openRequested = ValueNotifier<int>(0);
  static Future<void> update(List<Map<String, dynamic>> messages, String? reg, {required bool active}) async {
    if (reg == null || reg.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'epc_chat_read_$reg';
    final lastRead = prefs.getString(key) ?? '';
    if (active) {
      if (messages.isNotEmpty) await prefs.setString(key, messages.last['id'].toString());
      count.value = 0;
    } else {
      count.value = messages.where((m) => (m['id']?.toString() ?? '').compareTo(lastRead) > 0 && m['authorId'] != reg).length;
    }
  }
}
