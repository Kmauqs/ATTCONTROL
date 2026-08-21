import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/app_repository.dart';
import '../../attendance/domain/attendance_models.dart';

class PresenceScreen extends ConsumerWidget {
  const PresenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(appRepositoryProvider).presenceToday(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data!;
        int n(PresenceKind k) => rows.where((r) => r.kind == k).length;
        return RefreshIndicator(
          onRefresh: () async => (context as Element).markNeedsBuild(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _chip('Presentes', n(PresenceKind.presente), AppColors.ok),
                  _chip('Tarde', n(PresenceKind.tarde), Colors.orange),
                  _chip('Ausentes', n(PresenceKind.ausente), AppColors.late),
                ],
              ),
              const SizedBox(height: 12),
              ...rows.map((r) {
                final color = switch (r.kind) {
                  PresenceKind.presente => AppColors.ok,
                  PresenceKind.tarde => Colors.orange,
                  PresenceKind.ausente => AppColors.late,
                };
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Text(r.profile.initials),
                    ),
                    title: Text(r.profile.fullName),
                    subtitle: Text(
                      '${r.profile.cargo ?? ''} · ${r.kind.name}',
                    ),
                    trailing: r.lastMark == null
                        ? const Text('—')
                        : Text(DateFormat('HH:mm').format(r.lastMark!.markedAt)),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, int n, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              '$n',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
