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

/// ── نشاط / فعالية ينشرها القائد ───────────────────────────────────────
const List<String> kWeekdaysAr = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

class Activity {
  final String id;
  String title;
  String details;
  String place;
  DateTime at; // اليوم + الوقت
  DateTime createdAt;
  DateTime updatedAt;

  Activity({
    required this.id,
    required this.title,
    this.details = '',
    this.place = '',
    required this.at,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isUpcoming => at.isAfter(DateTime.now());

  String get weekdayLabel => kWeekdaysAr[(at.weekday - 1).clamp(0, 6)];

  String get dateLabel =>
      '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}/${at.year}';

  String get timeLabel =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  String get dayNumber => at.day.toString().padLeft(2, '0');

  String get monthLabel {
    const months = [
      'جانفي',
      'فيفري',
      'مارس',
      'أفريل',
      'ماي',
      'جوان',
      'جويلية',
      'أوت',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return months[(at.month - 1).clamp(0, 11)];
  }

  /// كم بقي على النشاط بصيغة مقروءة
  String get remainingLabel {
    final diff = at.difference(DateTime.now());
    if (diff.isNegative) return 'انتهى';
    if (diff.inDays > 0) return 'بعد ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'بعد ${diff.inHours} ساعة';
    if (diff.inMinutes > 0) return 'بعد ${diff.inMinutes} دقيقة';
    return 'الآن';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'details': details,
        'place': place,
        'at': at.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static Activity fromJson(Map<String, dynamic> json) => Activity(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        details: (json['details'] ?? '').toString(),
        place: (json['place'] ?? '').toString(),
        at: DateTime.tryParse((json['at'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
        updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now(),
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
  static const _kActivities = 'epc_activities_v2';
  static const _kDeletedActivities = 'epc_deleted_activities_v2';
  static const _kNotified = 'epc_notified_activities_v2';

  final List<Member> _members = [];
  final Map<String, DateTime> _deleted = {};
  final List<Activity> _activities = [];
  final Map<String, DateTime> _deletedActivities = {};

  /// النشاطات التي جُدول لها منبّه بالفعل
  final Map<String, DateTime> _notified = {};

  /// النشاطات الجديدة التي لم تُفتح بعد (لشارة الإشعار)
  final Set<String> _unseenActivities = {};

  /// النشاطات القادمة من السحابة في آخر مزامنة (لإظهار إشعار فوري)
  List<Activity> lastSyncedNewActivities = const [];
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

    // النشاطات
    final activitiesRaw = _prefs!.getString(_kActivities);
    _activities.clear();
    if (activitiesRaw != null && activitiesRaw.isNotEmpty) {
      try {
        final List data = jsonDecode(activitiesRaw) as List;
        for (final item in data) {
          _activities.add(Activity.fromJson(Map<String, dynamic>.from(item as Map)));
        }
      } catch (_) {}
    }
    _sortActivities();

    final deletedActRaw = _prefs!.getString(_kDeletedActivities);
    if (deletedActRaw != null && deletedActRaw.isNotEmpty) {
      try {
        final map = jsonDecode(deletedActRaw) as Map<String, dynamic>;
        map.forEach((k, v) {
          final at = DateTime.tryParse(v.toString());
          if (at != null) _deletedActivities[k] = at;
        });
      } catch (_) {}
    }

    final notifiedRaw = _prefs!.getString(_kNotified);
    if (notifiedRaw != null && notifiedRaw.isNotEmpty) {
      try {
        final map = jsonDecode(notifiedRaw) as Map<String, dynamic>;
        map.forEach((k, v) {
          final at = DateTime.tryParse(v.toString());
          if (at != null) _notified[k] = at;
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
      _kActivities,
      jsonEncode(_activities.map((a) => a.toJson()).toList()),
    );
    await _prefs?.setString(
      _kDeletedActivities,
      jsonEncode(_deletedActivities.map((k, v) => MapEntry(k, v.toIso8601String()))),
    );
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
        'activities': _activities.map((a) => a.toJson()).toList(),
        'deletedActivities': _deletedActivities.entries
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

    // ── النشاطات القادمة من السحابة ──
    final remoteDeletedAct = <String, DateTime>{};
    final deletedActList = payload['deletedActivities'];
    if (deletedActList is List) {
      for (final item in deletedActList) {
        if (item is Map) {
          final at = DateTime.tryParse('${item['at']}');
          if (at != null && item['id'] != null) remoteDeletedAct['${item['id']}'] = at;
        }
      }
    }
    for (final entry in remoteDeletedAct.entries) {
      final local = _deletedActivities[entry.key];
      if (local == null || entry.value.isAfter(local)) {
        _deletedActivities[entry.key] = entry.value;
        final before = _activities.length;
        _activities.removeWhere((a) => a.id == entry.key);
        if (_activities.length != before) changed = true;
      }
    }

    final newlyPublished = <Activity>[];
    final actList = payload['activities'];
    if (actList is List) {
      final now = DateTime.now();
      for (final item in actList) {
        if (item is! Map) continue;
        final incoming = Activity.fromJson(Map<String, dynamic>.from(item));
        if (incoming.id.isEmpty) continue;
        final tomb = _deletedActivities[incoming.id];
        if (tomb != null && !incoming.updatedAt.isAfter(tomb)) continue;

        final index = _activities.indexWhere((a) => a.id == incoming.id);
        if (index < 0) {
          _activities.add(incoming);
          changed = true;
          // نشاط جديد لم يُنبَّه عنه بعد
          if (!_notified.containsKey(incoming.id) && incoming.at.isAfter(now)) {
            newlyPublished.add(incoming);
          }
        } else if (incoming.updatedAt.isAfter(_activities[index].updatedAt)) {
          _activities[index] = incoming;
          changed = true;
        }
      }
      if (newlyPublished.isNotEmpty) {
        _sortActivities();
        _unseenActivities.addAll(newlyPublished.map((a) => a.id));
        lastSyncedNewActivities = newlyPublished;
      }
    }

    if (changed) {
      _members.sort((a, b) => a.fullName.compareTo(b.fullName));
      _sortActivities();
      await _persist();
    }
    return changed;
  }

  // ── عمليات النشاطات ───────────────────────────────────────────────────
  void _sortActivities() {
    _activities.sort((a, b) {
      final aUp = a.at.isAfter(DateTime.now());
      final bUp = b.at.isAfter(DateTime.now());
      if (aUp != bUp) return aUp ? -1 : 1;
      return aUp ? a.at.compareTo(b.at) : b.at.compareTo(a.at);
    });
  }

  Future<void> _saveNotified() async {
    await _prefs?.setString(
      _kNotified,
      jsonEncode(_notified.map((k, v) => MapEntry(k, v.toIso8601String()))),
    );
  }

  /// كل النشاطات (القادمة أولاً)
  List<Activity> get activities => List.unmodifiable(_activities);

  List<Activity> get upcomingActivities =>
      _activities.where((a) => a.isUpcoming).toList(growable: false);

  List<Activity> get pastActivities =>
      _activities.where((a) => !a.isUpcoming).toList(growable: false);

  int get unseenActivitiesCount => _unseenActivities.length;

  bool isActivityUnseen(String id) => _unseenActivities.contains(id);

  void markActivitiesSeen() {
    if (_unseenActivities.isEmpty) return;
    _unseenActivities.clear();
    notifyListeners();
  }

  bool isActivityNotified(String id) => _notified.containsKey(id);

  Future<void> markActivityNotified(String id) async {
    _notified[id] = DateTime.now();
    await _saveNotified();
  }

  Future<void> saveActivity(Activity activity) async {
    activity.updatedAt = DateTime.now();
    final index = _activities.indexWhere((a) => a.id == activity.id);
    if (index >= 0) {
      _activities[index] = activity;
    } else {
      _activities.add(activity);
    }
    _sortActivities();
    await _persist();
  }

  Future<void> deleteActivity(String id) async {
    _activities.removeWhere((a) => a.id == id);
    _deletedActivities[id] = DateTime.now();
    _notified.remove(id);
    _unseenActivities.remove(id);
    await _saveNotified();
    await _persist();
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
