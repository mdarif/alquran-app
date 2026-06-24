/// The data contract handed to the OS home-screen widget. PURE value objects:
/// no Flutter, no `home_widget`, no platform code — just the shape the native
/// renderer (WidgetKit on iOS, Glance on Android) reads. Keeping it here, plain
/// and serialisable, is what lets the natives only ever RENDER: every minute of
/// prayer-times math (Karachi method + Shafi Asr, the forbidden windows) stays
/// in Dart, computed once and copied out.
///
/// Times are **device-local wall-clock** ISO-8601 strings (no offset). The
/// widget runs on the same device in the same zone, so the native side parses
/// them as local — the simplest unambiguous encoding for v1.
library;

import 'dart:convert';

/// One time marker — a salah or Sunrise. Mirrors the domain's next-marker
/// sequence so the widget can pick "the next marker after now" without
/// recomputing anything. [isSalah] is false only for Sunrise (it bounds the
/// Fajr window; it is not a prayer).
class WidgetMarker {
  const WidgetMarker({
    required this.name,
    required this.isSalah,
    required this.at,
  });

  final String name; // e.g. "Fajr", "Sunrise" — the domain Prayer.label
  final bool isSalah; // Sunrise → false
  final DateTime at; // device-local

  Map<String, dynamic> toJson() => {
        'name': name,
        'isSalah': isSalah,
        'at': at.toIso8601String(),
      };
}

/// One day's ordered markers (Fajr · Sunrise · Dhuhr · Asr · Maghrib · Isha).
class WidgetDay {
  const WidgetDay({required this.date, required this.markers});

  final DateTime date; // local civil date (midnight)
  final List<WidgetMarker> markers;

  Map<String, dynamic> toJson() => {
        'date': _ymd(date),
        'markers': markers.map((m) => m.toJson()).toList(),
      };
}

/// The full payload: a few days of schedule so the native timeline stays correct
/// for the horizon even if the app is never reopened. When no location is set,
/// [hasLocation] is false and [days] is empty (the widget shows a prompt).
class WidgetPayload {
  const WidgetPayload({
    required this.schemaVersion,
    required this.generatedAt,
    required this.hasLocation,
    required this.locationLabel,
    required this.days,
  });

  /// Bump when the JSON shape changes, so a stale native renderer can detect an
  /// incompatible payload instead of misreading it.
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final DateTime generatedAt; // local
  final bool hasLocation;
  final String? locationLabel;
  final List<WidgetDay> days; // today + horizon (empty when !hasLocation)

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'generatedAt': generatedAt.toIso8601String(),
        'hasLocation': hasLocation,
        'locationLabel': locationLabel,
        'days': days.map((d) => d.toJson()).toList(),
      };

  /// The string written to the shared store the native widget reads.
  String encode() => jsonEncode(toJson());
}

/// Zero-padded `YYYY-MM-DD` for the local civil date (no time, no zone).
String _ymd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-$m-$day';
}
