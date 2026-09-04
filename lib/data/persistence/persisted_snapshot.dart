import 'package:safe_path/data/persistence/json_codecs.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';

/// What one edit made to a student, kept so it survives a restart.
///
/// Only the mutable fields. Names, grades and card UIDs come from the roster
/// and will come from the server; writing a whole copy of the student here
/// would make a stale local file able to resurrect a corrected name.
class StudentOverride {
  const StudentOverride({
    required this.studentId,
    this.stopId,
    this.homeLocation,
    this.homeLabel,
    this.homeLinkSource,
  });

  final String studentId;
  final String? stopId;
  final LatLngPoint? homeLocation;
  final String? homeLabel;

  /// The pasted link the pin came from, kept so a wrong home can be traced to
  /// what was actually shared rather than argued about.
  final String? homeLinkSource;

  bool get isEmpty =>
      stopId == null && homeLocation == null && homeLinkSource == null;

  static StudentOverride? from(Student student, Student seed) {
    final override = StudentOverride(
      studentId: student.id,
      stopId: student.stopId == seed.stopId ? null : student.stopId,
      homeLocation: student.homeLocation,
      homeLabel: student.homeLabel,
      homeLinkSource: student.homeLinkSource,
    );
    return override.isEmpty ? null : override;
  }

  Student applyTo(Student student) => student.copyWith(
        stopId: stopId,
        homeLocation: homeLocation,
        homeLabel: homeLabel,
        homeLinkSource: homeLinkSource,
      );

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'stopId': stopId,
        'homeLocation': encodePoint(homeLocation),
        'homeLabel': homeLabel,
        'homeLinkSource': homeLinkSource,
      };

  static StudentOverride? fromJson(Map<String, dynamic> m) {
    final id = asString(m['studentId']);
    if (id == null) return null;
    return StudentOverride(
      studentId: id,
      stopId: asString(m['stopId']),
      homeLocation: decodePoint(m['homeLocation']),
      homeLabel: asString(m['homeLabel']),
      homeLinkSource: asString(m['homeLinkSource']),
    );
  }
}

/// How far a run had got.
///
/// The plan itself is rebuilt from the routes on every launch — geometry is
/// large, derivable, and the one thing that should follow a corrected route
/// rather than a stale file. Only what actually happened is stored.
class TripProgress {
  const TripProgress({
    required this.tripId,
    required this.status,
    required this.stops,
    this.startedAt,
    this.completedAt,
  });

  final String tripId;
  final TripStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<TripStopProgress> stops;

  static TripProgress from(Trip trip) => TripProgress(
        tripId: trip.id,
        status: trip.status,
        startedAt: trip.startedAt,
        completedAt: trip.completedAt,
        stops: trip.stops.map(TripStopProgress.from).toList(),
      );

  /// Replays what happened onto a freshly planned trip.
  Trip applyTo(Trip trip) {
    final byId = {for (final s in stops) s.stopId: s};
    return trip.copyWith(
      status: status,
      startedAt: startedAt,
      completedAt: completedAt,
      stops: [
        for (final stop in trip.stops) byId[stop.stopId]?.applyTo(stop) ?? stop,
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'status': status.name,
        'startedAt': startedAt == null ? null : encodeTime(startedAt!),
        'completedAt': completedAt == null ? null : encodeTime(completedAt!),
        'stops': stops.map((s) => s.toJson()).toList(),
      };

  static TripProgress? fromJson(Map<String, dynamic> m) {
    final id = asString(m['tripId']);
    final status = decodeEnum(TripStatus.values, m['status']);
    if (id == null || status == null) return null;
    return TripProgress(
      tripId: id,
      status: status,
      startedAt: decodeTime(m['startedAt']),
      completedAt: decodeTime(m['completedAt']),
      stops: decodeList(m['stops'], TripStopProgress.fromJson),
    );
  }
}

class TripStopProgress {
  const TripStopProgress({
    required this.stopId,
    required this.status,
    this.actualArrival,
    this.skipReason,
    this.approachNotified = false,
    this.arrivalNotified = false,
  });

  final String stopId;
  final TripStopStatus status;
  final DateTime? actualArrival;
  final String? skipReason;

  /// Carried across a restart on purpose. Without them a driver who reopens
  /// the app re-sends "the bus is five minutes away" to every guardian on the
  /// route — and a notification that arrives twice is one people learn to
  /// ignore.
  final bool approachNotified;
  final bool arrivalNotified;

  static TripStopProgress from(TripStop stop) => TripStopProgress(
        stopId: stop.stopId,
        status: stop.status,
        actualArrival: stop.actualArrival,
        skipReason: stop.skipReason,
        approachNotified: stop.approachNotified,
        arrivalNotified: stop.arrivalNotified,
      );

  TripStop applyTo(TripStop stop) => stop.copyWith(
        status: status,
        actualArrival: actualArrival,
        skipReason: skipReason,
        approachNotified: approachNotified,
        arrivalNotified: arrivalNotified,
      );

  Map<String, dynamic> toJson() => {
        'stopId': stopId,
        'status': status.name,
        'actualArrival':
            actualArrival == null ? null : encodeTime(actualArrival!),
        'skipReason': skipReason,
        'approachNotified': approachNotified,
        'arrivalNotified': arrivalNotified,
      };

  static TripStopProgress? fromJson(Map<String, dynamic> m) {
    final id = asString(m['stopId']);
    final status = decodeEnum(TripStopStatus.values, m['status']);
    if (id == null || status == null) return null;
    return TripStopProgress(
      stopId: id,
      status: status,
      actualArrival: decodeTime(m['actualArrival']),
      skipReason: asString(m['skipReason']),
      approachNotified: asBool(m['approachNotified']),
      arrivalNotified: asBool(m['arrivalNotified']),
    );
  }
}

/// Everything the app writes down between launches.
///
/// Note what is *not* here: bus positions. A stored position is a position
/// from the past, and the one thing this product must never do is redraw a
/// remembered location as though a bus had just reported it. On a cold start
/// the map has no bus until a real ping arrives, which is the truth.
class PersistedSnapshot {
  const PersistedSnapshot({
    required this.savedAt,
    this.attendanceEvents = const [],
    this.absences = const [],
    this.alerts = const [],
    this.notifications = const [],
    this.auditLog = const [],
    this.studentOverrides = const [],
    this.tripProgress = const [],
    this.localeCode,
    this.themeModeName,
    this.currentUserId,
  });

  /// Bumped only when an old file can no longer be read correctly. A file from
  /// a different version is discarded rather than half-understood.
  static const schemaVersion = 1;

  final DateTime savedAt;
  final List<AttendanceEvent> attendanceEvents;
  final List<AbsenceRecord> absences;
  final List<SafetyAlert> alerts;
  final List<AppNotification> notifications;
  final List<AuditEntry> auditLog;
  final List<StudentOverride> studentOverrides;
  final List<TripProgress> tripProgress;
  final String? localeCode;
  final String? themeModeName;
  final String? currentUserId;

  bool isFromServiceDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final saved = DateTime(savedAt.year, savedAt.month, savedAt.day);
    return saved == day;
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'savedAt': encodeTime(savedAt),
        'attendanceEvents':
            attendanceEvents.map(encodeAttendanceEvent).toList(),
        'absences': absences.map(encodeAbsence).toList(),
        'alerts': alerts.map(encodeAlert).toList(),
        'notifications': notifications.map(encodeNotification).toList(),
        'auditLog': auditLog.map(encodeAudit).toList(),
        'studentOverrides': studentOverrides.map((o) => o.toJson()).toList(),
        'tripProgress': tripProgress.map((t) => t.toJson()).toList(),
        'localeCode': localeCode,
        'themeMode': themeModeName,
        'currentUserId': currentUserId,
      };

  /// Returns null for anything this build cannot read. The caller falls back
  /// to a clean start, which is always safe; a half-decoded safety log is not.
  static PersistedSnapshot? fromJson(Map<String, dynamic> m) {
    if (m['schemaVersion'] != schemaVersion) return null;
    final savedAt = decodeTime(m['savedAt']);
    if (savedAt == null) return null;

    return PersistedSnapshot(
      savedAt: savedAt,
      attendanceEvents:
          decodeList(m['attendanceEvents'], decodeAttendanceEvent),
      absences: decodeList(m['absences'], decodeAbsence),
      alerts: decodeList(m['alerts'], decodeAlert),
      notifications: decodeList(m['notifications'], decodeNotification),
      auditLog: decodeList(m['auditLog'], decodeAudit),
      studentOverrides:
          decodeList(m['studentOverrides'], StudentOverride.fromJson),
      tripProgress: decodeList(m['tripProgress'], TripProgress.fromJson),
      localeCode: asString(m['localeCode']),
      themeModeName: asString(m['themeMode']),
      currentUserId: asString(m['currentUserId']),
    );
  }
}
