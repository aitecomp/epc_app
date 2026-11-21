import 'notifications.dart';
import 'store.dart';

/// يربط النشاطات بالإشعارات: إشعار فوري عند النشر + منبّه في اليوم والوقت المحدّد
class ActivityNotifier {
  /// جدولة كل الأنشطة القادمة التي لم تُجدَّل بعد
  static Future<void> scheduleUpcoming(MemberStore store) async {
    if (!Notifications.ready) return;
    final now = DateTime.now();
    for (final activity in store.upcomingActivities) {
      if (activity.at.isBefore(now)) continue;
      if (store.isActivityNotified(activity.id)) continue;
      final ok = await Notifications.scheduleAt(
        id: Notifications.idFor('activity_${activity.id}'),
        activityId: activity.id,
        when: activity.at,
        title: 'تذكير: ${activity.title}',
        body: _scheduleBody(activity),
      );
      if (ok) await store.markActivityNotified(activity.id);
    }
  }

  /// إشعار فوري بكل نشاط جديد وصل من السحابة
  static Future<void> announceNew(MemberStore store) async {
    final fresh = List<Activity>.from(store.lastSyncedNewActivities);
    if (fresh.isEmpty) return;
    store.lastSyncedNewActivities = const [];
    for (final activity in fresh) {
      await Notifications.showNow(
        id: Notifications.idFor('new_${activity.id}'),
        activityId: activity.id,
        title: 'نشاط جديد في النادي',
        body: '${activity.title} — ${activity.weekdayLabel} ${activity.dateLabel} '
            'على الساعة ${activity.timeLabel}',
      );
    }
    await scheduleUpcoming(store);
  }

  /// بعد كل مزامنة: إشعار للنشاطات الجديدة + جدولة المنبّهات
  static Future<void> afterSync(MemberStore store) async {
    if (!Notifications.ready) return;
    await announceNew(store);
    await scheduleUpcoming(store);
  }

  /// عند نشر نشاط من طرف القائد (أو تعديله)
  static Future<void> onPublished(Activity activity) async {
    if (!Notifications.ready) return;
    await Notifications.cancel(Notifications.idFor('activity_${activity.id}'));
    if (activity.at.isAfter(DateTime.now())) {
      await Notifications.scheduleAt(
        id: Notifications.idFor('activity_${activity.id}'),
        activityId: activity.id,
        when: activity.at,
        title: 'تذكير: ${activity.title}',
        body: _scheduleBody(activity),
      );
    }
  }

  static Future<void> onDeleted(String id) async {
    await Notifications.cancel(Notifications.idFor('activity_$id'));
    await Notifications.cancel(Notifications.idFor('new_$id'));
  }

  static String _scheduleBody(Activity activity) {
    final place = activity.place.trim();
    final time = activity.timeLabel;
    return place.isEmpty
        ? 'الموعد: $time — ${activity.dateLabel}'
        : '$place • الساعة $time';
  }
}
