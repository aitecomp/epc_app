import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/store.dart';
import '../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _regCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _regCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final error = await MemberStore.instance.login(_regCtrl.text, _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      toast(context, error, error: true);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/gate', (_) => false);
  }

  Future<void> _enterAsGuest() async {
    await MemberStore.instance.enterGuestMode();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/gate', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kSystemUiOnDark,
      child: Scaffold(
        backgroundColor: AppColors.plum,
        body: Stack(
          children: [
            const _AuroraBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        FadeSlideIn(child: _brand()),
                        const SizedBox(height: 24),
                        FadeSlideIn(delayMs: 90, child: _form()),
                        const SizedBox(height: 16),
                        FadeSlideIn(delayMs: 170, child: _guestPortalCard()),
                        const SizedBox(height: 16),
                        Text(
                          '© 2026 نادي رواد الاقتصاد — EPC',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.42),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brand() {
    return Column(
      children: [
        Container(
          width: 98,
          height: 98,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.75), width: 2),
          ),
          child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
        ),
        const SizedBox(height: 16),
        const Text(
          'نادي رواد الاقتصاد',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'ECONOMICS PIONEERS CLUB',
          style: TextStyle(
            color: AppColors.goldSoft,
            fontSize: 10.5,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const GoldRule(width: 62),
        const SizedBox(height: 8),
        Text(
          'Learn  •  Innovate  •  Lead  •  Succeed',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 11,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _form() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.purple, size: 22),
                SizedBox(width: 8),
                Text(
                  'بوابة أعضاء النادي',
                  style: TextStyle(fontSize: 18.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 3),
            const Text(
              'سجّل دخولك للوصول إلى الدردشة، الأفكار، والفعاليات',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            const _Label('رقم التسجيل'),
            const SizedBox(height: 7),
            TextFormField(
              controller: _regCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2),
              decoration: const InputDecoration(
                hintText: 'مثال: 20260001',
                prefixIcon: Icon(Icons.badge_outlined, color: AppColors.purple, size: 21),
              ),
              onFieldSubmitted: (_) => _passFocus.requestFocus(),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل رقم التسجيل' : null,
            ),
            const SizedBox(height: 14),
            const _Label('الرقم السري'),
            const SizedBox(height: 7),
            TextFormField(
              controller: _passCtrl,
              focusNode: _passFocus,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.6),
              decoration: InputDecoration(
                hintText: '••••••',
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.purple, size: 21),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => (v == null || v.isEmpty) ? 'أدخل الرقم السري' : null,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'دخول الأعضاء',
              icon: Icons.login,
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _guestPortalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.public_rounded, color: AppColors.goldSoft, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'لست عضواً بعد؟ استكشف نشاطات النادي كضيف',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'تصفّح صور وفيديوهات نشاطاتنا وقدّم طلب الانضمام ليصلك الرد عبر البريد الإلكتروني.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'الدخول كضيف وطلب الانضمام',
            icon: Icons.explore_outlined,
            gold: true,
            onPressed: _enterAsGuest,
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted),
      );
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(decoration: const BoxDecoration(gradient: AppColors.headerGradient)),
        Positioned(
          top: -120,
          right: -80,
          child: _glow(280, AppColors.violet.withValues(alpha: 0.55)),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          child: _glow(320, AppColors.gold.withValues(alpha: 0.22)),
        ),
      ],
    );
  }

  Widget _glow(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}
