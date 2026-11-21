import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'activity_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final MemberStore store;
  const NotificationsScreen({super.key, required this.store});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.store.markActivitiesSeen());
  }

  @override
  Widget build(BuildContext context) {
    final activities = widget.store.activities.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('إشعارات النشاطات')),
      body: SafeArea(child: activities.isEmpty
        ? const Center(child: Text('لا توجد نشاطات بعد'))
        : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: activities.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final a = activities[i];
            return Card(child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.notifications_active_outlined)),
              title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${a.dateLabel} • ${a.timeLabel}'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: a))),
            ));
          },
        )),
    );
  }
}
