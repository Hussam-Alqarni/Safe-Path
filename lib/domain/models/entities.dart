import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/geo.dart';

/// A school. The tenant boundary.
///
/// The pilot runs one school, but every record carries [schoolId] from day one
/// so adding the second school is configuration, not a rewrite.
class School {
  const School({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.location,
    required this.gateLocation,
    required this.dayStartsAt,
    required this.dayEndsAt,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final LatLngPoint location;

  /// Where the gate readers are installed. Distinct from [location] because a
  /// campus can be large enough that the difference matters for geofencing.
  final LatLngPoint gateLocation;

  final ScheduleTime dayStartsAt;
  final ScheduleTime dayEndsAt;
}

/// Wall-clock time of day, timezone-free. Rendered in the school's local zone.
class ScheduleTime {
  const ScheduleTime(this.hour, this.minute);

  final int hour;
  final int minute;

  DateTime onDate(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// The contractor that owns the buses. Schools rarely own their fleet, so the
/// operator is a first-class entity and buses hang off it, not off the school.
class TransportOperator {
  const TransportOperator({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.contactPhone,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String contactPhone;
}

class Bus {
  const Bus({
    required this.id,
    required this.operatorId,
    required this.plateNumber,
    required this.capacity,
    required this.trackerDeviceId,
    this.hasCardReader = true,
  });

  final String id;
  final String operatorId;
  final String plateNumber;
  final int capacity;

  /// IMEI of the in-vehicle tracker. Empty while a bus is being commissioned.
  final String trackerDeviceId;
  final bool hasCardReader;
}

/// Anyone who signs in. One account, one role.
class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.fullNameAr,
    required this.fullNameEn,
    required this.phone,
    required this.schoolId,
    this.linkedStudentIds = const [],
    this.assignedBusId,
  });

  final String id;
  final UserRole role;
  final String fullNameAr;
  final String fullNameEn;
  final String phone;
  final String schoolId;

  /// For guardians: the children they may see. Enforced again in the database.
  final List<String> linkedStudentIds;

  /// For drivers: the bus they are currently assigned to.
  final String? assignedBusId;
}

/// A pickup/drop-off point shared by one or more students.
class BusStop {
  const BusStop({
    required this.id,
    required this.schoolId,
    required this.nameAr,
    required this.nameEn,
    required this.location,
    required this.dwellSeconds,
  });

  final String id;
  final String schoolId;
  final String nameAr;
  final String nameEn;
  final LatLngPoint location;

  /// How long the bus is expected to wait here. Feeds ETA maths.
  final int dwellSeconds;
}

class Student {
  const Student({
    required this.id,
    required this.schoolId,
    required this.fullNameAr,
    required this.fullNameEn,
    required this.grade,
    required this.section,
    required this.guardianIds,
    required this.cardUid,
    this.stopId,
    this.usesBus = true,
    this.photoInitials = '',
    this.homeLocation,
    this.homeLabel,
    this.homeLinkSource,
  });

  final String id;
  final String schoolId;
  final String fullNameAr;
  final String fullNameEn;
  final String grade;
  final String section;
  final List<String> guardianIds;

  /// NFC card UID. Deliberately *not* the identity of the student — attendance
  /// is keyed on [id], so replacing a lost card never breaks their history.
  final String cardUid;

  /// Null for students who are not bus riders. They still appear in gate
  /// attendance, because the gate readers cover the whole school.
  final String? stopId;

  final bool usesBus;
  final String photoInitials;

  /// Where the student actually lives.
  ///
  /// Distinct from the stop: several homes share one pickup point, and the
  /// walk between them is exactly what a guardian needs to judge when to send
  /// their child down. Set from a shared map link rather than typed.
  final LatLngPoint? homeLocation;

  /// Place name carried by the link, when it had one.
  final String? homeLabel;

  /// The original pasted link, kept so a wrong pin can be traced to what was
  /// actually shared rather than argued about.
  final String? homeLinkSource;

  bool get hasHome => homeLocation != null;

  /// Metres from the front door to the pickup point.
  double? walkToStopMetres(BusStop? stop) {
    final home = homeLocation;
    if (home == null || stop == null) return null;
    return home.distanceTo(stop.location);
  }

  Student copyWith({
    String? stopId,
    bool? usesBus,
    LatLngPoint? homeLocation,
    String? homeLabel,
    String? homeLinkSource,
  }) {
    return Student(
      id: id,
      schoolId: schoolId,
      fullNameAr: fullNameAr,
      fullNameEn: fullNameEn,
      grade: grade,
      section: section,
      guardianIds: guardianIds,
      cardUid: cardUid,
      stopId: stopId ?? this.stopId,
      usesBus: usesBus ?? this.usesBus,
      photoInitials: photoInitials,
      homeLocation: homeLocation ?? this.homeLocation,
      homeLabel: homeLabel ?? this.homeLabel,
      homeLinkSource: homeLinkSource ?? this.homeLinkSource,
    );
  }
}

/// A named, ordered sequence of stops served by one bus.
class BusRoute {
  const BusRoute({
    required this.id,
    required this.schoolId,
    required this.busId,
    required this.driverId,
    required this.nameAr,
    required this.nameEn,
    required this.direction,
    required this.orderedStopIds,
    required this.departureTime,
  });

  final String id;
  final String schoolId;
  final String busId;
  final String driverId;
  final String nameAr;
  final String nameEn;
  final TripDirection direction;

  /// The default plan. A trip may skip entries but never reorders them
  /// arbitrarily — guardians wait at known stops in a known sequence.
  final List<String> orderedStopIds;

  final ScheduleTime departureTime;
}

/// One stop within one trip, with its own live state.
class TripStop {
  const TripStop({
    required this.stopId,
    required this.sequence,
    required this.status,
    required this.expectedStudentIds,
    this.plannedArrival,
    this.actualArrival,
    this.skipReason,
    this.distanceAlongRouteMetres = 0,
    this.approachNotified = false,
    this.arrivalNotified = false,
  });

  final String stopId;
  final int sequence;
  final TripStopStatus status;

  /// Students expected to board/alight here today, after absences are applied.
  final List<String> expectedStudentIds;

  final DateTime? plannedArrival;
  final DateTime? actualArrival;

  /// Populated when [status] is skipped. The stop is retained, never deleted.
  final String? skipReason;

  /// Where this stop sits along the trip's path. Drives ETA and the
  /// "bus is 5 minutes away" trigger.
  final double distanceAlongRouteMetres;

  final bool approachNotified;
  final bool arrivalNotified;

  TripStop copyWith({
    TripStopStatus? status,
    List<String>? expectedStudentIds,
    DateTime? plannedArrival,
    DateTime? actualArrival,
    String? skipReason,
    double? distanceAlongRouteMetres,
    bool? approachNotified,
    bool? arrivalNotified,
  }) {
    return TripStop(
      stopId: stopId,
      sequence: sequence,
      status: status ?? this.status,
      expectedStudentIds: expectedStudentIds ?? this.expectedStudentIds,
      plannedArrival: plannedArrival ?? this.plannedArrival,
      actualArrival: actualArrival ?? this.actualArrival,
      skipReason: skipReason ?? this.skipReason,
      distanceAlongRouteMetres:
          distanceAlongRouteMetres ?? this.distanceAlongRouteMetres,
      approachNotified: approachNotified ?? this.approachNotified,
      arrivalNotified: arrivalNotified ?? this.arrivalNotified,
    );
  }
}

/// One run of one route on one date.
class Trip {
  const Trip({
    required this.id,
    required this.schoolId,
    required this.routeId,
    required this.busId,
    required this.driverId,
    required this.direction,
    required this.serviceDate,
    required this.status,
    required this.stops,
    required this.path,
    this.startedAt,
    this.completedAt,
    this.distanceCoveredMetres = 0,
    this.lastPingAt,
  });

  final String id;
  final String schoolId;
  final String routeId;
  final String busId;
  final String driverId;
  final TripDirection direction;

  /// Calendar date in the school's local timezone.
  final DateTime serviceDate;

  final TripStatus status;
  final List<TripStop> stops;

  /// Road geometry for today's plan. Recomputed when stops are skipped.
  final RoutePath path;

  final DateTime? startedAt;
  final DateTime? completedAt;

  /// How far along [path] the bus currently is.
  final double distanceCoveredMetres;

  final DateTime? lastPingAt;

  TripStop? get nextStop {
    for (final stop in stops) {
      if (stop.status == TripStopStatus.pending ||
          stop.status == TripStopStatus.arrived) {
        return stop;
      }
    }
    return null;
  }

  List<TripStop> get activeStops =>
      stops.where((s) => s.status != TripStopStatus.skipped).toList();

  /// Every student the bus is responsible for on this run.
  Set<String> get expectedStudentIds =>
      activeStops.expand((s) => s.expectedStudentIds).toSet();

  Trip copyWith({
    TripStatus? status,
    List<TripStop>? stops,
    RoutePath? path,
    DateTime? startedAt,
    DateTime? completedAt,
    double? distanceCoveredMetres,
    DateTime? lastPingAt,
  }) {
    return Trip(
      id: id,
      schoolId: schoolId,
      routeId: routeId,
      busId: busId,
      driverId: driverId,
      direction: direction,
      serviceDate: serviceDate,
      status: status ?? this.status,
      stops: stops ?? this.stops,
      path: path ?? this.path,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      distanceCoveredMetres:
          distanceCoveredMetres ?? this.distanceCoveredMetres,
      lastPingAt: lastPingAt ?? this.lastPingAt,
    );
  }
}

/// An immutable attendance fact. Append-only: records are never edited or
/// deleted, only superseded. A safety log that can be rewritten is worthless.
class AttendanceEvent {
  const AttendanceEvent({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.type,
    required this.method,
    required this.occurredAt,
    this.tripId,
    this.stopId,
    this.recordedByUserId,
    this.manualReason,
    this.location,
    this.guardianConfirmation = GuardianConfirmation.pending,
  });

  final String id;
  final String schoolId;
  final String studentId;
  final AttendanceEventType type;
  final VerificationMethod method;
  final DateTime occurredAt;

  /// Null for gate events — those belong to the school, not to a bus run.
  final String? tripId;
  final String? stopId;

  /// Who entered it, for manual records.
  final String? recordedByUserId;
  final ManualEntryReason? manualReason;

  /// Where the device was when the record was made. Evidence, not decoration.
  final LatLngPoint? location;

  final GuardianConfirmation guardianConfirmation;

  bool get isManual => method.isManual;

  AttendanceEvent copyWith({GuardianConfirmation? guardianConfirmation}) {
    return AttendanceEvent(
      id: id,
      schoolId: schoolId,
      studentId: studentId,
      type: type,
      method: method,
      occurredAt: occurredAt,
      tripId: tripId,
      stopId: stopId,
      recordedByUserId: recordedByUserId,
      manualReason: manualReason,
      location: location,
      guardianConfirmation: guardianConfirmation ?? this.guardianConfirmation,
    );
  }
}

/// A declared or observed absence for one student on one date.
class AbsenceRecord {
  const AbsenceRecord({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.serviceDate,
    required this.reason,
    required this.declaredAt,
    required this.declaredByUserId,
    this.direction,
    this.note,
  });

  final String id;
  final String schoolId;
  final String studentId;
  final DateTime serviceDate;
  final AbsenceReason reason;
  final DateTime declaredAt;
  final String declaredByUserId;

  /// Null means "both runs today".
  final TripDirection? direction;

  final String? note;

  bool appliesTo(TripDirection tripDirection) =>
      direction == null || direction == tripDirection;
}

/// A detected anomaly. Produced by the safety engine, never entered by hand.
class SafetyAlert {
  const SafetyAlert({
    required this.id,
    required this.schoolId,
    required this.kind,
    required this.raisedAt,
    required this.titleAr,
    required this.titleEn,
    required this.detailAr,
    required this.detailEn,
    this.studentId,
    this.tripId,
    this.busId,
    this.acknowledgedAt,
    this.acknowledgedByUserId,
  });

  final String id;
  final String schoolId;
  final SafetyAlertKind kind;
  final DateTime raisedAt;
  final String titleAr;
  final String titleEn;
  final String detailAr;
  final String detailEn;
  final String? studentId;
  final String? tripId;
  final String? busId;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByUserId;

  AlertSeverity get severity => kind.severity;
  bool get isOpen => acknowledgedAt == null;

  SafetyAlert copyWith({
    DateTime? acknowledgedAt,
    String? acknowledgedByUserId,
  }) {
    return SafetyAlert(
      id: id,
      schoolId: schoolId,
      kind: kind,
      raisedAt: raisedAt,
      titleAr: titleAr,
      titleEn: titleEn,
      detailAr: detailAr,
      detailEn: detailEn,
      studentId: studentId,
      tripId: tripId,
      busId: busId,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedByUserId: acknowledgedByUserId ?? this.acknowledgedByUserId,
    );
  }
}

/// A message delivered to a guardian (push in production).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.schoolId,
    required this.recipientUserId,
    required this.kind,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.sentAt,
    this.studentId,
    this.attendanceEventId,
    this.requiresConfirmation = false,
    this.readAt,
  });

  final String id;
  final String schoolId;
  final String recipientUserId;
  final NotificationKind kind;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final DateTime sentAt;
  final String? studentId;

  /// Set when this notification reports a manual attendance record the
  /// guardian can confirm or dispute.
  final String? attendanceEventId;
  final bool requiresConfirmation;

  final DateTime? readAt;

  bool get isUnread => readAt == null;

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
        id: id,
        schoolId: schoolId,
        recipientUserId: recipientUserId,
        kind: kind,
        titleAr: titleAr,
        titleEn: titleEn,
        bodyAr: bodyAr,
        bodyEn: bodyEn,
        sentAt: sentAt,
        studentId: studentId,
        attendanceEventId: attendanceEventId,
        requiresConfirmation: requiresConfirmation,
        readAt: readAt ?? this.readAt,
      );
}

/// One line in the access audit trail.
///
/// Privileged access to a child's location data is logged without exception —
/// this is what makes the developer role defensible under PDPL rather than a
/// silent back door.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.schoolId,
    required this.actorUserId,
    required this.actorRole,
    required this.action,
    required this.occurredAt,
    this.subjectStudentId,
    this.detail,
  });

  final String id;
  final String schoolId;
  final String actorUserId;
  final UserRole actorRole;
  final String action;
  final DateTime occurredAt;
  final String? subjectStudentId;
  final String? detail;
}

/// A single position report from a vehicle tracker.
class BusPing {
  const BusPing({
    required this.busId,
    required this.tripId,
    required this.position,
    required this.speedKmh,
    required this.heading,
    required this.recordedAt,
    required this.distanceAlongRouteMetres,
  });

  final String busId;
  final String tripId;
  final LatLngPoint position;
  final double speedKmh;
  final double heading;
  final DateTime recordedAt;

  /// Snapped position along the planned path — computed at ingest so every
  /// consumer sees the same road-matched value.
  final double distanceAlongRouteMetres;
}
