// نادي رواد الاقتصاد — Economics Pioneers Club (EPC)
// تطبيق Flutter: تسجيل دخول برقم التسجيل + الرقم السري، بطاقة عضو قابلة للقلب،
// ولوحة تحكم شاملة للقائد لإضافة/تعديل/حذف الأعضاء.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ───────────────────────── الألوان ─────────────────────────
const Color kPurpleDark = Color(0xFF2E1065);
const Color kPurple = Color(0xFF4C1D95);
const Color kPurpleLight = Color(0xFF7C3AED);
const Color kLavender = Color(0xFFEDE9FE);
const Color kGold = Color(0xFFC9A227);
const Color kNavy = Color(0xFF0F2040);

// ───────────────────────── نموذج العضو ─────────────────────────
class Member {
  String id;
  String firstName; // الاسم
  String lastName; // اللقب
  String specialization; // التخصص
  String level; // المستوى الدراسي
  String year; // السنة الدراسية
  String regNumber; // رقم التسجيل
  String password; // الرقم السري
  String phone;
  String email;
  String photoBase64; // الصورة بصيغة base64 (اختياري)
  bool isLeader;
  String joinDate;

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
    this.photoBase64 = '',
    this.isLeader = false,
    this.joinDate = '',
  });

  String get fullName => '$firstName $lastName';

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
        'photoBase64': photoBase64,
        'isLeader': isLeader,
        'joinDate': joinDate,
      };

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: j['id'] ?? '',
        firstName: j['firstName'] ?? '',
        lastName: j['lastName'] ?? '',
        specialization: j['specialization'] ?? '',
        level: j['level'] ?? '',
        year: j['year'] ?? '',
        regNumber: j['regNumber'] ?? '',
        password: j['password'] ?? '',
        phone: j['phone'] ?? '',
        email: j['email'] ?? '',
        photoBase64: j['photoBase64'] ?? '',
        isLeader: j['isLeader'] ?? false,
        joinDate: j['joinDate'] ?? '',
      );

  Member copyWith({
    String? firstName,
    String? lastName,
    String? specialization,
    String? level,
    String? year,
    String? regNumber,
    String? password,
    String? phone,
    String? email,
    String? photoBase64,
    bool? isLeader,
  }) =>
      Member(
        id: id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        specialization: specialization ?? this.specialization,
        level: level ?? this.level,
        year: year ?? this.year,
        regNumber: regNumber ?? this.regNumber,
        password: password ?? this.password,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        photoBase64: photoBase64 ?? this.photoBase64,
        isLeader: isLeader ?? this.isLeader,
        joinDate: joinDate,
      );
}

const List<String> kSpecializations = [
  'اقتصاد',
  'تسيير مالي ومحاسبة',
  'إدارة أعمال',
  'مالية وبنوك',
  'تجارة دولية',
  'اقتصاد قياسي',
  'أخرى',
];
const List<String> kLevels = ['L1', 'L2', 'L3', 'M1', 'M2', 'دكتوراه'];
const List<String> kYears = [
  'السنة الأولى',
  'السنة الثانية',
  'السنة الثالثة',
  'السنة الرابعة',
  'السنة الخامسة',
];

// ───────────────────────── التخزين المحلي ─────────────────────────
class MemberStore extends ChangeNotifier {
  List<Member> members = [];
  bool loaded = false;
  static const _key = 'epc_members_v1';
  static const _sessionKey = 'epc_session_reg';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      members = _seed();
      await _save(prefs);
    } else {
      final list = jsonDecode(raw) as List;
      members = list.map((e) => Member.fromJson(e)).toList();
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(members.map((m) => m.toJson()).toList()));
  }

  List<Member> _seed() => [
        Member(
          id: 'leader',
          firstName: 'القائد',
          lastName: 'العام',
          specialization: 'اقتصاد',
          level: 'M2',
          year: 'السنة الخامسة',
          regNumber: '000000',
          password: 'admin123',
          phone: '0550000000',
          email: 'leader@epc.club',
          isLeader: true,
          joinDate: '2024-09-01',
        ),
        Member(
          id: 'm1',
          firstName: 'أحمد',
          lastName: 'بن يوسف',
          specialization: 'اقتصاد',
          level: 'L1',
          year: 'السنة الأولى',
          regNumber: '20240001',
          password: '123456',
          phone: '0661000001',
          email: 'ahmed@univ.dz',
          joinDate: '2024-09-15',
        ),
        Member(
          id: 'm2',
          firstName: 'فاطمة',
          lastName: 'الزهراء',
          specialization: 'تسيير مالي ومحاسبة',
          level: 'L2',
          year: 'السنة الثانية',
          regNumber: '20240002',
          password: '123456',
          phone: '0661000002',
          email: 'fatima@univ.dz',
          joinDate: '2024-09-15',
        ),
        Member(
          id: 'm3',
          firstName: 'محمد',
          lastName: 'الأمين',
          specialization: 'إدارة أعمال',
          level: 'L3',
          year: 'السنة الثالثة',
          regNumber: '20240003',
          password: '123456',
          phone: '0661000003',
          email: 'amine@univ.dz',
          joinDate: '2024-10-01',
        ),
      ];

  Member? findByCredentials(String reg, String pass) {
    for (final m in members) {
      if (m.regNumber.trim() == reg.trim() && m.password == pass) return m;
    }
    return null;
  }

  Future<void> add(Member m) async {
    members.add(m);
    await _save();
    notifyListeners();
  }

  Future<void> update(Member m) async {
    final i = members.indexWhere((e) => e.id == m.id);
    if (i >= 0) members[i] = m;
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    members.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> saveSession(String reg) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_sessionKey, reg);
  }

  Future<String?> sessionReg() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_sessionKey);
  }

  Future<void> clearSession() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_sessionKey);
  }
}

// ───────────────────────── التطبيق ─────────────────────────
void main() {
  runApp(const EpcApp());
}

class EpcApp extends StatefulWidget {
  const EpcApp({super.key});
  @override
  State<EpcApp> createState() => _EpcAppState();
}

class _EpcAppState extends State<EpcApp> {
  final store = MemberStore();

  @override
  void initState() {
    super.initState();
    store.load().then((_) async {
      final reg = await store.sessionReg();
      if (reg != null && mounted) {
        final m = store.members.where((e) => e.regNumber == reg).firstOrNull;
        if (m != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => m.isLeader ? AdminDashboard(store: store, leader: m) : ProfileScreen(store: store, member: m)),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EPC — نادي رواد الاقتصاد',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kPurple, primary: kPurple),
        scaffoldBackgroundColor: const Color(0xFFF5F3FF),
        appBarTheme: const AppBarTheme(backgroundColor: kPurpleDark, foregroundColor: Colors.white),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(backgroundColor: kPurple, foregroundColor: Colors.white),
        ),
      ),
      home: AnimatedBuilder(
        animation: store,
        builder: (_, __) => store.loaded
            ? LoginScreen(store: store)
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    );
  }
}

// ───────────────────────── شاشة تسجيل الدخول ─────────────────────────
class LoginScreen extends StatefulWidget {
  final MemberStore store;
  const LoginScreen({super.key, required this.store});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _reg = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  String? _error;

  void _login() {
    final m = widget.store.findByCredentials(_reg.text, _pass.text);
    if (m == null) {
      setState(() => _error = 'رقم التسجيل أو الرقم السري غير صحيح. تأكد من المعلومات وحاول مجدداً.');
      return;
    }
    widget.store.saveSession(m.regNumber);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => m.isLeader ? AdminDashboard(store: widget.store, leader: m) : ProfileScreen(store: widget.store, member: m)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // البانر
            Container(
              width: double.infinity,
              color: Colors.black,
              child: Image.asset('assets/images/banner.png', fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.white,
                    child: ClipOval(child: Image.asset('assets/images/logo.png', width: 96, height: 96, fit: BoxFit.cover)),
                  ),
                  const SizedBox(height: 12),
                  const Text('نادي رواد الاقتصاد', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kPurpleDark)),
                  const Text('Economics Pioneers Club — EPC', style: TextStyle(fontSize: 15, color: kPurple)),
                  const Text('Learn • Innovate • Lead • Succeed', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 28),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(children: [
                            Icon(Icons.login, color: kPurple),
                            SizedBox(width: 8),
                            Text('تسجيل الدخول', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _reg,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'رقم التسجيل',
                              prefixIcon: Icon(Icons.badge),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _pass,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'الرقم السري',
                              prefixIcon: const Icon(Icons.lock),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            onSubmitted: (_) => _login(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _login,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('دخول إلى بروفايلي', style: TextStyle(fontSize: 17)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: kLavender, borderRadius: BorderRadius.circular(14)),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('حسابات تجريبية (غيّرها القائد من لوحة التحكم):', style: TextStyle(fontWeight: FontWeight.bold, color: kPurpleDark)),
                        SizedBox(height: 6),
                        Text('• القائد:  رقم التسجيل 000000 — الرقم السري admin123'),
                        Text('• عضو تجريبي:  رقم التسجيل 20240001 — الرقم السري 123456'),
                        Text('• عضو تجريبي:  رقم التسجيل 20240002 — الرقم السري 123456'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('© 2026 نادي رواد الاقتصاد — جميع الحقوق محفوظة', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── بطاقة العضو القابلة للقلب ─────────────────────────
class FlipMemberCard extends StatefulWidget {
  final Member member;
  const FlipMemberCard({super.key, required this.member});
  @override
  State<FlipMemberCard> createState() => _FlipMemberCardState();
}

class _FlipMemberCardState extends State<FlipMemberCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _front = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  void _flip() {
    if (_front) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
    setState(() => _front = !_front);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final angle = _anim.value * math.pi;
          final showFront = angle <= math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: showFront ? _frontFace() : Transform(transform: Matrix4.rotationY(math.pi), alignment: Alignment.center, child: _backFace()),
          );
        },
      ),
    );
  }

  Widget _photo(double size) {
    if (widget.member.photoBase64.isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(base64Decode(widget.member.photoBase64), width: size, height: size, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: kLavender, borderRadius: BorderRadius.circular(16), border: Border.all(color: kPurple, width: 2)),
      child: Icon(Icons.person, size: size * 0.55, color: kPurple),
    );
  }

  Widget _field(String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: kPurpleDark, borderRadius: BorderRadius.circular(20)),
          child: Text('$label:', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20), border: Border.all(color: kPurple)),
            child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 13, color: kPurpleDark), overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }

  Widget _frontFace() {
    final m = widget.member;
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [kPurpleDark, kPurple, kPurpleLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: ClipOval(child: Image.asset('assets/images/logo.png', width: 48, height: 48, fit: BoxFit.cover)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('نادي رواد الاقتصاد', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                    Text('Economics Pioneers Club', style: TextStyle(color: Color(0xFFDDD6FE), fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.touch_app, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _photo(105),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _field('الاسم', m.firstName),
                        _field('اللقب', m.lastName),
                        _field('التخصص', m.specialization),
                        _field('المستوى الدراسي', m.level),
                        _field('السنة الدراسية', m.year),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.credit_card, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('بطاقة عضو', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(width: 8),
              Text('Member Card', style: TextStyle(color: Color(0xFFDDD6FE), fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _backFace() {
    final m = widget.member;
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), kPurpleDark], begin: Alignment.topRight, end: Alignment.bottomLeft),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info, color: kGold),
            SizedBox(width: 8),
            Text('معلومات العضو', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          _backRow(Icons.badge, 'رقم التسجيل', m.regNumber),
          _backRow(Icons.school, 'التخصص', m.specialization),
          _backRow(Icons.phone, 'الهاتف', m.phone),
          _backRow(Icons.email, 'البريد الإلكتروني', m.email),
          _backRow(Icons.calendar_month, 'تاريخ الانضمام', m.joinDate),
          _backRow(Icons.star, 'الصفة', m.isLeader ? 'قائد النادي' : 'عضو'),
          const Spacer(),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Learn • Innovate • Lead • Succeed', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('اضغط للقلب ↺', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _backRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, color: kGold, size: 18),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Color(0xFFDDD6FE), fontSize: 13)),
        Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

// ───────────────────────── شاشة البروفايل ─────────────────────────
class ProfileScreen extends StatelessWidget {
  final MemberStore store;
  final Member member;
  const ProfileScreen({super.key, required this.store, required this.member});

  Future<void> _pickPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    await store.update(member.copyWith(photoBase64: base64Encode(bytes)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الصورة بنجاح')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بروفايلي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await store.clearSession();
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen(store: store)));
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (_, __) {
          final m = store.members.firstWhere((e) => e.id == member.id, orElse: () => member);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('مرحباً، ${m.fullName} 👋', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPurpleDark)),
                const SizedBox(height: 4),
                const Text('اضغط على البطاقة لقلبها وعرض كل المعلومات', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                FlipMemberCard(member: m),
                const SizedBox(height: 18),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.badge, color: kPurple),
                    title: Text('رقم التسجيل: ${m.regNumber}'),
                    subtitle: Text('${m.specialization} — ${m.level} — ${m.year}'),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.phone, color: kPurple),
                    title: Text(m.phone.isEmpty ? 'لا يوجد رقم هاتف' : m.phone),
                    subtitle: Text(m.email.isEmpty ? 'لا يوجد بريد إلكتروني' : m.email),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickPhoto(context),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('تغيير الصورة'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await store.clearSession();
                          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen(store: store)));
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('تسجيل الخروج'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── نموذج إضافة/تعديل عضو ─────────────────────────
class MemberFormScreen extends StatefulWidget {
  final MemberStore store;
  final Member? member; // null = إضافة
  const MemberFormScreen({super.key, required this.store, this.member});
  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _first, _last, _reg, _pass, _phone, _email;
  String _spec = kSpecializations.first;
  String _level = kLevels.first;
  String _year = kYears.first;
  bool _isLeader = false;
  String _photo = '';

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _first = TextEditingController(text: m?.firstName ?? '');
    _last = TextEditingController(text: m?.lastName ?? '');
    _reg = TextEditingController(text: m?.regNumber ?? '');
    _pass = TextEditingController(text: m?.password ?? '');
    _phone = TextEditingController(text: m?.phone ?? '');
    _email = TextEditingController(text: m?.email ?? '');
    if (m != null) {
      _spec = kSpecializations.contains(m.specialization) ? m.specialization : 'أخرى';
      _level = kLevels.contains(m.level) ? m.level : kLevels.first;
      _year = kYears.contains(m.year) ? m.year : kYears.first;
      _isLeader = m.isLeader;
      _photo = m.photoBase64;
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _photo = base64Encode(bytes));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final now = DateTime.now();
    final join = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (widget.member == null) {
      if (widget.store.members.any((e) => e.regNumber == _reg.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم التسجيل موجود مسبقاً! اختر رقماً آخر.')));
        return;
      }
      await widget.store.add(Member(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        specialization: _spec,
        level: _level,
        year: _year,
        regNumber: _reg.text.trim(),
        password: _pass.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        photoBase64: _photo,
        isLeader: _isLeader,
        joinDate: join,
      ));
    } else {
      await widget.store.update(widget.member!.copyWith(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        specialization: _spec,
        level: _level,
        year: _year,
        regNumber: _reg.text.trim(),
        password: _pass.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        photoBase64: _photo,
        isLeader: _isLeader,
      ));
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.member != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل بيانات عضو' : 'إضافة عضو جديد')),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: kLavender,
                      child: _photo.isNotEmpty
                          ? ClipOval(child: Image.memory(base64Decode(_photo), width: 110, height: 110, fit: BoxFit.cover))
                          : const Icon(Icons.person, size: 60, color: kPurple),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: kPurple,
                        child: IconButton(icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white), onPressed: _pickPhoto),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Center(child: Text('اضغط على الكاميرا لاختيار صورة العضو', style: TextStyle(color: Colors.grey, fontSize: 12))),
              const SizedBox(height: 16),
              _txt(_first, 'الاسم *', Icons.person),
              _txt(_last, 'اللقب *', Icons.person_outline),
              _drop('التخصص', _spec, kSpecializations, (v) => setState(() => _spec = v!)),
              _drop('المستوى الدراسي', _level, kLevels, (v) => setState(() => _level = v!)),
              _drop('السنة الدراسية / الجامعية', _year, kYears, (v) => setState(() => _year = v!)),
              _txt(_reg, 'رقم التسجيل * (يُستخدم للدخول)', Icons.badge, keyboard: TextInputType.number),
              _txt(_pass, 'الرقم السري *', Icons.lock),
              _txt(_phone, 'رقم الهاتف', Icons.phone, keyboard: TextInputType.phone),
              _txt(_email, 'البريد الإلكتروني', Icons.email, keyboard: TextInputType.emailAddress),
              SwitchListTile(
                title: const Text('حساب قائد (لوحة تحكم)'),
                subtitle: const Text('عند التفعيل يستطيع هذا الحساب دخول لوحة التحكم'),
                value: _isLeader,
                onChanged: (v) => setState(() => _isLeader = v),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(isEdit ? 'حفظ التعديلات' : 'إضافة العضو', style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _txt(TextEditingController c, String label, IconData icon, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
        validator: (v) => (label.contains('*') && (v == null || v.trim().isEmpty)) ? 'هذا الحقل مطلوب' : null,
      ),
    );
  }

  Widget _drop(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.school), border: const OutlineInputBorder()),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ───────────────────────── لوحة تحكم القائد ─────────────────────────
class AdminDashboard extends StatefulWidget {
  final MemberStore store;
  final Member leader;
  const AdminDashboard({super.key, required this.store, required this.leader});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _search = '';
  String? _filterSpec;
  String? _filterYear;

  Map<String, int> _countBy(List<Member> list, String Function(Member) key) {
    final map = <String, int>{};
    for (final m in list) {
      map[key(m)] = (map[key(m)] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم القائد'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await widget.store.clearSession();
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen(store: widget.store)));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemberFormScreen(store: widget.store))),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة عضو'),
      ),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (_, __) {
          final all = widget.store.members;
          final bySpec = _countBy(all, (m) => m.specialization);
          final byYear = _countBy(all, (m) => m.year);
          var filtered = all.where((m) {
            final q = _search.trim();
            final okQ = q.isEmpty || m.fullName.contains(q) || m.regNumber.contains(q) || m.specialization.contains(q);
            final okS = _filterSpec == null || m.specialization == _filterSpec;
            final okY = _filterYear == null || m.year == _filterYear;
            return okQ && okS && okY;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('مرحباً قائد النادي: ${widget.leader.fullName} 👑', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPurpleDark)),
                const SizedBox(height: 14),
                // إحصائيات
                Row(children: [
                  _stat(Icons.people, 'إجمالي الأعضاء', '${all.length}', kPurple),
                  _stat(Icons.star, 'القادة', '${all.where((e) => e.isLeader).length}', kGold),
                  _stat(Icons.school, 'التخصصات', '${bySpec.length}', kNavy),
                ]),
                const SizedBox(height: 16),
                _chartCard('الأعضاء حسب التخصص', bySpec),
                const SizedBox(height: 12),
                _chartCard('الأعضاء حسب السنة الجامعية', byYear),
                const SizedBox(height: 16),
                // بحث وفلاتر
                TextField(
                  decoration: const InputDecoration(labelText: 'بحث بالاسم أو رقم التسجيل أو التخصص...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _filterDrop('كل التخصصات', _filterSpec, kSpecializations, (v) => setState(() => _filterSpec = v))),
                  const SizedBox(width: 8),
                  Expanded(child: _filterDrop('كل السنوات', _filterYear, kYears, (v) => setState(() => _filterYear = v))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Text('الأعضاء (${filtered.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      final txt = all.map((m) => '${m.fullName} | ${m.regNumber} | ${m.specialization} | ${m.level} | ${m.year} | ${m.phone}').join('\n');
                      Clipboard.setData(ClipboardData(text: txt));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ قائمة الأعضاء — الصقها في ملف Excel أو Word')));
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('نسخ القائمة'),
                  ),
                ]),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('لا يوجد أعضاء مطابقون للبحث', style: TextStyle(color: Colors.grey))),
                  ),
                ...filtered.map((m) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: kLavender,
                          child: m.photoBase64.isNotEmpty
                              ? ClipOval(child: Image.memory(base64Decode(m.photoBase64), width: 40, height: 40, fit: BoxFit.cover))
                              : const Icon(Icons.person, color: kPurple),
                        ),
                        title: Text(m.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${m.regNumber} • ${m.specialization} • ${m.level} • ${m.year}${m.isLeader ? ' • 👑 قائد' : ''}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.credit_card, color: kPurple),
                            tooltip: 'عرض البطاقة',
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _MemberCardPage(member: m))),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'تعديل',
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemberFormScreen(store: widget.store, member: m))),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'حذف',
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('حذف العضو؟'),
                                  content: Text('سيتم حذف ${m.fullName} نهائياً.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (ok == true) await widget.store.remove(m.id);
                            },
                          ),
                        ]),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _MemberCardPage(member: m))),
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
      ),
    );
  }

  Widget _chartCard(String title, Map<String, int> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxV = data.values.reduce(math.max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...data.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    SizedBox(width: 130, child: Text(e.key, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: maxV == 0 ? 0 : e.value / maxV,
                        backgroundColor: kLavender,
                        valueColor: const AlwaysStoppedAnimation(kPurple),
                        minHeight: 14,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                )),
          ],
        ),
      ),
    );
  }

  Widget _filterDrop(String hint, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: hint, border: const OutlineInputBorder(), isDense: true),
      items: [DropdownMenuItem(value: null, child: Text(hint)), ...items.map((e) => DropdownMenuItem(value: e, child: Text(e)))],
      onChanged: onChanged,
    );
  }
}

class _MemberCardPage extends StatelessWidget {
  final Member member;
  const _MemberCardPage({required this.member});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(member.fullName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          const Text('اضغط على البطاقة لقلبها', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          FlipMemberCard(member: member),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.badge, color: kPurple), title: Text('رقم التسجيل: ${member.regNumber}')),
          ListTile(leading: const Icon(Icons.phone, color: kPurple), title: Text(member.phone.isEmpty ? '—' : member.phone)),
          ListTile(leading: const Icon(Icons.email, color: kPurple), title: Text(member.email.isEmpty ? '—' : member.email)),
        ]),
      ),
    );
  }
}
