import 'notifications.dart';
import 'store.dart';

/// يربط النشاطات بالإشعارات:
/// - للأعضاء المسجّلين فقط (لا تصل للضيوف)
/// - منبّه الاهتزاز يُضبط تلقائياً قبل 10 دقائق من موعد النشاط
class ActivityNotifier {
  static const Duration kAlarmLead = Duration(minutes: 10);

  /// حساب وقت المنبّه (قبل 10 دقائق من النشاط، أو عند الموعد إذا تبقّى أقل من 10 دقائق)
  static DateTime? alarmTimeFor(DateTime activityTime) {
    final now = DateTime.now();
    if (!activityTime.isAfter(now)) return null;
    final early = activityTime.subtract(kAlarmLead);
    return early.isAfter(now) ? early : activityTime;
  }

  /// جدولة كل الأنشطة القادمة التي لم تُجدَّل بعد (للأعضاء فقط)
  static Future<void> scheduleUpcoming(MemberStore store) async {
    if (!Notifications.ready) return;
    if (store.sessionReg == null) return; // إشعارات النشاطات للأعضاء فقط
    for (final activity in store.upcomingActivities) {
      final when = alarmTimeFor(activity.at);
      if (when == null) continue;
      if (store.isActivityNotified(activity.id)) continue;
      final ok = await Notifications.scheduleAt(
        id: Notifications.idFor('activity_${activity.id}'),
        activityId: activity.id,
        when: when,
        title: 'منبّه قبل 10 دقائق: ${activity.title}',
        body: _scheduleBody(activity),
      );
      if (ok) await store.markActivityNotified(activity.id);
    }
  }

  /// إشعار فوري بكل نشاط جديد وصل من السحابة (للأعضاء فقط)
  static Future<void> announceNew(MemberStore store) async {
    if (store.sessionReg == null) {
      store.lastSyncedNewActivities = const [];
      return;
    }
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

  /// بعد كل مزامنة: إشعار للنشاطات الجديدة + جدولة المنبّهات (للأعضاء فقط)
  static Future<void> afterSync(MemberStore store) async {
    if (!Notifications.ready) return;
    if (store.sessionReg == null) return;
    await announceNew(store);
    await scheduleUpcoming(store);
  }

  /// عند نشر نشاط من طرف القائد (أو تعديله)
  static Future<void> onPublished(Activity activity) async {
    if (!Notifications.ready) return;
    await Notifications.cancel(Notifications.idFor('activity_${activity.id}'));
    final when = alarmTimeFor(activity.at);
    if (when != null) {
      await Notifications.scheduleAt(
        id: Notifications.idFor('activity_${activity.id}'),
        activityId: activity.id,
        when: when,
        title: 'منبّه قبل 10 دقائق: ${activity.title}',
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
        ? 'يبدأ الساعة $time — ${activity.dateLabel}'
        : '$place • يبدأ الساعة $time';
  }
}
