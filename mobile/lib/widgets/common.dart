import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/api.dart';

/// Run an async action with a spinner-safe error snackbar.
Future<T?> runGuarded<T>(BuildContext context, Future<T> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final r = await action();
    if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    return r;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Something went wrong. ${e is Exception ? '' : e}')));
  }
  return null;
}

String timeAgo(DateTime? t) {
  if (t == null) return 'never';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 45) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return DateFormat('d MMM, h:mm a').format(t);
}

class ChildAvatar extends StatelessWidget {
  const ChildAvatar({super.key, required this.label, required this.color, this.size = 44, this.ring});
  final String label;
  final Color color;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: ring ?? Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Color(0x33000000), offset: Offset(0, 2))],
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.4)),
      );
}

class BatteryBadge extends StatelessWidget {
  const BatteryBadge({super.key, required this.level, this.charging = false});
  final int? level;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    if (level == null) return const SizedBox.shrink();
    final low = level! <= 15 && !charging;
    final icon = charging
        ? Icons.battery_charging_full_rounded
        : level! > 80
            ? Icons.battery_full_rounded
            : level! > 40
                ? Icons.battery_5_bar_rounded
                : level! > 15
                    ? Icons.battery_3_bar_rounded
                    : Icons.battery_alert_rounded;
    final color = low ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 2),
      Text('$level%', style: TextStyle(fontSize: 12, color: color, fontWeight: low ? FontWeight.w700 : FontWeight.w500)),
    ]);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: t.colorScheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: t.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          ?trailing,
        ]),
      );
}

class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  @override
  Widget build(BuildContext context) => value.when(
        data: builder,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.cloud_off_rounded, title: "Couldn't load", message: e is StateError ? 'Please sign in again.' : 'Check your connection and try again.'),
      );
}
