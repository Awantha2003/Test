import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_rules.dart';

export 'app_rules.dart';

class InstalledApp {
  const InstalledApp(this.pkg, this.name);
  final String pkg;
  final String name;
  Map<String, String> toMap() => {'pkg': pkg, 'name': name};
}

class ControlsStatus {
  const ControlsStatus({required this.supported, required this.usageAccess, required this.accessibility});
  final bool supported;
  final bool usageAccess;
  final bool accessibility;
  bool get ready => supported && usageAccess && accessibility;
  static const unsupported = ControlsStatus(supported: false, usageAccess: false, accessibility: false);
}

/// Dart side of the Android app-control plugin. Every call is a no-op on iOS:
/// Apple only allows this through its Screen Time API, which needs a separate entitlement.
class AppControl {
  static const _channel = MethodChannel('lk.rakawala/app_control');

  static bool get supported => defaultTargetPlatform == TargetPlatform.android;

  static Future<ControlsStatus> status() async {
    if (!supported) return ControlsStatus.unsupported;
    final m = await _channel.invokeMapMethod<String, Object?>('status') ?? const {};
    return ControlsStatus(supported: true, usageAccess: m['usageAccess'] == true, accessibility: m['accessibility'] == true);
  }

  static Future<void> openUsageAccessSettings() => supported ? _channel.invokeMethod('openUsageAccessSettings') : Future.value();
  static Future<void> openAccessibilitySettings() => supported ? _channel.invokeMethod('openAccessibilitySettings') : Future.value();

  /// Apps that appear in the launcher (what the child can actually open).
  static Future<List<InstalledApp>> installedApps() async {
    if (!supported) return const [];
    final list = await _channel.invokeListMethod<Map<Object?, Object?>>('installedApps') ?? const [];
    return list.map((m) => InstalledApp(m['pkg'] as String, (m['name'] as String?) ?? (m['pkg'] as String))).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Foreground minutes per package since local midnight.
  static Future<Map<String, int>> usageTodayMinutes() async {
    if (!supported) return const {};
    final m = await _channel.invokeMapMethod<String, Object?>('usageToday') ?? const {};
    return {for (final e in m.entries) e.key: ((e.value as num) / 60000).round()}..removeWhere((_, v) => v <= 0);
  }

  /// Hands the guardian's rules to the on-device blocker (persisted natively).
  static Future<void> setRules(AppRules rules) => supported ? _channel.invokeMethod('setRules', rules.toJson()) : Future.value();
}
