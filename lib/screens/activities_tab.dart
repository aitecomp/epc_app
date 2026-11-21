import 'package:flutter/material.dart';

import '../core/activity_notifier.dart';
import '../core/cloud_sync.dart';
import '../core/push_notifications.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'activity_form_screen.dart';

/// الرئيسية: نشاطات النادي (يشاهدها الجميع، وينشرها القائد)
class ActivitiesTab extends StatelessWidget {
  final MemberStore store;
  final bool isLeader;
  final String memberName;
  final VoidCallback onOpenProfile;

  const ActivitiesTab({
    super.key,
    required this.store,
    required this.isLeader,
    required this.memberName,
    required this.onOpenProfile,
  });

  Future<void> _refresh(BuildContext context) async {
    if (CloudSync.enabled) {
      await CloudSync.syncNow(store);
    }
    await ActivityNotifier.scheduleUpcoming(store);
    markActivitiesSeen(store);
  }

  static void markActivitiesSeen(MemberStore store) {
    store.markActivitiesSeen();
  }

  Future<void> _openForm(BuildContext context, {Activity? activity}) async {
    final res = await Navigator.of(context).push<Activity>(
      MaterialPageRoute(builder: (_) => ActivityFormScreen(activity: activity)),
    );
    if (res == null) return;
    final saved = res;
    await store.saveActivity(saved);
    await ActivityNotifier.onPublished(saved);
    if (activity == null) {
      await store.markActivityNotified(saved.id);
    }
    final synced = await CloudSync.push(store);
    final pushed = synced && await PushNotifications.publish(saved, updated: activity != null);
    if (context.mounted) {
      toast(context, !synced ? 'حُفظ النشاط على هذا الجهاز، تعذّرت المزامنة' :
          pushed ? 'تم حفظ النشاط وإرسال طلب الإشعار' : 'تمت المزامنة، لكن تعذّر إرسال الإشعار');
    }
  }

  Future<void> _delete(BuildContext context, Activity activity) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف النشاط', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('هل تريد حذف «${activity.title}»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.deleteActivity(activity.id);
    await ActivityNotifier.onDeleted(activity.id);
    final synced = await CloudSync.push(store);
    if (synced) await PushNotifications.publish(activity, deleted: true);
    if (context.mounted) toast(context, synced ? 'تم حذف النشاط' : 'حُذف محلياً، تعذّرت المزامنة');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final upcoming = store.upcomingActivities;
    final past = store.pastActivities;

    return RefreshIndicator(
      color: AppColors.purple,
      onRefresh: () => _refresh(context),
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _header(context, top, upcoming.length),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLeader) ...[
                  _publishButton(context),
                  const SizedBox(height: 18),
                ],
                if (upcoming.isEmpty && past.isEmpty)
                  _emptyState(context)
                else ...[
                  if (upcoming.isNotEmpty) ...[
                    _sectionTitle('النشاطات القادمة', Icons.event_available_outlined),
                    const SizedBox(height: 10),
                    for (final a in upcoming) ...[
                      _ActivityCard(
                        activity: a,
                        isLeader: isLeader,
                        isNew: store.isActivityUnseen(a.id),
                        onEdit: () => _openForm(context, activity: a),
                        onDelete: () => _delete(context, a),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _sectionTitle('نشاطات سابقة', Icons.history_rounded),
                    const SizedBox(height: 10),
                    for (final a in past) ...[
                      _ActivityCard(
                        activity: a,
                        isLeader: isLeader,
                        isNew: false,
                        past: true,
                        onEdit: () => _openForm(context, activity: a),
                        onDelete: () => _delete(context, a),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, double top, int count) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 26),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
                ),
                child: ClipOval(
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('نشاطات النادي',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    Text('Economics Pioneers Club',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 10,
                            letterSpacing: 1.2)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onOpenProfile,
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.person_outline_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('مرحباً، $memberName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.campaign_outlined, size: 14, color: AppColors.goldSoft),
              const SizedBox(width: 6),
              Text(
                count == 0 ? 'لا توجد نشاطات قادمة' : '$count نشاط قادم',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _publishButton(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton(
        onPressed: () => _openForm(context),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.purple,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 4,
          shadowColor: AppColors.purple.withValues(alpha: 0.4),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: AppColors.goldSoft, size: 21),
            SizedBox(width: 9),
            Text('نشر نشاط جديد',
                style: TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: AppColors.purple),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.softViolet,
            ),
            child: const Icon(Icons.event_note_outlined,
                color: AppColors.purple, size: 30),
          ),
          const SizedBox(height: 16),
          const Text('لا توجد نشاطات بعد',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            isLeader
                ? 'انشر أول نشاط ليصل إشعار لكل أعضاء النادي.'
                : 'سيصلك إشعار هنا عند نشر أي نشاط جديد.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Activity activity;
  final bool isLeader;
  final bool isNew;
  final bool past;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActivityCard({
    required this.activity,
    required this.isLeader,
    required this.isNew,
    this.past = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNew ? AppColors.gold.withValues(alpha: 0.55) : AppColors.line,
          width: isNew ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dateBadge(),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              activity.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                                color: past ? AppColors.muted : AppColors.ink,
                              ),
                            ),
                          ),
                          if (isNew)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('جديد',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 13, color: AppColors.purple),
                          const SizedBox(width: 4),
                          Text(activity.timeLabel,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.purple)),
                          const SizedBox(width: 10),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: past
                                  ? AppColors.line
                                  : AppColors.softViolet.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              past ? 'انتهى' : activity.remainingLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: past ? AppColors.muted : AppColors.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (activity.place.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 13, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                activity.place,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (activity.details.trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          activity.details,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, height: 1.55, color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isLeader)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('تعديل',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(foregroundColor: AppColors.purple),
                    ),
                  ),
                  Container(width: 1, height: 20, color: AppColors.line),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('حذف',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFB91C1C)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dateBadge() {
    return Container(
      width: 56,
      height: 62,
      decoration: BoxDecoration(
        gradient: past ? null : AppColors.headerGradient,
        color: past ? AppColors.line : null,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            activity.dayNumber,
            style: TextStyle(
              color: past ? AppColors.muted : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          Text(
            activity.monthLabel,
            style: TextStyle(
              color: past ? AppColors.muted : AppColors.goldSoft,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
