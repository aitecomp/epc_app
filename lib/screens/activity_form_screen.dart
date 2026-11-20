import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';

/// نموذج نشر / تعديل نشاط (للقائد فقط)
class ActivityFormScreen extends StatefulWidget {
  final Activity? activity;
  const ActivityFormScreen({super.key, this.activity});

  @override
  State<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends State<ActivityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _details;
  late final TextEditingController _place;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 16, minute: 0);

  bool get _editing => widget.activity != null;

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    _title = TextEditingController(text: a?.title ?? '');
    _details = TextEditingController(text: a?.details ?? '');
    _place = TextEditingController(text: a?.place ?? '');
    if (a != null) {
      _date = DateTime(a.at.year, a.at.month, a.at.day);
      _time = TimeOfDay(hour: a.at.hour, minute: a.at.minute);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _place.dispose();
    super.dispose();
  }

  DateTime get _combined =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('ar'),
      helpText: 'اختر يوم النشاط',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'اختر وقت النشاط',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_combined.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
      toast(context, 'لا يمكن اختيار موعد في الماضي', error: true);
      return;
    }
    Navigator.pop(context, buildActivity());
  }

  Activity buildActivity() {
    final now = DateTime.now();
    return Activity(
      id: widget.activity?.id ?? 'act_${now.microsecondsSinceEpoch}',
      title: _title.text.trim(),
      details: _details.text.trim(),
      place: _place.text.trim(),
      at: _combined,
      createdAt: widget.activity?.createdAt ?? now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(18, top + 14, 18, 20),
            decoration: const BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                const Expanded(
                  child: Text(
                    'نشر نشاط جديد',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.campaign_outlined, color: AppColors.goldSoft),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  SectionCard(
                    title: 'تفاصيل النشاط',
                    child: Column(
                      children: [
                        _field(
                          controller: _title,
                          label: 'عنوان النشاط',
                          hint: 'مثال: ندوة حول ريادة الأعمال',
                          icon: Icons.title_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'أدخل عنوان النشاط'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _place,
                          label: 'المكان',
                          hint: 'قاعة المحاضرات — كلية العلوم الاقتصادية',
                          icon: Icons.place_outlined,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _details,
                          label: 'وصف مختصر (اختياري)',
                          hint: 'تفاصيل إضافية عن النشاط…',
                          icon: Icons.notes_rounded,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'اليوم والوقت',
                    child: Column(
                      children: [
                        _pickerRow(
                          icon: Icons.calendar_month_outlined,
                          label: 'اليوم',
                          value:
                              '${Activity(id: 'x', title: '', at: _combined).weekdayLabel} — '
                              '${_combined.day.toString().padLeft(2, '0')}/${_combined.month.toString().padLeft(2, '0')}/${_combined.year}',
                          onTap: _pickDate,
                        ),
                        const Divider(height: 22),
                        _pickerRow(
                          icon: Icons.schedule_rounded,
                          label: 'الوقت',
                          value:
                              '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                          onTap: _pickTime,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.softViolet.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.notifications_active_outlined,
                            color: AppColors.purple, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'سيصل إشعار لكل الأعضاء عند النشر، ومنبّه بالاهتزاز في اليوم والوقت المحدّد.',
                            style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: Icon(_editing ? Icons.save_outlined : Icons.send_rounded),
                      label: Text(
                        _editing ? 'حفظ التعديلات' : 'نشر النشاط',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 19, color: AppColors.purple),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.purple, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pickerRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.purple),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const Spacer(),
            Text(value,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
