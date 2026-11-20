import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/store.dart';
import '../core/theme.dart';

class SettingsTab extends StatefulWidget {
  final MemberStore store;
  final VoidCallback onLogout;

  const SettingsTab({super.key, required this.store, required this.onLogout});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _reg = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reg.text = widget.store.leaderReg;
  }

  @override
  void dispose() {
    _reg.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _copyList() async {
    final text = widget.store.exportText();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) toast(context, 'تم نسخ قائمة الأعضاء — الصقها في Excel أو Word');
  }

  Future<void> _resetClub() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف كل الأعضاء؟', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'سيتم حذف جميع بطاقات الأعضاء نهائياً من هذا الجهاز، ولا يمكن التراجع عن العملية.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.resetClub();
    if (mounted) toast(context, 'تم حذف جميع الأعضاء');
  }

  Future<void> _saveCredentials() async {
    final reg = _reg.text.trim();
    if (reg.length < 4) {
      toast(context, 'رقم تسجيل القائد قصير جداً', error: true);
      return;
    }
    if (widget.store.members.any((m) => m.regNumber == reg)) {
      toast(context, 'رقم التسجيل مستعمل من قِبل أحد الأعضاء', error: true);
      return;
    }
    if (_pass.text.isNotEmpty) {
      if (_pass.text.length < 5) {
        toast(context, 'الرقم السري يجب أن يكون 5 أحرف على الأقل', error: true);
        return;
      }
      if (_pass.text != _pass2.text) {
        toast(context, 'الرقمان السريان غير متطابقين', error: true);
        return;
      }
    }
    setState(() => _saving = true);
    await widget.store.updateLeaderCredentials(
      reg: reg,
      password: _pass.text.isEmpty ? widget.store.leaderPassword : _pass.text,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _pass.clear();
      _pass2.clear();
    });
    toast(context, 'تم تحديث بيانات دخول القائد');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 58, 20, 24),
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الإعدادات',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('إدارة بيانات الدخول والبيانات العامة للنادي',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          child: Column(
            children: [
              SectionCard(
                title: 'بيانات دخول القائد',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('رقم التسجيل'),
                    const SizedBox(height: 7),
                    TextField(
                      controller: _reg,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.badge_outlined, size: 19, color: AppColors.purple),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('رقم سري جديد (اتركه فارغاً للإبقاء على الحالي)'),
                    const SizedBox(height: 7),
                    TextField(
                      controller: _pass,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, size: 19, color: AppColors.purple),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 19,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('تأكيد الرقم السري'),
                    const SizedBox(height: 7),
                    TextField(
                      controller: _pass2,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.lock_reset_outlined, size: 19, color: AppColors.purple),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _saveCredentials,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ التغييرات',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'بيانات النادي',
                child: Column(
                  children: [
                    _tile(
                      icon: Icons.copy_all_outlined,
                      title: 'نسخ قائمة الأعضاء',
                      subtitle: '${s.totalMembers} عضواً — جاهزة للصق في Excel',
                      onTap: _copyList,
                    ),
                    _tile(
                      icon: Icons.badge_outlined,
                      title: 'رقم تسجيل القائد',
                      subtitle: '${s.leaderReg.length} رقماً — محفوظ بشكل آمن',
                      onTap: null,
                    ),
                    _tile(
                      icon: Icons.logout,
                      title: 'تسجيل الخروج',
                      subtitle: 'الخروج من لوحة القيادة',
                      color: const Color(0xFFB91C1C),
                      onTap: widget.onLogout,
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'حول التطبيق',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.line, width: 1.5),
                          ),
                          child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('نادي رواد الاقتصاد',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                              Text('Economics Pioneers Club — EPC',
                                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        const ChipTag(text: 'v1.1.0'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'تطبيق إدارة عضوية النادي: بطاقة عضو رقمية قابلة للقلب، لوحة قيادة شاملة، '
                      'وبيانات محفوظة على الجهاز.',
                      style: TextStyle(fontSize: 12.5, height: 1.7, color: AppColors.muted.withValues(alpha: 0.95)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'منطقة الخطر',
                child: Column(
                  children: [
                    Text(
                      'حذف جميع الأعضاء من هذا الجهاز. لا يمكن التراجع.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted.withValues(alpha: 0.95)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _resetClub,
                        icon: const Icon(Icons.delete_forever_outlined, size: 19),
                        label: const Text('حذف كل الأعضاء',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB91C1C),
                          side: BorderSide(color: const Color(0xFFB91C1C).withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? color,
    bool last = false,
  }) {
    final tint = color ?? AppColors.purple;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_left, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
