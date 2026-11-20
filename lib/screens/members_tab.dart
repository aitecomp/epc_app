import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/member_card.dart';

class MembersTab extends StatefulWidget {
  final MemberStore store;
  final VoidCallback onAddMember;
  final void Function(Member) onOpenMember;
  final void Function(Member) onEditMember;
  final void Function(Member) onDeleteMember;

  const MembersTab({
    super.key,
    required this.store,
    required this.onAddMember,
    required this.onOpenMember,
    required this.onEditMember,
    required this.onDeleteMember,
  });

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> {
  final _search = TextEditingController();
  String _query = '';
  String? _spec;
  String? _year;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text.trim()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Member> get _filtered {
    var list = widget.store.members.toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((m) {
        return m.fullName.toLowerCase().contains(q) ||
            m.regNumber.contains(q) ||
            m.phone.contains(q) ||
            m.email.toLowerCase().contains(q) ||
            m.specialization.toLowerCase().contains(q);
      }).toList();
    }
    if (_spec != null) list = list.where((m) => m.specialization == _spec).toList();
    if (_year != null) list = list.where((m) => m.year == _year).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final members = _filtered;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(26),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('أعضاء النادي',
                        style: TextStyle(
                            color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${members.length} / ${widget.store.totalMembers}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم، رقم التسجيل، التخصص…',
                  prefixIcon: const Icon(Icons.search, color: AppColors.purple, size: 21),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => _search.clear(),
                          icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                        ),
                  fillColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            children: [
              _filterChip(
                label: _spec ?? 'كل التخصصات',
                active: _spec != null,
                onTap: () => _pick(
                  title: 'التخصص',
                  items: kSpecializations,
                  current: _spec,
                  onSelected: (v) => setState(() => _spec = v),
                ),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: _year ?? 'كل السنوات',
                active: _year != null,
                onTap: () => _pick(
                  title: 'السنة الجامعية',
                  items: kYears,
                  current: _year,
                  onSelected: (v) => setState(() => _year = v),
                ),
              ),
              if (_spec != null || _year != null) ...[
                const SizedBox(width: 8),
                _filterChip(
                  label: 'إزالة الفلاتر',
                  active: false,
                  icon: Icons.filter_alt_off_outlined,
                  onTap: () => setState(() {
                    _spec = null;
                    _year = null;
                  }),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: members.isEmpty
              ? EmptyState(
                  icon: Icons.search_off,
                  title: widget.store.members.isEmpty ? 'لا يوجد أعضاء بعد' : 'لا توجد نتائج',
                  subtitle: widget.store.members.isEmpty
                      ? 'أضف أول عضو في النادي لتظهر بطاقته هنا.'
                      : 'جرّب تعديل كلمات البحث أو إزالة الفلاتر.',
                  action: widget.store.members.isEmpty
                      ? SizedBox(
                          width: 190,
                          child: PrimaryButton(
                            label: 'إضافة عضو',
                            icon: Icons.person_add_alt_1,
                            onPressed: widget.onAddMember,
                          ),
                        )
                      : null,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final m = members[index];
                    return _MemberTile(
                      member: m,
                      onTap: () => widget.onOpenMember(m),
                      onEdit: () => widget.onEditMember(m),
                      onDelete: () => widget.onDeleteMember(m),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.purple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.purple : AppColors.line),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: active ? Colors.white : AppColors.purple),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.ink,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down,
                size: 16, color: active ? Colors.white : AppColors.muted),
          ],
        ),
      ),
    );
  }

  Future<void> _pick({
    required String title,
    required List<String> items,
    required String? current,
    required ValueChanged<String?> onSelected,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Center(
                child: Text(title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
            ListTile(
              title: const Text('الكل'),
              trailing: current == null ? const Icon(Icons.check, color: AppColors.purple) : null,
              onTap: () => Navigator.pop(context, '__all__'),
            ),
            for (final item in items)
              ListTile(
                title: Text(item),
                trailing: current == item ? const Icon(Icons.check, color: AppColors.purple) : null,
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (result == null) return;
    onSelected(result == '__all__' ? null : result);
  }
}

class _MemberTile extends StatelessWidget {
  final Member member;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemberTile({
    required this.member,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              MemberAvatar(member: member, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ChipTag(text: member.specialization, icon: Icons.school_outlined),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(member.regNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.muted, size: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (value) {
                  if (value == 'view') onTap();
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(children: [
                      Icon(Icons.badge_outlined, size: 18, color: AppColors.purple),
                      SizedBox(width: 8),
                      Text('عرض البطاقة'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18, color: AppColors.purple),
                      SizedBox(width: 8),
                      Text('تعديل'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 18, color: Color(0xFFB91C1C)),
                      SizedBox(width: 8),
                      Text('حذف', style: TextStyle(color: Color(0xFFB91C1C))),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
