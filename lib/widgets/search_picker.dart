import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';

/// منتقي بحث قابل لإعادة الاستخدام (يُستخدم للتخصصات والكليات)
Future<String?> showProgramPicker(
  BuildContext context, {
  required String title,
  required List<MapEntry<String, String>> Function(String query) search,
  String? current,
  bool allowCustom = false,
  String customHint = 'اكتب التخصص',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProgramSheet(
      title: title,
      search: search,
      current: current,
      allowCustom: allowCustom,
      customHint: customHint,
    ),
  );
}

class _ProgramSheet extends StatefulWidget {
  final String title;
  final List<MapEntry<String, String>> Function(String query) search;
  final String? current;
  final bool allowCustom;
  final String customHint;

  const _ProgramSheet({
    required this.title,
    required this.search,
    required this.current,
    required this.allowCustom,
    required this.customHint,
  });

  @override
  State<_ProgramSheet> createState() => _ProgramSheetState();
}

class _ProgramSheetState extends State<_ProgramSheet> {
  late final TextEditingController _query;
  late List<MapEntry<String, String>> _results;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController();
    _results = widget.search('');
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _filter(String value) {
    setState(() => _results = widget.search(value));
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: height * 0.78,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  Text('${_results.length}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _query,
                autofocus: false,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'ابحث… (مثال: محاسبة، إعلام آلي، حقوق)',
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.purple),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _query.clear();
                            _filter('');
                          },
                        ),
                ),
              ),
            ),
            if (widget.allowCustom)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final custom = await _askCustom(context);
                    if (custom != null && custom.trim().isNotEmpty && context.mounted) {
                      Navigator.pop(context, custom.trim());
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.softViolet,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline, size: 18, color: AppColors.purple),
                        const SizedBox(width: 8),
                        Text(
                          _query.text.trim().isEmpty
                              ? 'تخصص غير موجود؟ أضِفه يدوياً'
                              : 'إضافة «${_query.text.trim()}»',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Expanded(
              child: _results.isEmpty
                  ? const Center(
                      child: Text('لا توجد نتائج',
                          style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 20),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        final selected = item.value == widget.current;
                        final showHeader = index == 0 || _results[index - 1].key != item.key;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showHeader)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppColors.gold,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item.key,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              tileColor: selected ? AppColors.softViolet : null,
                              title: Text(
                                item.value,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                              trailing: selected
                                  ? const Icon(Icons.check_circle, color: AppColors.purple, size: 20)
                                  : null,
                              onTap: () => Navigator.pop(context, item.value),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askCustom(BuildContext context) {
    final controller = TextEditingController(text: _query.text.trim());
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تخصص مخصص', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: widget.customHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

/// منتقي بسيط للكليات (قائمة قصيرة)
Future<String?> showFacultyPicker(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Center(
              child: Text('الكلية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
          for (final faculty in kBranches)
            ListTile(
              title: Text(faculty, style: const TextStyle(fontSize: 13.5)),
              trailing: current == faculty
                  ? const Icon(Icons.check_circle, color: AppColors.purple, size: 20)
                  : null,
              onTap: () => Navigator.pop(context, faculty),
            ),
        ],
      ),
    ),
  );
}
