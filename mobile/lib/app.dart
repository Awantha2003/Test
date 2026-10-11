import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'data/providers.dart';
import 'services/app_lock.dart';
import 'services/push_service.dart';

class RakawalaApp extends ConsumerStatefulWidget {
  const RakawalaApp({super.key});
  @override
  ConsumerState<RakawalaApp> createState() => _RakawalaAppState();
}

class _RakawalaAppState extends ConsumerState<RakawalaApp> {
  StreamSubscription<Map<String, dynamic>>? _taps;

  @override
  void initState() {
    super.initState();
    _taps = PushService.taps.listen((data) {
      final router = ref.read(routerProvider);
      final alertId = data['alertId'] as String?;
      if (data['type'] == 'sos' && alertId != null) {
        router.push('/p/sos/$alertId');
      } else {
        router.go('/p/alerts');
      }
    });
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Rakawala',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      builder: (context, child) => LockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Blocks the guardian UI behind biometrics/PIN when app lock is on.
/// Child devices are never locked: SOS must always be one tap away.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _checking = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _maybeLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _backgroundedAt = DateTime.now();
    if (state == AppLifecycleState.resumed && _backgroundedAt != null && DateTime.now().difference(_backgroundedAt!) > const Duration(minutes: 2)) {
      _maybeLock();
    }
  }

  Future<void> _maybeLock() async {
    final session = ref.read(sessionProvider).value;
    if (session != null && session.isChild) return;
    if (await AppLock.isEnabled()) {
      setState(() => _locked = true);
      await _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_checking) return;
    _checking = true;
    final ok = await AppLock.unlock();
    _checking = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    final t = Theme.of(context);
    return Stack(children: [
      widget.child,
      Positioned.fill(
        child: Material(
          color: t.colorScheme.surface,
          child: SafeArea(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shield_rounded, size: 72, color: t.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Rakawala is locked', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                FilledButton.icon(onPressed: _unlock, icon: const Icon(Icons.fingerprint), label: const Text('Unlock')),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
