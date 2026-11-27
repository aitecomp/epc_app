import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../screens/chat_member_profile.dart';

/// نص ذكي يدعم الروابط (https/www) والهاشتاغات (#) والمنشن (@) والبريد والهاتف
class RichSmartText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final MemberStore? store;
  final bool allowProfileNavigation;
  final ValueChanged<String>? onHashtagTap;
  final int? maxLines;
  final TextOverflow? overflow;

  const RichSmartText(
    this.text, {
    super.key,
    this.style,
    this.store,
    this.allowProfileNavigation = true,
    this.onHashtagTap,
    this.maxLines,
    this.overflow,
  });

  @override
  State<RichSmartText> createState() => _RichSmartTextState();
}

class _RichSmartTextState extends State<RichSmartText> {
  final List<TapGestureRecognizer> _recognizers = [];

  static final RegExp _tokenRegex = RegExp(
    r'((?:https?:\/\/|www\.)[^\s<>()]+)'
    r'|([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})'
    r'|(#[a-zA-Z0-9_\u0600-\u06FF]+)'
    r'|(@[a-zA-Z0-9_.\u0600-\u06FF]+)'
    r'|((?:\+?213|0)[567]\d{8})',
    unicode: true,
  );

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _makeTap(VoidCallback onTap) {
    final r = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(r);
    return r;
  }

  Future<void> _openUrl(String raw) async {
    final normalized = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      await Clipboard.setData(ClipboardData(text: normalized));
      if (mounted) toast(context, 'تم نسخ الرابط');
    }
  }

  Future<void> _openEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _handleMention(String token) {
    final query = token.substring(1).replaceAll('_', ' ').trim().toLowerCase();
    final store = widget.store ?? MemberStore.instance;
    if (!widget.allowProfileNavigation || store.sessionReg == null) {
      toast(context, 'المنشن: $token');
      return;
    }

    Member? found;
    final leader = store.leaderMember;
    if (leader.regNumber.toLowerCase() == query ||
        leader.fullName.toLowerCase().contains(query) ||
        leader.firstName.toLowerCase() == query ||
        query == 'القائد') {
      found = leader;
    } else {
      for (final m in store.members) {
        if (m.regNumber.toLowerCase() == query ||
            m.fullName.toLowerCase() == query ||
            m.firstName.toLowerCase() == query ||
            m.fullName.toLowerCase().contains(query)) {
          found = m;
          break;
        }
      }
    }

    if (found != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatMemberProfile(member: found!)),
      );
    } else {
      toast(context, 'لم يتم العثور على العضو $token');
    }
  }

  void _handleHashtag(String tag) {
    if (widget.onHashtagTap != null) {
      widget.onHashtagTap!(tag);
      return;
    }
    Clipboard.setData(ClipboardData(text: tag));
    toast(context, 'تم نسخ الهاشتاغ $tag');
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final text = widget.text;
    final spans = <InlineSpan>[];
    var last = 0;

    for (final match in _tokenRegex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final token = match.group(0)!;
      if (match.group(1) != null) {
        // رابط URL
        spans.add(TextSpan(
          text: token,
          style: baseStyle.copyWith(
            color: const Color(0xFF1D4ED8),
            decoration: TextDecoration.underline,
            decorationColor: const Color(0xFF1D4ED8),
            fontWeight: FontWeight.w700,
          ),
          recognizer: _makeTap(() => _openUrl(token)),
        ));
      } else if (match.group(2) != null) {
        // بريد إلكتروني
        spans.add(TextSpan(
          text: token,
          style: baseStyle.copyWith(
            color: const Color(0xFF0E7490),
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w700,
          ),
          recognizer: _makeTap(() => _openEmail(token)),
        ));
      } else if (match.group(3) != null) {
        // هاشتاغ #
        spans.add(TextSpan(
          text: token,
          style: baseStyle.copyWith(
            color: AppColors.purple,
            fontWeight: FontWeight.w800,
          ),
          recognizer: _makeTap(() => _handleHashtag(token)),
        ));
      } else if (match.group(4) != null) {
        // منشن @
        spans.add(TextSpan(
          text: token,
          style: baseStyle.copyWith(
            color: const Color(0xFF9A6B22),
            fontWeight: FontWeight.w800,
          ),
          recognizer: _makeTap(() => _handleMention(token)),
        ));
      } else if (match.group(5) != null) {
        // رقم هاتف
        spans.add(TextSpan(
          text: token,
          style: baseStyle.copyWith(
            color: const Color(0xFF15803D),
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w700,
          ),
          recognizer: _makeTap(() => _openPhone(token)),
        ));
      }
      last = match.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}

/// استخراج اقتراحات المنشن (@) أثناء الكتابة في الدردشة
List<Member> matchMentionCandidates(MemberStore store, String text, int cursorOffset) {
  if (cursorOffset < 0 || cursorOffset > text.length) return const [];
  final before = text.substring(0, cursorOffset);
  final match = RegExp(r'(?:^|\s)@([a-zA-Z0-9_.\u0600-\u06FF]*)$', unicode: true).firstMatch(before);
  if (match == null) return const [];
  final q = (match.group(1) ?? '').replaceAll('_', ' ').trim().toLowerCase();
  final all = <Member>[store.leaderMember, ...store.members];
  return all.where((m) {
    if (q.isEmpty) return true;
    return m.fullName.toLowerCase().contains(q) || m.regNumber.toLowerCase().contains(q);
  }).take(6).toList();
}

/// إدراج منشن عضو مكان النص بعد علامة @
void insertMemberMention(TextEditingController ctrl, Member member) {
  final text = ctrl.text;
  final sel = ctrl.selection.baseOffset.clamp(0, text.length);
  final before = text.substring(0, sel);
  final after = text.substring(sel);
  final match = RegExp(r'(?:^|\s)(@[a-zA-Z0-9_.\u0600-\u06FF]*)$', unicode: true).firstMatch(before);
  if (match == null) return;
  final tokenStart = before.length - match.group(1)!.length;
  final handle = '@${member.fullName.trim().replaceAll(RegExp(r'\s+'), '_')} ';
  final nextText = text.substring(0, tokenStart) + handle + after;
  ctrl.value = TextEditingValue(
    text: nextText,
    selection: TextSelection.collapsed(offset: tokenStart + handle.length),
  );
}
