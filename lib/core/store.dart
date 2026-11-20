import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ── خيارات النادي ──────────────────────────────────────────────────────
/// التخصصات مبنية على كليات وأقسام جامعة غيليزان (أحمد زبانة)

const String kAcademicYear = '2026/2027';
const List<String> kAcademicYears = ['2026/2027', '2025/2026'];

const String kCommonTrunk = 'جذع مشترك';
const String kCommonTrunkProgram = 'جذع مشترك — علوم اقتصادية وتجارية وعلوم التسيير';
const String kOtherFaculty = 'أخرى';

/// الكلية → قائمة التخصصات
const Map<String, List<String>> kFaculties = {
  'كلية العلوم الاقتصادية والتجارية وعلوم التسيير': [
    kCommonTrunkProgram,
    'اقتصاد وتسيير المؤسسات',
    'اقتصاد نقدي وبنكي',
    'اقتصاد دولي',
    'اقتصاد كمي',
    'اقتصاد رقمي',
    'تسويق',
    'مالية وتجارة دولية',
    'علوم تجارية',
    'تجارة إلكترونية',
    'إدارة أعمال',
    'إدارة مالية',
    'إدارة الموارد البشرية',
    'إدارة إلكترونية',
    'تسيير عمومي',
    'محاسبة',
    'مالية',
    'مالية المؤسسة',
    'مالية وبنوك',
    'محاسبة وتدقيق',
    'محاسبة وجباية',
    'تكنولوجيا مالية',
  ],
  'كلية العلوم والتكنولوجيا': [
    'جذع مشترك — علوم وتكنولوجيا',
    'رياضيات',
    'إعلام آلي',
    'فيزياء',
    'كيمياء',
    'علوم فلاحية',
    'هندسة مدنية',
    'هندسة إلكترونية',
    'هندسة ميكانيكية',
    'هندسة الطرائق',
    'أمن معلوماتي',
  ],
  'كلية علوم الطبيعة والحياة': [
    'جذع مشترك — علوم الطبيعة والحياة',
    'علوم بيولوجية',
    'بيوتكنولوجيا',
    'علوم بيئية',
    'إنتاج نباتي',
    'إنتاج حيواني',
    'تكنولوجيا الغذاء ومراقبة النوعية',
  ],
  'كلية الحقوق': [
    'حقوق',
    'قانون عام',
    'قانون خاص',
    'قانون أعمال',
    'قانون إداري',
  ],
  'كلية الآداب واللغات': [
    'لغة عربية وآدابها',
    'لغة فرنسية',
    'لغة إنجليزية',
    'ترجمة',
    'لسانيات',
  ],
  'كلية العلوم الاجتماعية والإنسانية': [
    'علم الاجتماع',
    'علم النفس',
    'علوم الإعلام والاتصال',
    'التاريخ',
    'جغرافيا',
    'علوم إسلامية',
    'علوم التربية',
    'علم اجتماع الترفيه والأسفار',
    'تاريخ المغرب العربي الحديث',
    'علم نفس العمل والتنظيم وتسيير الموارد البشرية',
  ],
  kOtherFaculty: ['تخصص آخر'],
};

/// توافق مع الشيفرة السابقة
const Map<String, List<String>> kPrograms = kFaculties;

List<String> get kBranches => kFaculties.keys.toList();

List<String> get kSpecializations =>
    kFaculties.values.expand((e) => e).toList(growable: false);

String branchOfProgram(String program) {
  for (final entry in kFaculties.entries) {
    if (entry.value.contains(program)) return entry.key;
  }
  return kOtherFaculty;
}

/// بحث سريع في كل التخصصات
List<MapEntry<String, String>> searchPrograms(String query) {
  final q = query.trim();
  final results = <MapEntry<String, String>>[];
  for (final entry in kFaculties.entries) {
    for (final program in entry.value) {
      if (q.isEmpty ||
          program.contains(q) ||
          entry.key.contains(q) ||
          program.toLowerCase().contains(q.toLowerCase())) {
        results.add(MapEntry(entry.key, program));
      }
    }
  }
  return results;
}

/// المستويات الدراسية (نظام ل.م.د)
const List<String> kLevels = [
  'السنة الأولى (L1)',
  'السنة الثانية (L2)',
  'السنة الثالثة (L3)',
  'ماستر 1 (M1)',
  'ماستر 2 (M2)',
  'دكتوراه',
];

const List<String> kLevelShort = ['L1', 'L2', 'L3', 'M1', 'M2', 'دكتوراه'];

const List<String> kYears = kAcademicYears;

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
  String branch;
  String level;
  String year;
  String regNumber;
  String password;
  String phone;
  String email;
  String role;
  String photoBase64;
  DateTime joinedAt;
  DateTime updatedAt;

  Member({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.specialization,
    String? branch,
    required this.level,
    required this.year,
    required this.regNumber,
    required this.password,
    this.phone = '',
    this.email = '',
    this.role = 'عضو',
    this.photoBase64 = '',
    DateTime? joinedAt,
    DateTime? updatedAt,
  })  : branch = branch ?? branchOfProgram(specialization),
        joinedAt = joinedAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.trim().isEmpty ? '' : firstName.trim()[0];
    final last = lastName.trim().isEmpty ? '' : lastName.trim()[0];
    return '$first$last';
  }

  /// التخصص بصيغة قصيرة مناسبة للبطاقة
  String get displaySpecialization {
    if (branch == kCommonTrunk || specialization == kCommonTrunkProgram) {
      return 'جذع مشترك';
    }
    return specialization;
  }

  String get joinedLabel =>
      '${joinedAt.day.toString().padLeft(2, '0')}/${joinedAt.month.toString().padLeft(2, '0')}/${joinedAt.year}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'specialization': specialization,
        'branch': branch,
        'level': level,
        'year': year,
        'regNumber': regNumber,
        'password': password,
        'phone': phone,
        'email': email,
        'role': role,
        'photo': photoBase64,
        'joinedAt': joinedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static Member fromJson(Map<String, dynamic> json) => Member(
        id: (json['id'] ?? '').toString(),
        firstName: (json['firstName'] ?? '').toString(),
        lastName: (json['lastName'] ?? '').toString(),
        specialization: (json['specialization'] ?? kCommonTrunkProgram).toString(),
        branch: (json['branch'] ?? '').toString().isEmpty
            ? branchOfProgram((json['specialization'] ?? kCommonTrunkProgram).toString())
            : (json['branch'] ?? '').toString(),
        level: (json['level'] ?? kLevels.first).toString(),
        year: (json['year'] ?? kAcademicYear).toString(),
        regNumber: (json['regNumber'] ?? '').toString(),
        password: (json['password'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        role: (json['role'] ?? 'عضو').toString(),
        photoBase64: (json['photo'] ?? '').toString(),
        joinedAt: DateTime.tryParse((json['joinedAt'] ?? '').toString()) ?? DateTime.now(),
        updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
            DateTime.tryParse((json['joinedAt'] ?? '').toString()) ??
            DateTime.now(),
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
  static const _kDeleted = 'epc_deleted_v2';
  static const _kLeaderProfile = 'epc_leader_profile';

  final List<Member> _members = [];
  final Map<String, DateTime> _deleted = {};
  Member? _leaderProfile;
  SharedPreferences? _prefs;
  bool ready = false;

  void notify() => notifyListeners();

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
    final leaderRaw = _prefs!.getString(_kLeaderProfile);
    if (leaderRaw != null && leaderRaw.isNotEmpty) {
      try {
        _leaderProfile = Member.fromJson(
          Map<String, dynamic>.from(jsonDecode(leaderRaw) as Map),
        );
      } catch (_) {}
    }

    _migrateMembers();
    _members.sort((a, b) => a.fullName.compareTo(b.fullName));

    final deletedRaw = _prefs!.getString(_kDeleted);
    if (deletedRaw != null && deletedRaw.isNotEmpty) {
      try {
        final map = jsonDecode(deletedRaw) as Map<String, dynamic>;
        map.forEach((k, v) {
          final at = DateTime.tryParse(v.toString());
          if (at != null) _deleted[k] = at;
        });
      } catch (_) {}
    }

    ready = true;
    notifyListeners();
  }

  /// ترقية البيانات القديمة إلى السنة الجامعية الجديدة والمصطلحات الجديدة
  void _migrateMembers() {
    for (final m in _members) {
      if (!m.year.contains('/')) {
        m.year = kAcademicYear;
      }
      if (m.branch.isEmpty) {
        m.branch = branchOfProgram(m.specialization);
      }
      if (!kLevels.contains(m.level)) {
        final old = m.level;
        if (old.contains('ليسانس 1') || old.contains('ليسانس1')) {
          m.level = kLevels[0];
        } else if (old.contains('ليسانس 2')) {
          m.level = kLevels[1];
        } else if (old.contains('ليسانس 3')) {
          m.level = kLevels[2];
        } else if (old.contains('ماستر 1')) {
          m.level = kLevels[3];
        } else if (old.contains('ماستر 2')) {
          m.level = kLevels[4];
        } else if (old.contains('دكتور')) {
          m.level = kLevels[5];
        } else {
          m.level = kLevels.first;
        }
      }
      if (!kSpecializations.contains(m.specialization)) {
        m.specialization = kCommonTrunkProgram;
        m.branch = kCommonTrunk;
      }
    }
  }

  Future<void> _persist() async {
    await _prefs?.setString(_kMembers, jsonEncode(_members.map((m) => m.toJson()).toList()));
    await _prefs?.setString(
      _kDeleted,
      jsonEncode(_deleted.map((k, v) => MapEntry(k, v.toIso8601String()))),
    );
    notifyListeners();
  }

  /// حزمة المزامنة الكاملة (الأعضاء + المحذوفون)
  Map<String, dynamic> exportPayload() => {
        'members': _members.map((m) => m.toJson()).toList(),
        'deleted': _deleted.entries
            .map((e) => {'id': e.key, 'at': e.value.toIso8601String()})
            .toList(),
      };

  /// دمج نسخة السحابة مع النسخة المحلية (الأحدث يفوز)
  Future<bool> applyRemotePayload(Map<String, dynamic> payload) async {
    bool changed = false;

    final remoteDeleted = <String, DateTime>{};
    final deletedList = payload['deleted'];
    if (deletedList is List) {
      for (final item in deletedList) {
        if (item is Map) {
          final at = DateTime.tryParse('${item['at']}');
          if (at != null && item['id'] != null) remoteDeleted['${item['id']}'] = at;
        }
      }
    }

    // حذف ما حُذف في السحابة
    for (final entry in remoteDeleted.entries) {
      final local = _deleted[entry.key];
      if (local == null || entry.value.isAfter(local)) {
        _deleted[entry.key] = entry.value;
        final before = _members.length;
        _members.removeWhere((m) =>
            m.id == entry.key &&
            !m.updatedAt.isAfter(entry.value));
        if (_members.length != before) changed = true;
      }
    }

    // إضافة / تحديث الأعضاء
    final list = payload['members'];
    if (list is List) {
      for (final item in list) {
        if (item is! Map) continue;
        final incoming = Member.fromJson(Map<String, dynamic>.from(item));
        if (incoming.id.isEmpty) continue;
        final tomb = _deleted[incoming.id];
        if (tomb != null && !incoming.updatedAt.isAfter(tomb)) continue;

        final index = _members.indexWhere((m) => m.id == incoming.id);
        if (index < 0) {
          _members.add(incoming);
          changed = true;
        } else if (incoming.updatedAt.isAfter(_members[index].updatedAt)) {
          _members[index] = incoming;
          changed = true;
        }
      }
    }

    if (changed) {
      _members.sort((a, b) => a.fullName.compareTo(b.fullName));
      await _persist();
    }
    return changed;
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
    member.updatedAt = DateTime.now();
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
    _deleted[id] = DateTime.now();
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

  /// بطاقة القائد (تُعرض في تبويب البروفيل)
  Member get leaderMember {
    final base = _leaderProfile;
    if (base != null) {
      base.regNumber = leaderReg;
      base.role = 'القائد';
      return base;
    }
    return Member(
      id: 'leader',
      firstName: 'قائد',
      lastName: 'النادي',
      specialization: 'إدارة أعمال',
      branch: 'كلية العلوم الاقتصادية والتجارية وعلوم التسيير',
      level: kLevels[2],
      year: kAcademicYear,
      regNumber: leaderReg,
      password: '',
      role: 'القائد',
    );
  }

  Future<void> saveLeaderProfile(Member member) async {
    member.updatedAt = DateTime.now();
    _leaderProfile = member;
    await _prefs?.setString(_kLeaderProfile, jsonEncode(member.toJson()));
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
      map[m.displaySpecialization] = (map[m.displaySpecialization] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get byBranch {
    final map = <String, int>{};
    for (final m in _members) {
      map[m.branch] = (map[m.branch] ?? 0) + 1;
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
