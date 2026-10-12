import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../widgets/common.dart';

(IconData, Color) alertStyle(AlertType t) => switch (t) {
      AlertType.sos => (Icons.sos_rounded, AppColors.sos),
      AlertType.enter => (Icons.login_rounded, AppColors.safe),
      AlertType.exit => (Icons.logout_rounded, AppColors.brand),
      AlertType.late => (Icons.alarm_rounded, AppColors.warn),
      AlertType.battery => (Icons.battery_alert_rounded, AppColors.warn),
      AlertType.offline => (Icons.signal_wifi_off_rounded, AppColors.warn),
      AlertType.speed => (Icons.speed_rounded, AppColors.warn),
      AlertType.checkin => (Icons.verified_user_rounded, AppColors.safe),
      AlertType.apps => (Icons.apps_rounded, AppColors.brand),
    };

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});
  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  AlertType? _filter;

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(alertsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final f in <AlertType?>[null, AlertType.sos, AlertType.enter, AlertType.exit, AlertType.late, AlertType.battery, AlertType.offline])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f == null ? 'All' : switch (f) { AlertType.enter => 'Arrived', AlertType.exit => 'Left', _ => f.name[0].toUpperCase() + f.name.substring(1) }),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
              ),
          ]),
        ),
        Expanded(
          child: AsyncView(
            value: alerts,
            builder: (list) {
              final items = _filter == null ? list : list.where((a) => a.type == _filter).toList();
              if (items.isEmpty) {
                return const EmptyState(icon: Icons.notifications_none_rounded, title: 'All quiet', message: "You'll see arrivals, departures and safety alerts here.");
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => AlertTile(alert: items[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class AlertTile extends StatelessWidget {
  const AlertTile({super.key, required this.alert});
  final AlertItem alert;
  @override
  Widget build(BuildContext context) {
    final (icon, color) = alertStyle(alert.type);
    final t = Theme.of(context);
    return Card(
      color: alert.isOpenSos ? AppColors.sos.withValues(alpha: 0.08) : null,
      child: ListTile(
        onTap: alert.type == AlertType.sos ? () => context.push('/p/sos/${alert.id}') : null,
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
        title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${alert.body}\n${timeAgo(alert.createdAt)}'),
        isThreeLine: true,
        trailing: alert.isOpenSos
            ? Chip(label: const Text('OPEN'), labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), backgroundColor: AppColors.sos, side: BorderSide.none, visualDensity: VisualDensity.compact)
            : alert.type == AlertType.sos
                ? Icon(Icons.check_circle_rounded, color: t.colorScheme.outline)
                : null,
      ),
    );
  }
}
