import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../services/push_service.dart';

class ParentShell extends ConsumerStatefulWidget {
  const ParentShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  final _shownSos = <String>{};

  @override
  void initState() {
    super.initState();
    final uid = ref.read(sessionProvider).value?.uid;
    if (uid != null) PushService.registerGuardianDevice(uid);
  }

  @override
  Widget build(BuildContext context) {
    final openSos = ref.watch(openSosProvider);
    // An SOS arriving while the app is open takes over the screen once.
    ref.listen(openSosProvider, (_, next) {
      for (final a in next) {
        if (a.status == 'open' && _shownSos.add(a.id)) {
          context.push('/p/sos/${a.id}');
          break;
        }
      }
    });
    final unread = (ref.watch(alertsProvider).value ?? const []).where((a) => a.createdAt != null && DateTime.now().difference(a.createdAt!) < const Duration(hours: 6)).length;

    return Scaffold(
      body: Column(children: [
        if (openSos.isNotEmpty)
          Material(
            color: AppColors.sos,
            child: SafeArea(
              bottom: false,
              child: ListTile(
                onTap: () => context.push('/p/sos/${openSos.first.id}'),
                leading: const Icon(Icons.sos_rounded, color: Colors.white),
                title: Text(openSos.first.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: const Text('Tap to respond', style: TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ),
          ),
        Expanded(child: MediaQuery.removePadding(context: context, removeTop: openSos.isNotEmpty, child: widget.shell)),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        onDestinationSelected: (i) => widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Map'),
          NavigationDestination(
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_outlined)),
            selectedIcon: const Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          const NavigationDestination(icon: Icon(Icons.place_outlined), selectedIcon: Icon(Icons.place_rounded), label: 'Places'),
          const NavigationDestination(icon: Icon(Icons.family_restroom_outlined), selectedIcon: Icon(Icons.family_restroom_rounded), label: 'Family'),
          const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}
