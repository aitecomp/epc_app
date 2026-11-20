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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.plum,
      body: Stack(
        children: [
          const _AuroraBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      _brand(),
                      const SizedBox(height: 26),
                      _form(),
                      const SizedBox(height: 22),
                      Text(
                        'الدخول متاح للأعضاء المسجَّلين في النادي فقط.\nللاستفسار تواصل مع قائد النادي.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '© 2026 نادي رواد الاقتصاد — EPC',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
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
    );
  }

  Widget _brand() {
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
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
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 2),
          ),
          child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
        ),
        const SizedBox(height: 18),
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
        const SizedBox(height: 12),
        const GoldRule(width: 62),
        const SizedBox(height: 10),
        Text(
          'Learn  •  Innovate  •  Lead  •  Succeed',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _form() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
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
            const Text(
              'تسجيل الدخول',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            const Text(
              'استخدم بيانات العضوية الخاصة بك',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            const _Label('رقم التسجيل'),
            const SizedBox(height: 8),
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
            const SizedBox(height: 16),
            const _Label('الرقم السري'),
            const SizedBox(height: 8),
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
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'دخول',
              icon: Icons.login,
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
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
          child: _glow(320, AppColors.gold.withValues(alpha: 0.20)),
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
