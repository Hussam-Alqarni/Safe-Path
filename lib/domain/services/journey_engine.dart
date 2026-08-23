import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';

/// Where one student stands today, derived purely from the event log.
class StudentDaySnapshot {
  const StudentDaySnapshot({
    required this.studentId,
    required this.stage,
    required this.events,
    required this.openAlerts,
    this.absence,
  });

  final String studentId;
  final JourneyStage stage;

  /// Today's events, oldest first.
  final List<AttendanceEvent> events;

  final List<SafetyAlert> openAlerts;
  final AbsenceRecord? absence;

  DateTime? get lastEventAt => events.isEmpty ? null : events.last.occurredAt;

  AttendanceEvent? get lastEvent => events.isEmpty ? null : events.last;

  bool get isOnBoard =>
      stage == JourneyStage.onMorningBus ||
      stage == JourneyStage.onAfternoonBus;

  bool get isSafelyResolved =>
      stage == JourneyStage.deliveredHome ||
      stage == JourneyStage.insideSchool ||
      stage == JourneyStage.absent;

  bool get hasCriticalAlert =>
      openAlerts.any((a) => a.severity == AlertSeverity.critical);
}

/// Derives student state and detects safety anomalies.
///
/// Everything here is a pure function of the event log. Nothing is cached and
/// nothing is stored, so the displayed state can never drift from the facts
/// that produced it — which is exactly the property a safety system needs.
class JourneyEngine {
  const JourneyEngine({this.gateEntryGrace = const Duration(minutes: 10)});

  /// How long a student may take to walk from the bus door to the gate reader
  /// before the gap is treated as an anomaly.
  final Duration gateEntryGrace;

  /// Builds today's snapshot for one student.
  StudentDaySnapshot snapshotFor({
    required String studentId,
    required List<AttendanceEvent> allEvents,
    required List<SafetyAlert> allAlerts,
    AbsenceRecord? absence,
  }) {
    final events = allEvents.where((e) => e.studentId == studentId).toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    final alerts = allAlerts
        .where((a) => a.studentId == studentId && a.isOpen)
        .toList()
      ..sort((a, b) => a.severity.index.compareTo(b.severity.index));

    return StudentDaySnapshot(
      studentId: studentId,
      stage: _deriveStage(events: events, absence: absence),
      events: events,
      openAlerts: alerts,
      absence: absence,
    );
  }

  /// The state machine. Later events always win, so a replayed or late-arriving
  /// record cannot move a student backwards through their day.
  JourneyStage _deriveStage({
    required List<AttendanceEvent> events,
    required AbsenceRecord? absence,
  }) {
    if (events.isEmpty) {
      if (absence == null) return JourneyStage.notStarted;
      return absence.reason == AbsenceReason.noShowAtStop
          ? JourneyStage.noShow
          : JourneyStage.absent;
    }

    var stage = JourneyStage.notStarted;
    var hasReachedSchool = false;

    for (final event in events) {
      switch (event.type) {
        case AttendanceEventType.boardedBus:
          // The same event type means different things before and after the
          // school day: morning pickup vs. afternoon drop-off.
          stage = hasReachedSchool
              ? JourneyStage.onAfternoonBus
              : JourneyStage.onMorningBus;
        case AttendanceEventType.alightedBus:
          if (stage == JourneyStage.onAfternoonBus) {
            stage = JourneyStage.deliveredHome;
          } else {
            stage = JourneyStage.arrivedAtSchool;
          }
        case AttendanceEventType.enteredSchool:
          stage = JourneyStage.insideSchool;
          hasReachedSchool = true;
        case AttendanceEventType.exitedSchool:
          stage = JourneyStage.leftSchoolGrounds;
          hasReachedSchool = true;
      }
    }
    return stage;
  }

  /// Runs when a trip is closed out.
  ///
  /// This is the check the whole product exists for: anyone who boarded and
  /// never alighted is still on that bus.
  List<SafetyAlert> reconcileTripCompletion({
    required Trip trip,
    required List<AttendanceEvent> allEvents,
    required Map<String, Student> studentsById,
    required DateTime now,
    required String Function() idFactory,
  }) {
    final alerts = <SafetyAlert>[];
    final tripEvents = allEvents.where((e) => e.tripId == trip.id).toList();

    final boarded = <String>{};
    final alighted = <String>{};
    for (final event in tripEvents) {
      if (event.type == AttendanceEventType.boardedBus) {
        boarded.add(event.studentId);
      } else if (event.type == AttendanceEventType.alightedBus) {
        alighted.add(event.studentId);
      }
    }

    final stillOnBoard = boarded.difference(alighted);
    for (final studentId in stillOnBoard) {
      final student = studentsById[studentId];
      final nameAr = student?.fullNameAr ?? studentId;
      final nameEn = student?.fullNameEn ?? studentId;
      alerts.add(
        SafetyAlert(
          id: idFactory(),
          schoolId: trip.schoolId,
          kind: SafetyAlertKind.leftOnBus,
          raisedAt: now,
          titleAr: 'طالب لم يسجّل نزوله',
          titleEn: 'Student never scanned off',
          detailAr: 'انتهت الرحلة و$nameAr سجّل صعوده ولم يسجّل نزوله. '
              'افحص الحافلة فوراً قبل إقفالها.',
          detailEn: '$nameEn boarded and the trip ended with no matching '
              'alight scan. Check the bus before it is locked.',
          studentId: studentId,
          tripId: trip.id,
          busId: trip.busId,
        ),
      );
    }
    return alerts;
  }

  /// Students who alighted at school but never tapped the gate reader.
  ///
  /// Covers the gap between the bus door and the school door — a window the
  /// bus reader alone cannot see.
  List<SafetyAlert> detectMissingGateEntries({
    required Trip trip,
    required List<AttendanceEvent> allEvents,
    required Map<String, Student> studentsById,
    required DateTime now,
    required String Function() idFactory,
  }) {
    if (trip.direction != TripDirection.toSchool) return const [];

    final alerts = <SafetyAlert>[];
    final alightedAt = <String, DateTime>{};
    final enteredSchool = <String>{};

    for (final event in allEvents) {
      if (event.tripId == trip.id &&
          event.type == AttendanceEventType.alightedBus) {
        alightedAt[event.studentId] = event.occurredAt;
      }
      if (event.type == AttendanceEventType.enteredSchool) {
        enteredSchool.add(event.studentId);
      }
    }

    for (final entry in alightedAt.entries) {
      if (enteredSchool.contains(entry.key)) continue;
      if (now.difference(entry.value) < gateEntryGrace) continue;

      final student = studentsById[entry.key];
      final nameAr = student?.fullNameAr ?? entry.key;
      final nameEn = student?.fullNameEn ?? entry.key;
      final minutes = now.difference(entry.value).inMinutes;

      alerts.add(
        SafetyAlert(
          id: idFactory(),
          schoolId: trip.schoolId,
          kind: SafetyAlertKind.missingGateEntry,
          raisedAt: now,
          titleAr: 'طالب نزل ولم يدخل المدرسة',
          titleEn: 'Student off the bus, not through the gate',
          detailAr: 'نزل $nameAr من الحافلة قبل $minutes دقيقة '
              'ولم يسجّل دخوله من بوابة المدرسة.',
          detailEn: '$nameEn left the bus $minutes minutes ago and has not '
              'scanned in at the school gate.',
          studentId: entry.key,
          tripId: trip.id,
          busId: trip.busId,
        ),
      );
    }
    return alerts;
  }

  /// Students expected at a departed stop who never boarded.
  ///
  /// Not an alarm — a fact the school and the guardian both need promptly.
  List<String> studentsWhoDidNotBoard({
    required Trip trip,
    required TripStop stop,
    required List<AttendanceEvent> allEvents,
  }) {
    final boarded = allEvents
        .where(
          (e) =>
              e.tripId == trip.id &&
              e.type == AttendanceEventType.boardedBus &&
              e.stopId == stop.stopId,
        )
        .map((e) => e.studentId)
        .toSet();

    return stop.expectedStudentIds
        .where((id) => !boarded.contains(id))
        .toList();
  }

  /// Share of a driver's records entered by hand. A persistently high rate
  /// means a broken reader — or something that needs a human to look at it.
  double manualEntryRate(List<AttendanceEvent> events) {
    if (events.isEmpty) return 0;
    final manual = events.where((e) => e.isManual).length;
    return manual / events.length;
  }
}
