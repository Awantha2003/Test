import 'dart:convert';

/// How a guardian wants one app treated.
enum AppMode {
  /// Normal app: follows schedules and the daily screen-time limit.
  allow,

  /// Never blocked, even during school time or bedtime (e.g. a study app, maps).
  always,

  /// Allowed up to [AppRule.limitMin] minutes a day.
  limit,

  /// Never allowed.
  block,
}

class AppRule {
  const AppRule({this.mode = AppMode.allow, this.limitMin = 60});
  final AppMode mode;
  final int limitMin;

  Map<String, Object?> toMap() => {'mode': mode.name, if (mode == AppMode.limit) 'limitMin': limitMin};

  static AppRule fromMap(Map<String, dynamic>? m) => AppRule(
        mode: AppMode.values.firstWhere((e) => e.name == m?['mode'], orElse: () => AppMode.allow),
        limitMin: (m?['limitMin'] as num?)?.toInt() ?? 60,
      );
}

/// A recurring window during which all normal apps are paused (school time, bedtime).
class TimeWindow {
  const TimeWindow({required this.id, required this.label, required this.days, required this.start, required this.end, this.active = true});
  final String id;
  final String label;
  final List<String> days; // mon..sun
  final String start; // HH:mm
  final String end; // HH:mm; earlier than start = crosses midnight
  final bool active;

  static const weekdays = ['mon', 'tue', 'wed', 'thu', 'fri'];
  static const allDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  static const schoolTime = TimeWindow(id: 'school', label: 'School time', days: weekdays, start: '07:30', end: '13:30');
  static const bedtime = TimeWindow(id: 'bedtime', label: 'Bedtime', days: allDays, start: '21:30', end: '06:00');
  static const studyTime = TimeWindow(id: 'study', label: 'Study time', days: weekdays, start: '18:00', end: '20:00', active: false);

  TimeWindow copyWith({String? label, List<String>? days, String? start, String? end, bool? active}) =>
      TimeWindow(id: id, label: label ?? this.label, days: days ?? this.days, start: start ?? this.start, end: end ?? this.end, active: active ?? this.active);

  Map<String, Object?> toMap() => {'id': id, 'label': label, 'days': days, 'start': start, 'end': end, 'active': active};

  static TimeWindow fromMap(Map<String, dynamic> m) => TimeWindow(
        id: m['id'] as String? ?? 'w',
        label: m['label'] as String? ?? 'Schedule',
        days: List<String>.from(m['days'] as List? ?? const []),
        start: m['start'] as String? ?? '00:00',
        end: m['end'] as String? ?? '00:00',
        active: m['active'] as bool? ?? true,
      );

  static int _minutes(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  /// True if [now] (local time) falls inside this window.
  bool isActiveAt(DateTime now) {
    if (!active) return false;
    final s = _minutes(start), e = _minutes(end), t = now.hour * 60 + now.minute;
    final today = allDays[now.weekday - 1];
    final yesterday = allDays[(now.weekday + 5) % 7];
    if (s == e) return false;
    if (s < e) return days.contains(today) && t >= s && t < e;
    // Crosses midnight: the evening part belongs to today, the morning part to yesterday's window.
    return (days.contains(today) && t >= s) || (days.contains(yesterday) && t < e);
  }
}

class Decision {
  const Decision.allowed() : blocked = false, reason = '';
  const Decision.blocked(this.reason) : blocked = true;
  final bool blocked;
  final String reason;
  @override
  String toString() => blocked ? 'blocked: $reason' : 'allowed';
}

/// The full rule set for one child phone. Mirrored in Kotlin (RuleEngine.kt) for enforcement.
class AppRules {
  const AppRules({this.apps = const {}, this.schedules = const [], this.dailyLimitMin = 0});
  final Map<String, AppRule> apps;
  final List<TimeWindow> schedules;

  /// Total screen time per day across normal apps (0 = no limit).
  final int dailyLimitMin;

  static const empty = AppRules();

  AppRule ruleFor(String pkg) => apps[pkg] ?? const AppRule();

  Decision evaluate(String pkg, DateTime now, {int usedMin = 0, int totalMin = 0}) {
    final rule = ruleFor(pkg);
    if (rule.mode == AppMode.block) return const Decision.blocked('Blocked by your family');
    if (rule.mode == AppMode.always) return const Decision.allowed();
    for (final w in schedules) {
      if (w.isActiveAt(now)) return Decision.blocked('${w.label} (${w.start}–${w.end})');
    }
    if (rule.mode == AppMode.limit && usedMin >= rule.limitMin) {
      return Decision.blocked('Daily limit of ${rule.limitMin} min reached');
    }
    if (dailyLimitMin > 0 && totalMin >= dailyLimitMin) {
      return Decision.blocked('Daily screen time of $dailyLimitMin min used up');
    }
    return const Decision.allowed();
  }

  AppRules copyWith({Map<String, AppRule>? apps, List<TimeWindow>? schedules, int? dailyLimitMin}) =>
      AppRules(apps: apps ?? this.apps, schedules: schedules ?? this.schedules, dailyLimitMin: dailyLimitMin ?? this.dailyLimitMin);

  /// Shape stored in Firestore (`families/{fid}/appRules/{childId}`) and passed to Android.
  Map<String, Object?> toMap() => {
        'apps': {for (final e in apps.entries) if (e.value.mode != AppMode.allow) e.key: e.value.toMap()},
        'schedules': schedules.map((w) => w.toMap()).toList(),
        'dailyLimitMin': dailyLimitMin,
      };

  String toJson() => jsonEncode(toMap());

  static AppRules fromMap(Map<String, dynamic>? m) {
    if (m == null) return empty;
    final apps = <String, AppRule>{};
    (m['apps'] as Map?)?.forEach((k, v) => apps[k as String] = AppRule.fromMap((v as Map?)?.cast<String, dynamic>()));
    return AppRules(
      apps: apps,
      schedules: ((m['schedules'] as List?) ?? const []).map((e) => TimeWindow.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      dailyLimitMin: (m['dailyLimitMin'] as num?)?.toInt() ?? 0,
    );
  }
}
