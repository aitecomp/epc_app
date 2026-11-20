import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/cloud_sync.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'screens/leader_shell.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await MemberStore.instance.init();
  runApp(const EpcApp());
  // مزامنة سحابية في الخلفية (Cloudflare R2)
  if (CloudSync.enabled) {
    CloudSync.syncNow(MemberStore.instance);
  }
}

class EpcApp extends StatelessWidget {
  const EpcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نادي رواد الاقتصاد — EPC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const RootGate(),
      routes: {'/gate': (_) => const RootGate()},
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  final MemberStore _store = MemberStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChange);
  }

  @override
  void dispose() {
    _store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    await _store.logout();
  }

  @override
  Widget build(BuildContext context) {
    if (!_store.ready) {
      return const _SplashScreen();
    }
    final reg = _store.sessionReg;
    if (reg == null) {
      return const LoginScreen();
    }
    if (_store.isLeaderSession) {
      return LeaderShell(store: _store, onLogout: _logout);
    }
    final member = _store.currentMember;
    if (member == null) {
      // جلسة لغير موجود (حُذف العضو) — نعيد الدخول
      WidgetsBinding.instance.addPostFrameCallback((_) => _store.logout());
      return const _SplashScreen();
    }
    return ProfileScreen(member: member, onLogout: _logout);
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.headerGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(color: AppColors.goldSoft, strokeWidth: 2.6),
              ),
              SizedBox(height: 18),
              Text('نادي رواد الاقتصاد',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('ECONOMICS PIONEERS CLUB',
                  style: TextStyle(color: AppColors.goldSoft, fontSize: 9, letterSpacing: 1.8)),
            ],
          ),
        ),
      ),
    );
  }
}
