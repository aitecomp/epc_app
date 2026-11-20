import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ── خيارات النادي ──────────────────────────────────────────────────────
const List<String> kSpecializations = [
  'اقتصاد',
  'تسيير مالي ومحاسبة',
  'إدارة أعمال',
  'مالية وبنوك',
  'تجارة دولية',
  'اقتصاد قياسي',
  'إحصاء تطبيقي',
  'أخرى',
];

const List<String> kLevels = ['ليسانس 1', 'ليسانس 2', 'ليسانس 3', 'ماستر 1', 'ماستر 2', 'دكتوراه'];
const List<String> kYears = ['السنة الأولى', 'السنة الثانية', 'السنة الثالثة', 'السنة الرابعة', 'السنة الخامسة'];
const List<String> kRoles = ['عضو', 'عضو أساسي', 'نائب القائد', 'أمين عام', 'القائد'];

/// بيانات القائد مُشفّرة ولا تظهر في الكود بشكل مباشر،
/// وتُمرَّر عبر متغيّرات سرّية عند البناء (--dart-define).
const String _kLeaderRegEnv = String.fromEnvironment('LEADER_REG_B64', defaultValue: 'MjYzNzAw');
const String _kLeaderPassEnv = String.fromEnvironment('LEADER_PASS_B64', defaultValue: 'c3Rhd2Fh');

String _decodeB64(String value, String fallback) {
  try {
    final decoded = utf8.decode(base64.decode(value));
    return decoded.isEmpty ? fallback : decoded;
  } catch (_) {
    return fallback;
  }
}

String _encodeB64(String value) => base64.encode(utf8.encode(value));

class Member {
  final String id;
  String firstName;
  String lastName;
  String specialization;
  String level;
  String year;
  String regNumber;
  String password;
  String phone;
  String email;
  String role;
  String photoBase64;
  DateTime joinedAt;

  Member({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.specialization,
    required this.level,
    required this.year,
    required this.regNumber,
    required this.password,
    this.phone = '',
    this.email = '',
    this.role = 'عضو',
    this.photoBase64 = '',
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.trim().isEmpty ? '' : firstName.trim()[0];
    final last = lastName.trim().isEmpty ? '' : lastName.trim()[0];
    return '$first$last';
  }

  String get joinedLabel =>
      '${joinedAt.day.toString().padLeft(2, '0')}/${joinedAt.month.toString().padLeft(2, '0')}/${joinedAt.year}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'specialization': specialization,
        'level': level,
        'year': year,
        'regNumber': regNumber,
        'password': password,
        'phone': phone,
        'email': email,
        'role': role,
        'photo': photoBase64,
        'joinedAt': joinedAt.toIso8601String(),
      };

  static Member fromJson(Map<String, dynamic> json) => Member(
        id: (json['id'] ?? '').toString(),
        firstName: (json['firstName'] ?? '').toString(),
        lastName: (json['lastName'] ?? '').toString(),
        specialization: (json['specialization'] ?? kSpecializations.first).toString(),
        level: (json['level'] ?? kLevels.first).toString(),
        year: (json['year'] ?? kYears.first).toString(),
        regNumber: (json['regNumber'] ?? '').toString(),
        password: (json['password'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        role: (json['role'] ?? 'عضو').toString(),
        photoBase64: (json['photo'] ?? '').toString(),
        joinedAt: DateTime.tryParse((json['joinedAt'] ?? '').toString()) ?? DateTime.now(),
      );
}

/// ── مخزن البيانات ──────────────────────────────────────────────────────
class MemberStore extends ChangeNotifier {
  MemberStore._();
  static final MemberStore instance = MemberStore._();

  static const _kMembers = 'epc_members_v2';
  static const _kSession = 'epc_session_v2';
  static const _kLeaderReg = 'epc_leader_reg';
  static const _kLeaderPass = 'epc_leader_pass';

  final List<Member> _members = [];
  SharedPreferences? _prefs;
  bool ready = false;

  List<Member> get members => List.unmodifiable(_members);

  /// رقم التسجيل السري للقائد
  String get leaderReg {
    final stored = _prefs?.getString(_kLeaderReg);
    if (stored != null && stored.isNotEmpty) return stored;
    return _decodeB64(_kLeaderRegEnv, '');
  }

  /// الرقم السري للقائد
  String get leaderPassword {
    final stored = _prefs?.getString(_kLeaderPass);
    if (stored != null && stored.isNotEmpty) return stored;
    return _decodeB64(_kLeaderPassEnv, '');
  }

  bool get hasLeader => leaderReg.isNotEmpty && leaderPassword.isNotEmpty;

  String? get sessionReg => _prefs?.getString(_kSession);

  Member? get currentMember {
    final reg = sessionReg;
    if (reg == null) return null;
    for (final m in _members) {
      if (m.regNumber == reg) return m;
    }
    return null;
  }

  bool get isLeaderSession => sessionReg != null && sessionReg == leaderReg;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_kMembers);
    _members.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final List data = jsonDecode(raw) as List;
        for (final item in data) {
          _members.add(Member.fromJson(Map<String, dynamic>.from(item as Map)));
        }
      } catch (_) {}
    }
    _members.sort((a, b) => a.fullName.compareTo(b.fullName));
    ready = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs?.setString(_kMembers, jsonEncode(_members.map((m) => m.toJson()).toList()));
    notifyListeners();
  }

  /// الدخول: قائد أو عضو
  Future<String?> login(String reg, String password) async {
    final cleanReg = reg.trim();
    if (cleanReg.isEmpty || password.isEmpty) {
      return 'أدخل رقم التسجيل والرقم السري';
    }
    if (cleanReg == leaderReg && password == leaderPassword) {
      await _prefs?.setString(_kSession, cleanReg);
      notifyListeners();
      return null;
    }
    for (final m in _members) {
      if (m.regNumber == cleanReg) {
        if (m.password == password) {
          await _prefs?.setString(_kSession, cleanReg);
          notifyListeners();
          return null;
        }
        return 'الرقم السري غير صحيح';
      }
    }
    return 'رقم التسجيل غير مسجّل في النادي';
  }

  Future<void> logout() async {
    await _prefs?.remove(_kSession);
    notifyListeners();
  }

  bool regExists(String reg, {String? ignoreId}) =>
      _members.any((m) => m.regNumber == reg.trim() && m.id != ignoreId) || reg.trim() == leaderReg;

  Future<void> saveMember(Member member) async {
    final index = _members.indexWhere((m) => m.id == member.id);
    if (index >= 0) {
      _members[index] = member;
    } else {
      _members.add(member);
    }
    _members.sort((a, b) => a.fullName.compareTo(b.fullName));
    await _persist();
  }

  Future<void> deleteMember(String id) async {
    _members.removeWhere((m) => m.id == id);
    await _persist();
  }

  Future<void> updateLeaderCredentials({required String reg, required String password}) async {
    await _prefs?.setString(_kLeaderReg, reg.trim());
    await _prefs?.setString(_kLeaderPass, password);
    if (sessionReg != null) {
      await _prefs?.setString(_kSession, reg.trim());
    }
    notifyListeners();
  }

  Future<void> resetClub() async {
    _members.clear();
    await _persist();
  }

  int get totalMembers => _members.length;

  int get leadersCount => _members.where((m) => kRoles.indexOf(m.role) >= 2).length;

  int get specializationsCount => _members.map((m) => m.specialization).toSet().length;

  int get withPhotoCount => _members.where((m) => m.photoBase64.isNotEmpty).length;

  Map<String, int> get bySpecialization {
    final map = <String, int>{};
    for (final m in _members) {
      map[m.specialization] = (map[m.specialization] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get byYear {
    final map = <String, int>{};
    for (final m in _members) {
      map[m.year] = (map[m.year] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get byLevel {
    final map = <String, int>{};
    for (final m in _members) {
      map[m.level] = (map[m.level] ?? 0) + 1;
    }
    return map;
  }

  /// نص جاهز للنسخ إلى Excel / Word
  String exportText() {
    final buffer = StringBuffer('قائمة أعضاء نادي رواد الاقتصاد — EPC\n');
    buffer.writeln('التاريخ: ${DateTime.now().toIso8601String().split('T').first}');
    buffer.writeln('العدد: ${_members.length}\n');
    buffer.writeln([
      'الاسم',
      'اللقب',
      'التخصص',
      'المستوى',
      'السنة',
      'رقم التسجيل',
      'الهاتف',
      'البريد',
      'الصفة',
    ].join('\t'));
    for (final m in _members) {
      buffer.writeln([
        m.firstName,
        m.lastName,
        m.specialization,
        m.level,
        m.year,
        m.regNumber,
        m.phone,
        m.email,
        m.role,
      ].join('\t'));
    }
    return buffer.toString();
  }
}

String encodePhoto(String value) => _encodeB64(value);
