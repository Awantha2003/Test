import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../services/background_service.dart';
import '../../services/offline_trail.dart';
import '../../services/permissions.dart';
import '../../services/sos_service.dart';
import '../../services/voice_guard.dart';
import '../../widgets/common.dart';
import '../../widgets/offline_window_sheet.dart';
import 'sos_button.dart';

/// The child's screen: deliberately simple. A huge SOS button, "I'm safe", call a parent.
class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});
  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen> with WidgetsBindingObserver {
  SharingReadiness? _readiness;
  bool _sharing = false;
  int _pendingTrail = 0;
  bool _sending = false;
  VoiceGuard? _voice;
  String _voiceStatus = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voice?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final r = await Permissions.check();
    if (r == SharingReadiness.ready || r == SharingReadiness.needsAlways) {
      await BackgroundSharing.start();
    }
    final running = await BackgroundSharing.isRunning();
    final pending = await OfflineTrailBuffer().count();
    if (mounted) {
      setState(() {
        _readiness = r;
        _sharing = running;
        _pendingTrail = pending;
      });
    }
  }

  Future<void> _noSignalAhead() async {
    final w = await showOfflineWindowSheet(context, title: 'No signal ahead?');
    if (w == null || !mounted) return;
    await runGuarded(
      context,
      () => ref.read(apiProvider).setOfflineWindow(minutes: w.minutes, reason: w.reason),
      success: 'Your family knows you may be offline for ${durationLabel(w.minutes)}.',
    );
  }

  Future<void> _sos(String source) async {
    if (_sending) return;
    setState(() => _sending = true);
    final child = ref.read(myChildProvider).value;
    final guardians = ref.read(guardiansProvider).value ?? const <Member>[];
    final outcome = await SosService(ref.read(apiProvider)).trigger(source: source, guardians: guardians, childName: child?.name ?? 'Your child');
    if (!mounted) return;
    setState(() => _sending = false);
    final msg = switch (outcome) {
      SosOutcome.sentOnline => 'SOS sent. Your family has been alerted.',
      SosOutcome.smsFallback => 'No internet: send the SMS that just opened.',
      SosOutcome.failed => 'Could not send. Call ${AppConfig.policeEmergency} now.',
    };
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(outcome == SosOutcome.failed ? Icons.error_rounded : Icons.check_circle_rounded, color: outcome == SosOutcome.failed ? AppColors.sos : AppColors.safe, size: 48),
        title: Text(outcome == SosOutcome.failed ? 'SOS not sent' : 'Help is coming'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => SosService.call(AppConfig.policeEmergency), child: const Text('Call 119')),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _checkIn() async {
    Position? p;
    try {
      p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 6)));
    } catch (_) {}
    if (!mounted) return;
    await runGuarded(context, () => ref.read(apiProvider).checkIn(lat: p?.latitude, lng: p?.longitude), success: 'Your family knows you are safe ✅');
  }

  Future<void> _toggleVoice(Child child) async {
    if (_voice?.active ?? false) {
      await _voice!.stop();
      setState(() => _voice = null);
      return;
    }
    await Permissions.requestMicrophone();
    final v = VoiceGuard(
      safeWord: child.settings.safeWord,
      onTriggered: () => _sos('voice'),
      onStatus: (s) => mounted ? setState(() => _voiceStatus = s) : null,
    );
    final ok = await v.start();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice guard is not available on this phone.')));
      return;
    }
    setState(() => _voice = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final child = ref.watch(myChildProvider).value;
    final guardians = ref.watch(guardiansProvider).value ?? const <Member>[];
    final voiceAllowed = (child?.settings.voiceSos ?? false) && (child?.settings.safeWord.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi ${child?.name ?? ''} 👋'),
        actions: [_SharingPill(on: _sharing)],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          if (child?.isLive ?? false)
            Card(
              color: AppColors.brand.withValues(alpha: 0.1),
              child: const ListTile(
                leading: Icon(Icons.radar_rounded, color: AppColors.brand),
                title: Text('Your family is viewing your live location'),
                subtitle: Text('Updates are faster for a few minutes so they can find you.'),
              ),
            ),
          if (_readiness != null && _readiness != SharingReadiness.ready) _PermissionCard(readiness: _readiness!, onDone: _refresh),
          const SizedBox(height: 12),
          Center(child: SosButton(busy: _sending, onTriggered: () => _sos('button'))),
          const SizedBox(height: 8),
          Center(child: Text('Press and hold for 2 seconds', style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant))),
          const SizedBox(height: 28),
          FilledButton.tonalIcon(
            onPressed: _checkIn,
            icon: const Icon(Icons.verified_user_rounded),
            label: const Text("I'm safe"),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58), backgroundColor: AppColors.safe.withValues(alpha: 0.15), foregroundColor: AppColors.safe),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _noSignalAhead,
            icon: const Icon(Icons.signal_cellular_off_rounded),
            label: const Text('No signal ahead? (train, trip)'),
          ),
          if (_pendingTrail > 0) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_upload_rounded),
                title: Text('$_pendingTrail location${_pendingTrail == 1 ? '' : 's'} saved offline'),
                subtitle: const Text('They upload automatically when you have signal again.'),
              ),
            ),
          ],
          if (voiceAllowed && child != null) ...[
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                value: _voice?.active ?? false,
                onChanged: (_) => _toggleVoice(child),
                secondary: Icon((_voice?.active ?? false) ? Icons.mic_rounded : Icons.mic_none_rounded, color: (_voice?.active ?? false) ? AppColors.sos : null),
                title: const Text('Voice guard'),
                subtitle: Text((_voice?.active ?? false)
                    ? 'Listening for your secret word${_voiceStatus.isNotEmpty ? ' · $_voiceStatus' : ''}. Keep this screen open.'
                    : 'Say your secret word to send SOS hands-free. Turn on when walking alone.'),
              ),
            ),
          ],
          const SectionHeader('Call'),
          ...guardians.where((g) => (g.phone ?? '').isNotEmpty).map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                    title: Text(g.name),
                    trailing: IconButton.filledTonal(icon: const Icon(Icons.call_rounded), onPressed: () => SosService.call(g.phone!)),
                  ),
                ),
              )),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => SosService.call(AppConfig.policeEmergency), icon: const Icon(Icons.local_police_rounded), label: const Text('Police 119'))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(onPressed: () => SosService.call(AppConfig.childHelpline), icon: const Icon(Icons.support_agent_rounded), label: const Text('Child line 1929'))),
          ]),
        ]),
      ),
    );
  }
}

class _SharingPill extends StatelessWidget {
  const _SharingPill({required this.on});
  final bool on;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Chip(
          avatar: Icon(on ? Icons.location_on_rounded : Icons.location_off_rounded, size: 18, color: on ? AppColors.safe : AppColors.warn),
          label: Text(on ? 'Sharing' : 'Not sharing'),
          visualDensity: VisualDensity.compact,
        ),
      );
}

/// Prominent disclosure required by Google Play before requesting background location.
class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.readiness, required this.onDone});
  final SharingReadiness readiness;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final (title, body, action) = switch (readiness) {
      SharingReadiness.serviceOff => ('Turn on location', 'Your phone\'s location is switched off, so your family can\'t see where you are.', 'Open settings'),
      SharingReadiness.denied => ('Location is blocked', 'Open settings → Permissions → Location → "Allow all the time".', 'Open settings'),
      SharingReadiness.needsAlways => ('Allow "all the time"', 'Rakawala collects your location even when the app is closed or not in use, so your family is alerted if something goes wrong on the way to school or class.', 'Allow'),
      _ => ('Share your location', 'Rakawala collects your location even when the app is closed or not in use, to show it to your family and send safety alerts. It is never sold or used for ads.', 'Allow'),
    };
    return Card(
      color: AppColors.warn.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              if (readiness == SharingReadiness.serviceOff) {
                await Geolocator.openLocationSettings();
              } else if (readiness == SharingReadiness.denied) {
                await Permissions.openSettings();
              } else {
                await Permissions.request();
              }
              await onDone();
            },
            child: Text(action),
          ),
        ]),
      ),
    );
  }
}
