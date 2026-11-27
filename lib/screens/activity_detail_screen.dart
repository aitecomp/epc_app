import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/smart_text.dart';

class ActivityDetailScreen extends StatelessWidget {
  final Activity activity;
  const ActivityDetailScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('تفاصيل النشاط')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(activity.title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.purple)),
          const SizedBox(height: 22),
          Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.calendar_today_outlined), title: const Text('التاريخ'), subtitle: Text('${activity.weekdayLabel}، ${activity.dateLabel}')),
            ListTile(leading: const Icon(Icons.schedule), title: const Text('الوقت'), subtitle: Text(activity.timeLabel, textDirection: TextDirection.ltr)),
            if (activity.place.trim().isNotEmpty)
              ListTile(leading: const Icon(Icons.place_outlined), title: const Text('المكان'), subtitle: Text(activity.place)),
          ])),
          if (activity.details.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('تفاصيل النشاط', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            RichSmartText(activity.details, store: MemberStore.instance, style: const TextStyle(fontSize: 15, height: 1.7)),
          ],
        ]),
      ),
    );
  }
}
