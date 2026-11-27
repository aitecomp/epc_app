import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/club_api.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/search_picker.dart';

/// نموذج طلب الانضمام للنادي (للضيوف فقط)
class JoinRequestTab extends StatefulWidget {
  final MemberStore store;
  final VoidCallback onSwitchToLogin;

  const JoinRequestTab({
    super.key,
    required this.store,
    required this.onSwitchToLogin,
  });

  @override
  State<JoinRequestTab> createState() => _JoinRequestTabState();
}

class _JoinRequestTabState extends State<JoinRequestTab> {
  late final ClubApi _api = ClubApi(widget.store);
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _regCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _motivationCtrl = TextEditingController();

  String _branch = kBranches.first;
  String _specialization = kCommonTrunkProgram;
  String _level = kLevels.first;
  String _year = kAcademicYear;
  String _photoBase64 = '';
  bool _obscure = true;
  bool _submitting = false;

  Map<String, dynamic>? _existingStatus;
  bool _checkingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkSavedRequest();
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _regCtrl.dispose();
    _passCtrl.dispose();
    _motivationCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkSavedRequest() async {
    final savedId = await ClubApi.getSavedJoinRequestId();
    if (savedId == null || savedId.isEmpty) {
      if (mounted) setState(() => _checkingStatus = false);
      return;
    }
    final status = await _api.fetchJoinRequestStatus(savedId);
    if (!mounted) return;
    setState(() {
      _existingStatus = status;
      _checkingStatus = false;
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await _picker.pickImage(
          source: ImageSource.gallery, maxWidth: 900, imageQuality: 76);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photoBase64 = base64Encode(bytes));
    } catch (_) {
      if (mounted) toast(context, 'تعذّر اختيار الصورة', error: true);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await _api.submitJoinRequest(
        firstName: _firstCtrl.text.trim(),
        lastName: _lastCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        branch: _branch,
        specialization: _specialization,
        level: _level,
        year: _year,
        regNumber: _regCtrl.text.trim(),
        password: _passCtrl.text,
        motivation: _motivationCtrl.text.trim(),
        photoBase64: _photoBase64,
      );
      await _checkSavedRequest();
      if (!mounted) return;
      setState(() => _submitting = false);
      toast(context, 'تم إرسال طلب الانضمام بنجاح! سيصلك الرد على بريدك الإلكتروني.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      toast(context, e.toString().replaceFirst('Bad state: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return RefreshIndicator(
      color: AppColors.purple,
      onRefresh: _checkSavedRequest,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _header(top),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset(context)),
            child: _checkingStatus
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator(color: AppColors.purple)),
                  )
                : (_existingStatus != null ? _statusView(_existingStatus!) : _formView()),
          ),
        ],
      ),
    );
  }

  Widget _header(double top) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 24),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.how_to_reg_rounded, color: AppColors.plum, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلب الانضمام للنادي',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'املأ استمارة العضوية وسيتم إشعارك عبر البريد الإلكتروني',
                  style: TextStyle(color: AppColors.goldSoft, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusView(Map<String, dynamic> status) {
    final st = (status['status'] ?? 'pending').toString();
    final note = (status['leaderNote'] ?? '').toString();
    final approved = st == 'approved';
    final rejected = st == 'rejected';
    final color = approved
        ? const Color(0xFF15803D)
        : (rejected ? const Color(0xFFB91C1C) : AppColors.gold);

    return FadeSlideIn(
      child: SectionCard(
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.45), width: 2),
              ),
              child: Icon(
                approved
                    ? Icons.verified_rounded
                    : (rejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded),
                size: 40,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              approved
                  ? 'مبروك! تم قبول عضويتك في النادي 🎉'
                  : (rejected ? 'نعتذر، تم رفض طلب الانضمام' : 'طلبك قيد المراجعة لدى القائد'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              approved
                  ? 'أصبحت الآن عضواً رسمياً في نادي رواد الاقتصاد. يمكنك تسجيل الدخول فوراً برقم التسجيل (${status['regNumber']}) وكلمة المرور التي اخترتها.'
                  : (rejected
                      ? 'تم إرسال إشعار بالقرار إلى بريدك الإلكتروني (${status['email']}).'
                      : 'تلقّى قائد النادي طلبك وسيصلك إشعار فوري على بريدك (${status['email']}) فور اتخاذ القرار.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.6),
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.softViolet,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ملاحظة القائد:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(note, style: const TextStyle(fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (approved)
              PrimaryButton(
                label: 'تسجيل الدخول كعضو الآن',
                icon: Icons.login_rounded,
                gold: true,
                onPressed: widget.onSwitchToLogin,
              )
            else ...[
              PrimaryButton(
                label: 'تحديث حالة الطلب',
                icon: Icons.refresh_rounded,
                onPressed: _checkSavedRequest,
              ),
              const SizedBox(height: 10),
              GhostButton(
                label: 'تقديم طلب جديد',
                icon: Icons.edit_document,
                onPressed: () async {
                  await ClubApi.clearSavedJoinRequestId();
                  if (mounted) setState(() => _existingStatus = null);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _formView() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // ── الصورة الشخصية ──
          FadeSlideIn(
            child: SectionCard(
              title: 'الصورة الشخصية (اختياري)',
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.softViolet,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold, width: 2),
                        image: _photoBase64.isNotEmpty
                            ? DecorationImage(
                                image: MemoryImage(base64Decode(_photoBase64)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _photoBase64.isEmpty
                          ? const Icon(Icons.add_a_photo_outlined,
                              color: AppColors.purple, size: 28)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تُستخدم لبطاقة العضوية بعد القبول',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: _pickPhoto,
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: Text(_photoBase64.isEmpty ? 'اختيار صورة' : 'تغيير الصورة'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── المعلومات الشخصية ──
          FadeSlideIn(
            delayMs: 60,
            child: SectionCard(
              title: 'المعلومات الشخصية والتواصل',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الاسم الأول *',
                            prefixIcon: Icon(Icons.person_outline, size: 19),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lastCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اللقب *',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني *',
                      hintText: 'example@gmail.com',
                      helperText: 'سيصلك إشعار القبول أو الرفض مباشرة على هذا البريد',
                      prefixIcon: Icon(Icons.mail_outline_rounded, color: AppColors.purple),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'البريد الإلكتروني مطلوب';
                      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)) {
                        return 'صيغة البريد غير صحيحة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف *',
                      hintText: '05xxxxxxxx',
                      prefixIcon: Icon(Icons.phone_outlined, color: AppColors.purple),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 8) ? 'أدخل رقم هاتف صحيح' : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── المسار الجامعي ──
          FadeSlideIn(
            delayMs: 120,
            child: SectionCard(
              title: 'المسار الجامعي',
              child: Column(
                children: [
                  _pickerBox(
                    label: 'الكلية',
                    value: _branch,
                    icon: Icons.account_balance_outlined,
                    onTap: () async {
                      final picked = await showFacultyPicker(context, current: _branch);
                      if (picked == null) return;
                      setState(() {
                        _branch = picked;
                        final specs = kFaculties[picked];
                        if (specs != null && specs.isNotEmpty) {
                          _specialization = specs.first;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _pickerBox(
                    label: 'التخصص',
                    value: _specialization,
                    icon: Icons.school_outlined,
                    onTap: () async {
                      final picked = await showProgramPicker(
                        context,
                        title: 'اختر التخصص',
                        search: searchPrograms,
                        current: _specialization,
                      );
                      if (picked == null) return;
                      setState(() {
                        _specialization = picked;
                        _branch = branchOfProgram(picked);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _level,
                    decoration: const InputDecoration(
                      labelText: 'المستوى الدراسي',
                      prefixIcon: Icon(Icons.stairs_outlined, color: AppColors.purple),
                    ),
                    items: kLevels
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _level = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _year,
                    decoration: const InputDecoration(
                      labelText: 'السنة الجامعية',
                      prefixIcon: Icon(Icons.calendar_month_outlined, color: AppColors.purple),
                    ),
                    items: kAcademicYears
                        .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _year = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── بيانات الدخول بعد القبول + الدافع ──
          FadeSlideIn(
            delayMs: 180,
            child: SectionCard(
              title: 'بيانات حسابك بعد القبول والدافع',
              child: Column(
                children: [
                  TextFormField(
                    controller: _regCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'رقم التسجيل الجامعي *',
                      hintText: 'مثال: 20260123',
                      prefixIcon: Icon(Icons.badge_outlined, color: AppColors.purple),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 4) ? 'أدخل رقم تسجيل صحيح' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور المقترحة للدخول *',
                      hintText: '4 أحرف أو أرقام على الأقل',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.purple),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 4) ? 'كلمة المرور 4 أحرف على الأقل' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _motivationCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'لماذا تريد الانضمام للنادي وما هي مهاراتك؟ *',
                      hintText: 'اذكر اهتماماتك ومهاراتك (تنظيم، تصميم، إلقاء، ريادة أعمال...)',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 10)
                            ? 'اكتب نبذة مختصرة (10 أحرف على الأقل)'
                            : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'إرسال طلب الانضمام',
            icon: Icons.send_rounded,
            gold: true,
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _pickerBox({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.purple),
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
