import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/store.dart';
import '../core/theme.dart';

class MemberFormScreen extends StatefulWidget {
  final Member? member;

  /// وضع بطاقة القائد: يحفظ في ملف القائد ولا يطلب بيانات الدخول
  final bool leaderMode;

  const MemberFormScreen({super.key, this.member, this.leaderMode = false});

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _reg;
  late final TextEditingController _pass;
  late final TextEditingController _phone;
  late final TextEditingController _email;

  late String _branch;
  late String _specialization;
  late String _level;
  late String _year;
  late String _role;
  String _photo = '';
  bool _saving = false;

  bool get isEdit => widget.member != null;

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
    _branch = m?.branch ?? kCommonTrunk;
    _specialization = m?.specialization ?? kCommonTrunkProgram;
    _level = m?.level ?? kLevels.first;
    _year = m?.year ?? kAcademicYear;
    _role = m?.role ?? kRoles.first;
    _photo = m?.photoBase64 ?? '';
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _reg.dispose();
    _pass.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1000, imageQuality: 78);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _photo = base64Encode(bytes));
    } catch (_) {
      if (!mounted) return;
      toast(context, 'تعذّر اختيار الصورة', error: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final reg = _reg.text.trim();
    if (MemberStore.instance.regExists(reg, ignoreId: widget.member?.id)) {
      setState(() => _saving = false);
      toast(context, 'رقم التسجيل « $reg » مستعمل مسبقاً', error: true);
      return;
    }

    final member = Member(
      id: widget.member?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      specialization: _specialization,
      branch: _branch,
      level: _level,
      year: _year,
      regNumber: reg,
      password: _pass.text,
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      role: _role,
      photoBase64: _photo,
      joinedAt: widget.member?.joinedAt,
    );

    if (widget.leaderMode) {
      await MemberStore.instance.saveLeaderProfile(member);
    } else {
      await MemberStore.instance.saveMember(member);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: AppColors.ink),
        ),
        title: Text(
          widget.leaderMode
              ? 'تعديل بطاقة القائد'
              : (isEdit ? 'تعديل بيانات العضو' : 'إضافة عضو جديد'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _photoSection(),
            const SizedBox(height: 18),
            SectionCard(
              title: 'البيانات الشخصية',
              child: Column(
                children: [
                  _field('الاسم', _first, hint: 'الاسم الأول', icon: Icons.person_outline,
                      validator: (v) => v!.trim().isEmpty ? 'الاسم مطلوب' : null),
                  const SizedBox(height: 14),
                  _field('اللقب', _last, hint: 'اسم العائلة', icon: Icons.person_outline,
                      validator: (v) => v!.trim().isEmpty ? 'اللقب مطلوب' : null),
                  const SizedBox(height: 14),
                  _field('رقم الهاتف', _phone, hint: '05xxxxxxxx', icon: Icons.phone_outlined,
                      keyboard: TextInputType.phone),
                  const SizedBox(height: 14),
                  _field('البريد الإلكتروني', _email, hint: 'name@example.com',
                      icon: Icons.mail_outline, keyboard: TextInputType.emailAddress),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'المسار الجامعي — جامعة غيليزان',
              child: Column(
                children: [
                  _dropdown('الشعبة', kBranches, _branch, (v) {
                    setState(() {
                      _branch = v;
                      _specialization = kPrograms[v]!.first;
                    });
                  }, icon: Icons.account_tree_outlined),
                  const SizedBox(height: 14),
                  _dropdown('التخصص', kPrograms[_branch] ?? const [kCommonTrunkProgram],
                      kPrograms[_branch]!.contains(_specialization)
                          ? _specialization
                          : kPrograms[_branch]!.first,
                      (v) => setState(() => _specialization = v),
                      icon: Icons.school_outlined),
                  const SizedBox(height: 14),
                  _dropdown('المستوى الدراسي', kLevels, _level, (v) => setState(() => _level = v),
                      icon: Icons.trending_up),
                  const SizedBox(height: 14),
                  _dropdown('السنة الجامعية', kAcademicYears, _year,
                      (v) => setState(() => _year = v), icon: Icons.calendar_month_outlined),
                  const SizedBox(height: 14),
                  _dropdown('الصفة في النادي', kRoles, _role, (v) => setState(() => _role = v),
                      icon: Icons.workspace_premium_outlined),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.softViolet,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.purple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _branch == kCommonTrunk
                                ? 'طلبة السنة الأولى يدرسون في الجذع المشترك ثم يختارون الشعبة.'
                                : 'الشعبة: $_branch — التخصص: $_specialization',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!widget.leaderMode) ...[
            SectionCard(
              title: 'بيانات الدخول',
              child: Column(
                children: [
                  _field('رقم التسجيل', _reg, hint: '20260001', icon: Icons.badge_outlined,
                      keyboard: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        final value = v!.trim();
                        if (value.isEmpty) return 'رقم التسجيل مطلوب';
                        if (value.length < 4) return 'رقم التسجيل قصير جداً';
                        return null;
                      }),
                  const SizedBox(height: 14),
                  _field('الرقم السري', _pass, hint: 'كلمة مرور العضو', icon: Icons.lock_outline,
                      obscure: true,
                      validator: (v) => (v == null || v.trim().length < 4) ? 'الرقم السري 4 أحرف على الأقل' : null),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 15, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'يمنح العضو رقماً سرياً يتيح له الدخول إلى بطاقته.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.muted.withValues(alpha: 0.95)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: isEdit ? 'حفظ التعديلات' : 'إضافة العضو',
              icon: Icons.check_circle_outline,
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 10),
            GhostButton(label: 'إلغاء', onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }

  Widget _photoSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.softViolet,
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.55), width: 2),
                ),
                child: ClipOval(
                  child: _photo.isEmpty
                      ? Icon(Icons.person, size: 52, color: AppColors.purple.withValues(alpha: 0.45))
                      : Image.memory(base64Decode(_photo), fit: BoxFit.cover),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: GestureDetector(
                  onTap: () => _pick(ImageSource.camera),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.purple,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: const Icon(Icons.photo_camera_outlined, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.image_outlined, size: 17),
            label: Text(_photo.isEmpty ? 'إضافة صورة العضو' : 'تغيير الصورة'),
            style: TextButton.styleFrom(foregroundColor: AppColors.purple),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    IconData? icon,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          inputFormatters: formatters,
          obscureText: obscure,
          validator: validator,
          style: const TextStyle(fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon, size: 19, color: AppColors.purple),
          ),
        ),
      ],
    );
  }

  Widget _dropdown(String label, List<String> items, String value, ValueChanged<String> onChanged,
      {IconData icon = Icons.school_outlined}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: AppColors.purple),
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 14),
          decoration: InputDecoration(prefixIcon: Icon(icon, size: 19, color: AppColors.purple)),
          items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
