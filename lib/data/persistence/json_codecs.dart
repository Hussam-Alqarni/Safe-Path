import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';

/// Wire format for everything the app keeps between launches.
///
/// Deliberately hand-written and deliberately outside `lib/domain/`. The
/// entities describe what the product *is*; this file describes one way of
/// writing them down, and a stored file outlives the code that wrote it. A
/// generator would hide exactly the decisions that matter here — that enums
/// travel by name, that an unknown name is dropped rather than guessed, and
/// that a field added later must not invalidate a file written today.
///
/// Reading is total: every decoder returns null instead of throwing, and the
/// list helper skips the entries that fail. A single corrupt record must cost
/// that record, never the whole safety log.

// ── primitives ─────────────────────────────────────────────────────────────

Map<String, dynamic>? asMap(Object? value) =>
    value is Map<String, dynamic> ? value : null;

String? asString(Object? value) => value is String ? value : null;

double? asDouble(Object? value) => value is num ? value.toDouble() : null;

bool asBool(Object? value, {bool fallback = false}) =>
    value is bool ? value : fallback;

/// UTC ISO-8601. Times are stored absolute and rendered local: a school that
/// crosses a daylight-saving boundary must not shift its own attendance log.
String encodeTime(DateTime at) => at.toUtc().toIso8601String();

DateTime? decodeTime(Object? value) {
  final text = asString(value);
  if (text == null) return null;
  return DateTime.tryParse(text)?.toLocal();
}

/// Enums travel by name. An unrecognised name means the file was written by a
/// newer build; the record is dropped rather than silently mapped to whatever
/// happens to sit at that index.
T? decodeEnum<T extends Enum>(List<T> values, Object? value) {
  final name = asString(value);
  if (name == null) return null;
  for (final candidate in values) {
    if (candidate.name == name) return candidate;
  }
  return null;
}

Map<String, dynamic>? encodePoint(LatLngPoint? point) =>
    point == null ? null : {'lat': point.latitude, 'lng': point.longitude};

LatLngPoint? decodePoint(Object? value) {
  final map = asMap(value);
  final lat = asDouble(map?['lat']);
  final lng = asDouble(map?['lng']);
  if (lat == null || lng == null) return null;
  return LatLngPoint(lat, lng);
}

/// Decodes a list, dropping entries that cannot be read.
List<T> decodeList<T>(Object? value, T? Function(Map<String, dynamic>) one) {
  if (value is! List) return const [];
  final out = <T>[];
  for (final entry in value) {
    final map = asMap(entry);
    if (map == null) continue;
    final decoded = one(map);
    if (decoded != null) out.add(decoded);
  }
  return out;
}

// ── attendance ─────────────────────────────────────────────────────────────

Map<String, dynamic> encodeAttendanceEvent(AttendanceEvent e) => {
      'id': e.id,
      'schoolId': e.schoolId,
      'studentId': e.studentId,
      'type': e.type.name,
      'method': e.method.name,
      'occurredAt': encodeTime(e.occurredAt),
      'tripId': e.tripId,
      'stopId': e.stopId,
      'recordedByUserId': e.recordedByUserId,
      'manualReason': e.manualReason?.name,
      'location': encodePoint(e.location),
      'guardianConfirmation': e.guardianConfirmation.name,
    };

AttendanceEvent? decodeAttendanceEvent(Map<String, dynamic> m) {
  final id = asString(m['id']);
  final schoolId = asString(m['schoolId']);
  final studentId = asString(m['studentId']);
  final type = decodeEnum(AttendanceEventType.values, m['type']);
  final method = decodeEnum(VerificationMethod.values, m['method']);
  final occurredAt = decodeTime(m['occurredAt']);
  if (id == null ||
      schoolId == null ||
      studentId == null ||
      type == null ||
      method == null ||
      occurredAt == null) {
    return null;
  }

  return AttendanceEvent(
    id: id,
    schoolId: schoolId,
    studentId: studentId,
    type: type,
    method: method,
    occurredAt: occurredAt,
    tripId: asString(m['tripId']),
    stopId: asString(m['stopId']),
    recordedByUserId: asString(m['recordedByUserId']),
    manualReason: decodeEnum(ManualEntryReason.values, m['manualReason']),
    location: decodePoint(m['location']),
    guardianConfirmation:
        decodeEnum(GuardianConfirmation.values, m['guardianConfirmation']) ??
            GuardianConfirmation.pending,
  );
}

// ── absences ───────────────────────────────────────────────────────────────

Map<String, dynamic> encodeAbsence(AbsenceRecord a) => {
      'id': a.id,
      'schoolId': a.schoolId,
      'studentId': a.studentId,
      'serviceDate': encodeTime(a.serviceDate),
      'reason': a.reason.name,
      'declaredAt': encodeTime(a.declaredAt),
      'declaredByUserId': a.declaredByUserId,
      'direction': a.direction?.name,
      'note': a.note,
    };

AbsenceRecord? decodeAbsence(Map<String, dynamic> m) {
  final id = asString(m['id']);
  final schoolId = asString(m['schoolId']);
  final studentId = asString(m['studentId']);
  final serviceDate = decodeTime(m['serviceDate']);
  final reason = decodeEnum(AbsenceReason.values, m['reason']);
  final declaredAt = decodeTime(m['declaredAt']);
  final declaredBy = asString(m['declaredByUserId']);
  if (id == null ||
      schoolId == null ||
      studentId == null ||
      serviceDate == null ||
      reason == null ||
      declaredAt == null ||
      declaredBy == null) {
    return null;
  }

  return AbsenceRecord(
    id: id,
    schoolId: schoolId,
    studentId: studentId,
    // Absences are compared against a midnight-local key, so the calendar day
    // is what survives the round trip, not the instant it was written.
    serviceDate: DateTime(serviceDate.year, serviceDate.month, serviceDate.day),
    reason: reason,
    declaredAt: declaredAt,
    declaredByUserId: declaredBy,
    direction: decodeEnum(TripDirection.values, m['direction']),
    note: asString(m['note']),
  );
}

// ── alerts ─────────────────────────────────────────────────────────────────

Map<String, dynamic> encodeAlert(SafetyAlert a) => {
      'id': a.id,
      'schoolId': a.schoolId,
      'kind': a.kind.name,
      'raisedAt': encodeTime(a.raisedAt),
      'titleAr': a.titleAr,
      'titleEn': a.titleEn,
      'detailAr': a.detailAr,
      'detailEn': a.detailEn,
      'studentId': a.studentId,
      'tripId': a.tripId,
      'busId': a.busId,
      'acknowledgedAt':
          a.acknowledgedAt == null ? null : encodeTime(a.acknowledgedAt!),
      'acknowledgedByUserId': a.acknowledgedByUserId,
    };

SafetyAlert? decodeAlert(Map<String, dynamic> m) {
  final id = asString(m['id']);
  final schoolId = asString(m['schoolId']);
  final kind = decodeEnum(SafetyAlertKind.values, m['kind']);
  final raisedAt = decodeTime(m['raisedAt']);
  if (id == null || schoolId == null || kind == null || raisedAt == null) {
    return null;
  }

  return SafetyAlert(
    id: id,
    schoolId: schoolId,
    kind: kind,
    raisedAt: raisedAt,
    titleAr: asString(m['titleAr']) ?? '',
    titleEn: asString(m['titleEn']) ?? '',
    detailAr: asString(m['detailAr']) ?? '',
    detailEn: asString(m['detailEn']) ?? '',
    studentId: asString(m['studentId']),
    tripId: asString(m['tripId']),
    busId: asString(m['busId']),
    acknowledgedAt: decodeTime(m['acknowledgedAt']),
    acknowledgedByUserId: asString(m['acknowledgedByUserId']),
  );
}

// ── notifications ──────────────────────────────────────────────────────────

Map<String, dynamic> encodeNotification(AppNotification n) => {
      'id': n.id,
      'schoolId': n.schoolId,
      'recipientUserId': n.recipientUserId,
      'kind': n.kind.name,
      'titleAr': n.titleAr,
      'titleEn': n.titleEn,
      'bodyAr': n.bodyAr,
      'bodyEn': n.bodyEn,
      'sentAt': encodeTime(n.sentAt),
      'studentId': n.studentId,
      'attendanceEventId': n.attendanceEventId,
      'requiresConfirmation': n.requiresConfirmation,
      'readAt': n.readAt == null ? null : encodeTime(n.readAt!),
    };

AppNotification? decodeNotification(Map<String, dynamic> m) {
  final id = asString(m['id']);
  final schoolId = asString(m['schoolId']);
  final recipient = asString(m['recipientUserId']);
  final kind = decodeEnum(NotificationKind.values, m['kind']);
  final sentAt = decodeTime(m['sentAt']);
  if (id == null ||
      schoolId == null ||
      recipient == null ||
      kind == null ||
      sentAt == null) {
    return null;
  }

  return AppNotification(
    id: id,
    schoolId: schoolId,
    recipientUserId: recipient,
    kind: kind,
    titleAr: asString(m['titleAr']) ?? '',
    titleEn: asString(m['titleEn']) ?? '',
    bodyAr: asString(m['bodyAr']) ?? '',
    bodyEn: asString(m['bodyEn']) ?? '',
    sentAt: sentAt,
    studentId: asString(m['studentId']),
    attendanceEventId: asString(m['attendanceEventId']),
    requiresConfirmation: asBool(m['requiresConfirmation']),
    readAt: decodeTime(m['readAt']),
  );
}

// ── audit ──────────────────────────────────────────────────────────────────

Map<String, dynamic> encodeAudit(AuditEntry a) => {
      'id': a.id,
      'schoolId': a.schoolId,
      'actorUserId': a.actorUserId,
      'actorRole': a.actorRole.name,
      'action': a.action,
      'occurredAt': encodeTime(a.occurredAt),
      'subjectStudentId': a.subjectStudentId,
      'detail': a.detail,
    };

AuditEntry? decodeAudit(Map<String, dynamic> m) {
  final id = asString(m['id']);
  final schoolId = asString(m['schoolId']);
  final actor = asString(m['actorUserId']);
  final role = decodeEnum(UserRole.values, m['actorRole']);
  final action = asString(m['action']);
  final occurredAt = decodeTime(m['occurredAt']);
  if (id == null ||
      schoolId == null ||
      actor == null ||
      role == null ||
      action == null ||
      occurredAt == null) {
    return null;
  }

  return AuditEntry(
    id: id,
    schoolId: schoolId,
    actorUserId: actor,
    actorRole: role,
    action: action,
    occurredAt: occurredAt,
    subjectStudentId: asString(m['subjectStudentId']),
    detail: asString(m['detail']),
  );
}
