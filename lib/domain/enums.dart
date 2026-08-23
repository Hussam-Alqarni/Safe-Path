/// Domain enumerations for Safe Path.
///
/// Every enum here is persisted by name, never by index — reordering a value
/// must never silently rewrite historical records.
library;

/// Who is using the app. Permissions are derived from this, and enforced again
/// server-side; the client role is a convenience, never the security boundary.
enum UserRole {
  guardian,
  driver,
  schoolAdmin,
  schoolStaff,
  developer;

  bool get canSeeAllStudents =>
      this == schoolAdmin || this == schoolStaff || this == developer;

  bool get canEditStudents => this == schoolAdmin || this == developer;

  bool get canManageRoutes => this == schoolAdmin || this == developer;

  bool get canRecordAttendance =>
      this == driver || this == schoolStaff || this == schoolAdmin;

  /// Only the developer role may impersonate. Every impersonation session is
  /// written to the audit log and expires automatically.
  bool get canImpersonate => this == developer;

  bool get canSeeAuditLog => this == schoolAdmin || this == developer;

  bool get canSeeSystemDiagnostics => this == developer;
}

/// Direction of a scheduled run.
enum TripDirection {
  /// Morning pickup: homes to school.
  toSchool,

  /// Afternoon drop-off: school to homes.
  fromSchool,
}

/// Lifecycle of one bus run on one date.
enum TripStatus {
  scheduled,
  inProgress,
  completed,
  cancelled;

  bool get isActive => this == inProgress;
}

/// Lifecycle of a single stop within a trip.
enum TripStopStatus {
  /// Not reached yet.
  pending,

  /// Deliberately skipped — every assigned student was marked absent.
  /// The stop is never deleted, only marked, so the plan stays auditable.
  skipped,

  /// Bus is currently at the stop.
  arrived,

  /// Bus has left the stop.
  departed;

  bool get isDone => this == departed || this == skipped;
}

/// The four moments Safe Path records for a student.
enum AttendanceEventType {
  /// Tapped the reader inside the bus, boarding.
  boardedBus,

  /// Tapped the reader inside the bus, alighting.
  alightedBus,

  /// Tapped the reader at the school gate, entering the grounds.
  enteredSchool,

  /// Tapped the reader at the school gate, leaving the grounds.
  exitedSchool;

  bool get isBusEvent => this == boardedBus || this == alightedBus;
  bool get isGateEvent => this == enteredSchool || this == exitedSchool;
}

/// How an attendance record came to exist. Surfaced to guardians verbatim —
/// a manual record must never be presented as if the card was scanned.
enum VerificationMethod {
  /// The student tapped their own NFC card. The trusted path.
  nfcCard,

  /// The driver recorded it by hand — forgotten card, broken reader.
  manualDriver,

  /// School staff recorded it by hand at the gate.
  manualStaff;

  bool get isManual => this != nfcCard;
}

/// Why an attendance record had to be entered by hand.
enum ManualEntryReason {
  forgottenCard,
  damagedCard,
  readerFault,
  other,
}

/// A guardian's response to a manual attendance notification. Their denial is
/// a second verification layer and a legal record.
enum GuardianConfirmation {
  pending,
  confirmed,
  disputed,
}

/// Why a student is not on the bus today.
enum AbsenceReason {
  /// Guardian declared the absence ahead of time.
  declaredByGuardian,

  /// Bus reached the stop, student never boarded.
  noShowAtStop,

  /// Another party is transporting the student today.
  alternativeTransport,
}

/// Where a student is in the day's journey. Derived from the event log —
/// never stored directly, so it can never drift from the underlying facts.
enum JourneyStage {
  notStarted,
  onMorningBus,
  arrivedAtSchool,
  insideSchool,
  leftSchoolGrounds,
  onAfternoonBus,
  deliveredHome,
  absent,
  noShow,
}

/// Safety anomalies detected by [reconcile]-style checks.
/// Ordered most severe first — the UI relies on this ordering.
enum SafetyAlertKind {
  /// Boarded and the trip ended without them alighting. The alert this whole
  /// product exists to raise.
  leftOnBus,

  /// Alighted at school but never tapped the gate reader. The gap between the
  /// bus door and the school door.
  missingGateEntry,

  /// Left the school grounds but never boarded the afternoon bus.
  leftSchoolNotOnBus,

  /// Tracker has gone quiet mid-trip.
  trackerSilent,

  /// This driver's manual-entry rate is abnormal — broken reader, or worse.
  highManualRate,
}

/// Severity drives colour, sort order, and whether an alert pages someone.
enum AlertSeverity {
  critical,
  warning,
  info,
}

extension SafetyAlertKindX on SafetyAlertKind {
  AlertSeverity get severity => switch (this) {
        SafetyAlertKind.leftOnBus => AlertSeverity.critical,
        SafetyAlertKind.missingGateEntry => AlertSeverity.critical,
        SafetyAlertKind.leftSchoolNotOnBus => AlertSeverity.warning,
        SafetyAlertKind.trackerSilent => AlertSeverity.warning,
        SafetyAlertKind.highManualRate => AlertSeverity.info,
      };
}

/// Categories of guardian-facing notification.
enum NotificationKind {
  boarded,
  alighted,
  enteredSchool,
  exitedSchool,
  busApproaching,
  busArrived,
  manualAttendance,
  absenceRecorded,
  noShow,
  safetyAlert,
  tripStarted,
  tripCompleted,
}
