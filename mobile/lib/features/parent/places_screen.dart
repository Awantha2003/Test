import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/providers.dart';
import '../../widgets/common.dart';

class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(placesProvider);
    final schedules = ref.watch(schedulesProvider).value ?? const [];
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Safe places')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/p/place'), icon: const Icon(Icons.add_location_alt_rounded), label: const Text('Add place')),
      body: AsyncView(
        value: places,
        builder: (list) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
          Card(
            color: t.colorScheme.primaryContainer,
            child: ListTile(
              onTap: () => context.push('/p/schedules'),
              leading: Icon(Icons.alarm_on_rounded, color: t.colorScheme.onPrimaryContainer),
              title: Text('Class & school schedules', style: TextStyle(fontWeight: FontWeight.w700, color: t.colorScheme.onPrimaryContainer)),
              subtitle: Text(
                schedules.isEmpty ? 'Get alerted if they haven\'t arrived on time' : '${schedules.length} active schedule${schedules.length == 1 ? '' : 's'}',
                style: TextStyle(color: t.colorScheme.onPrimaryContainer),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: t.colorScheme.onPrimaryContainer),
            ),
          ),
          const SectionHeader('Places'),
          if (list.isEmpty)
            const EmptyState(icon: Icons.add_location_alt_rounded, title: 'No places yet', message: 'Add home, school and tuition classes to get arrive and leave alerts.')
          else
            for (final p in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    onTap: () => context.push('/p/place', extra: p),
                    leading: CircleAvatar(backgroundColor: t.colorScheme.primaryContainer, child: Icon(p.type.icon, color: t.colorScheme.onPrimaryContainer)),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${p.type.label} · ${p.radius} m · ${[if (p.notifyEnter) 'arrive', if (p.notifyExit) 'leave'].join(' & ')} alerts'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
        ]),
      ),
    );
  }
}
