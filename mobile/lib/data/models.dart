import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

DateTime? _ts(Object? v) => v is Timestamp ? v.toDate() : null;
double _d(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;

Color parseHex(String? hex, [Color fallback = const Color(0xFF2563EB)]) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return fallback;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

class Session {
  const Session({required this.uid, required this.role, this.familyId, this.email, this.emailVerified = true, this.isAdmin = false});
  final String uid;
  final String? role; // parent | child | null (not set up yet)
  final String? familyId;
  final String? email;
  final bool emailVerified;
  final bool isAdmin;

  bool get isParent => role == 'parent' && familyId != null;
  bool get isChild => role == 'child' && familyId != null;
}

class Family {
  Family({required this.id, required this.name, required this.ownerUid, required this.planId, required this.planStatus, this.planRenewsAt, required this.limits});
  final String id;
  final String name;
  final String ownerUid;
  final String planId;
  final String planStatus;
  final DateTime? planRenewsAt;
  final Map<String, dynamic> limits;

  factory Family.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Family(
      id: d.id,
      name: m['name'] as String? ?? 'My family',
      ownerUid: m['ownerUid'] as String? ?? '',
      planId: m['planId'] as String? ?? 'free',
      planStatus: m['planStatus'] as String? ?? 'active',
      planRenewsAt: _ts(m['planRenewsAt']),
      limits: Map<String, dynamic>.from(m['limits'] as Map? ?? {}),
    );
  }

  bool get isPaid => planId != 'free';
  bool get smsSos => limits['smsSos'] == true;
  bool get voiceSos => limits['voiceSos'] == true;
  bool get appControls => limits['appControls'] == true;
}

class ChildSettings {
  const ChildSettings({this.speedLimitKmh = 70, this.lowBatteryPct = 15, this.guardMode = true, this.voiceSos = false, this.safeWord = '', this.offlineAlertMin = 45});
  final int speedLimitKmh;
  final int lowBatteryPct;
  final bool guardMode;
  final bool voiceSos;
  final String safeWord;
  final int offlineAlertMin;

  factory ChildSettings.fromMap(Map<String, dynamic>? m) => ChildSettings(
        speedLimitKmh: (m?['speedLimitKmh'] as num?)?.toInt() ?? 70,
        lowBatteryPct: (m?['lowBatteryPct'] as num?)?.toInt() ?? 15,
        guardMode: m?['guardMode'] as bool? ?? true,
        voiceSos: m?['voiceSos'] as bool? ?? false,
        safeWord: m?['safeWord'] as String? ?? '',
        offlineAlertMin: (m?['offlineAlertMin'] as num?)?.toInt() ?? 45,
      );

  Map<String, dynamic> toMap() => {
        'speedLimitKmh': speedLimitKmh,
        'lowBatteryPct': lowBatteryPct,
        'guardMode': guardMode,
        'voiceSos': voiceSos,
        'safeWord': safeWord,
        'offlineAlertMin': offlineAlertMin,
      };

  ChildSettings copyWith({int? speedLimitKmh, int? lowBatteryPct, bool? guardMode, bool? voiceSos, String? safeWord, int? offlineAlertMin}) => ChildSettings(
        speedLimitKmh: speedLimitKmh ?? this.speedLimitKmh,
        lowBatteryPct: lowBatteryPct ?? this.lowBatteryPct,
        guardMode: guardMode ?? this.guardMode,
        voiceSos: voiceSos ?? this.voiceSos,
        safeWord: safeWord ?? this.safeWord,
        offlineAlertMin: offlineAlertMin ?? this.offlineAlertMin,
      );
}

class Child {
  Child({required this.id, required this.name, required this.color, required this.paired, this.deviceName, this.platform, required this.settings, this.liveUntil});
  final String id;
  final String name;
  final Color color;
  final bool paired;
  final String? deviceName;
  final String? platform;
  final ChildSettings settings;

  /// While set and in the future, the child's phone sends fast (~5 s) updates for a guardian's live view.
  final DateTime? liveUntil;
  bool get isLive => liveUntil != null && liveUntil!.isAfter(DateTime.now());

  String get initials => name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();

  factory Child.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Child(
      id: d.id,
      name: m['name'] as String? ?? 'Child',
      color: parseHex(m['color'] as String?),
      paired: m['paired'] as bool? ?? false,
      deviceName: m['deviceName'] as String?,
      platform: m['platform'] as String?,
      settings: ChildSettings.fromMap((m['settings'] as Map?)?.cast<String, dynamic>()),
      liveUntil: _ts(m['liveUntil']),
    );
  }
}

class LiveLocation {
  LiveLocation({required this.childId, required this.lat, required this.lng, required this.accuracy, this.speed, this.heading, this.battery, this.charging = false, this.ts});
  final String childId;
  final double lat;
  final double lng;
  final double accuracy;
  final double? speed;
  final double? heading;
  final int? battery;
  final bool charging;
  final DateTime? ts;

  Duration? get age => ts == null ? null : DateTime.now().difference(ts!);
  bool get isStale => (age ?? const Duration(days: 1)) > const Duration(minutes: 20);

  factory LiveLocation.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return LiveLocation(
      childId: d.id,
      lat: _d(m['lat']),
      lng: _d(m['lng']),
      accuracy: _d(m['accuracy'], 999),
      speed: (m['speed'] as num?)?.toDouble(),
      heading: (m['heading'] as num?)?.toDouble(),
      battery: (m['battery'] as num?)?.toInt(),
      charging: m['charging'] as bool? ?? false,
      ts: _ts(m['ts']),
    );
  }
}

enum PlaceType { home, school, classroom, relative, other }

extension PlaceTypeX on PlaceType {
  String get wire => this == PlaceType.classroom ? 'class' : name;
  String get label => switch (this) {
        PlaceType.home => 'Home',
        PlaceType.school => 'School',
        PlaceType.classroom => 'Tuition class',
        PlaceType.relative => 'Relative',
        PlaceType.other => 'Other',
      };
  IconData get icon => switch (this) {
        PlaceType.home => Icons.home_rounded,
        PlaceType.school => Icons.school_rounded,
        PlaceType.classroom => Icons.menu_book_rounded,
        PlaceType.relative => Icons.family_restroom_rounded,
        PlaceType.other => Icons.place_rounded,
      };
  static PlaceType parse(String? s) => s == 'class' ? PlaceType.classroom : PlaceType.values.firstWhere((t) => t.name == s, orElse: () => PlaceType.other);
}

class Place {
  Place({required this.id, required this.name, required this.type, required this.lat, required this.lng, required this.radius, this.notifyEnter = true, this.notifyExit = true});
  final String id;
  final String name;
  final PlaceType type;
  final double lat;
  final double lng;
  final int radius;
  final bool notifyEnter;
  final bool notifyExit;

  factory Place.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Place(
      id: d.id,
      name: m['name'] as String? ?? 'Place',
      type: PlaceTypeX.parse(m['type'] as String?),
      lat: _d(m['lat']),
      lng: _d(m['lng']),
      radius: (m['radius'] as num?)?.toInt() ?? 150,
      notifyEnter: m['notifyEnter'] as bool? ?? true,
      notifyExit: m['notifyExit'] as bool? ?? true,
    );
  }
}

class Schedule {
  Schedule({required this.id, required this.childId, required this.placeId, required this.label, required this.days, required this.arriveBy, this.graceMin = 10, this.active = true});
  final String id;
  final String childId;
  final String placeId;
  final String label;
  final List<String> days;
  final String arriveBy;
  final int graceMin;
  final bool active;

  factory Schedule.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Schedule(
      id: d.id,
      childId: m['childId'] as String? ?? '',
      placeId: m['placeId'] as String? ?? '',
      label: m['label'] as String? ?? 'Class',
      days: List<String>.from(m['days'] as List? ?? const []),
      arriveBy: m['arriveBy'] as String? ?? '08:00',
      graceMin: (m['graceMin'] as num?)?.toInt() ?? 10,
      active: m['active'] as bool? ?? true,
    );
  }
}

enum AlertType { sos, enter, exit, late, battery, offline, speed, checkin, apps, device }

class AlertItem {
  AlertItem({required this.id, required this.type, required this.childId, required this.childName, required this.title, required this.body, this.lat, this.lng, this.createdAt, required this.status});
  final String id;
  final AlertType type;
  final String childId;
  final String childName;
  final String title;
  final String body;
  final double? lat;
  final double? lng;
  final DateTime? createdAt;
  final String status; // open | acknowledged | resolved | info

  bool get isOpenSos => type == AlertType.sos && (status == 'open' || status == 'acknowledged');

  factory AlertItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AlertItem(
      id: d.id,
      type: AlertType.values.firstWhere((t) => t.name == m['type'], orElse: () => AlertType.checkin),
      childId: m['childId'] as String? ?? '',
      childName: m['childName'] as String? ?? '',
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      createdAt: _ts(m['createdAt']),
      status: m['status'] as String? ?? 'info',
    );
  }
}

class Member {
  Member({required this.uid, required this.role, required this.name, this.phone, this.owner = false});
  final String uid;
  final String role;
  final String name;
  final String? phone;
  final bool owner;

  factory Member.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Member(uid: d.id, role: m['role'] as String? ?? 'parent', name: m['name'] as String? ?? '', phone: m['phone'] as String?, owner: m['owner'] as bool? ?? false);
  }
}

class Plan {
  Plan({required this.id, required this.name, required this.priceLkr, required this.interval, required this.features, this.highlight = false, required this.order});
  final String id;
  final String name;
  final num priceLkr;
  final String interval;
  final List<String> features;
  final bool highlight;
  final int order;

  factory Plan.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Plan(
      id: d.id,
      name: m['name'] as String? ?? d.id,
      priceLkr: m['priceLkr'] as num? ?? 0,
      interval: m['interval'] as String? ?? 'month',
      features: List<String>.from(m['features'] as List? ?? const []),
      highlight: m['highlight'] as bool? ?? false,
      order: (m['order'] as num?)?.toInt() ?? 99,
    );
  }
}

class HistoryPoint {
  HistoryPoint(this.lat, this.lng, this.ts);
  final double lat;
  final double lng;
  final DateTime? ts;
  factory HistoryPoint.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return HistoryPoint(_d(m['lat']), _d(m['lng']), _ts(m['ts']));
  }
}
