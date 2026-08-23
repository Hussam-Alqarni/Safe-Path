import 'dart:async';

import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/config/app_config.dart';
import 'package:safe_path/data/repositories/app_state.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/data/simulation/simulated_fleet.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';
import 'package:safe_path/domain/services/eta_engine.dart';
import 'package:safe_path/domain/services/fleet_event_source.dart';
import 'package:safe_path/domain/services/journey_engine.dart';
import 'package:safe_path/domain/services/route_planner.dart';
import 'package:uuid/uuid.dart';

/// Orchestrates everything above the domain engines.
///
/// In the pilot this logic lives on the server and the app is a thin client.
/// It is written here first because the rules are identical either way, and
/// proving them against a simulated fleet is far faster than proving them
/// against a bus.
class SafePathController extends StateNotifier<AppState> {
  SafePathController({
    required AppConfig config,
    FleetEventSource? eventSource,
  })  : _planner = const RoutePlanner(LocalGeometryRoutingService()),
        _journey = JourneyEngine(
          gateEntryGrace: Duration(minutes: config.gateEntryGraceMinutes),
        ),
        _eta = EtaEngine(
          approachThreshold:
              Duration(minutes: config.approachNotificationMinutes),
        ),
        _source = eventSource ??
            SimulatedFleet(tickInterval: const Duration(milliseconds: 900)),
        super(_initialState(config));

  final RoutePlanner _planner;
  final JourneyEngine _journey;
  final EtaEngine _eta;
  final FleetEventSource _source;
  final _uuid = const Uuid();

  StreamSubscription<FleetEvent>? _subscription;
  Timer? _staleTimer;

  String _id() => _uuid.v4();

  static AppState _initialState(AppConfig config) => AppState(
        config: config,
        school: SeedData.school,
        trips: const [],
        attendanceEvents: const [],
        absences: const [],
        alerts: const [],
        notifications: const [],
        auditLog: const [],
        liveByBus: const {},
        currentUser: SeedData.demoGuardian,
        locale: const Locale('ar'),
        themeMode: ThemeMode.system,
      );

  // ── lifecycle ────────────────────────────────────────────────────────────

  /// Builds today's trips and wires up the telemetry stream.
  Future<void> bootstrap() async {
    final today = DateTime.now();
    final serviceDate = DateTime(today.year, today.month, today.day);

    final trips = <Trip>[];
    for (final route in SeedData.routes) {
      // Only the morning runs are built at start-up; the afternoon pair is
      // created when the school day ends, exactly as a scheduler would.
      if (route.direction != TripDirection.toSchool) continue;
      trips.add(
        await _planner.buildTrip(
          tripId: 'trip-${route.id}',
          route: route,
          stopsById: SeedData.stopsById,
          students: SeedData.students,
          absences: state.absences,
          schoolLocation: SeedData.school.location,
          serviceDate: serviceDate,
        ),
      );
    }

    state = state.copyWith(trips: trips);

    await _subscription?.cancel();
    _subscription = _source.events.listen(_onFleetEvent);

    _staleTimer?.cancel();
    _staleTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _markStale());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _staleTimer?.cancel();
    unawaited(_source.stop());
    super.dispose();
  }

  // ── trips ────────────────────────────────────────────────────────────────

  Future<void> startTrip(String tripId) async {
    final trip = state.tripById(tripId);
    if (trip == null || trip.status != TripStatus.scheduled) return;

    final now = DateTime.now();
    _replaceTrip(
      trip.copyWith(status: TripStatus.inProgress, startedAt: now),
    );

    for (final studentId in trip.expectedStudentIds) {
      _notifyGuardians(
        studentId: studentId,
        kind: NotificationKind.tripStarted,
        titleAr: 'انطلقت الحافلة',
        titleEn: 'The bus has departed',
        bodyAr: 'انطلقت حافلة ${_busPlate(trip.busId)} في طريقها.',
        bodyEn: 'Bus ${_busPlate(trip.busId)} has started its route.',
        at: now,
      );
    }

    await _source.start(state.activeTrips);
    state = state.copyWith(simulationRunning: _source.isRunning);
  }

  /// Closes a trip and runs the reconciliation that this product exists for.
  Future<void> endTrip(String tripId) async {
    final trip = state.tripById(tripId);
    if (trip == null || trip.status != TripStatus.inProgress) return;

    final now = DateTime.now();
    final completed = trip.copyWith(
      status: TripStatus.completed,
      completedAt: now,
      stops: trip.stops
          .map(
            (s) => s.status.isDone
                ? s
                : s.copyWith(status: TripStopStatus.departed),
          )
          .toList(),
    );
    _replaceTrip(completed);

    final raised = _journey.reconcileTripCompletion(
      trip: completed,
      allEvents: state.attendanceEvents,
      studentsById: SeedData.studentsById,
      now: now,
      idFactory: _id,
    );

    if (raised.isNotEmpty) {
      state = state.copyWith(alerts: [...state.alerts, ...raised]);
      for (final alert in raised) {
        final studentId = alert.studentId;
        if (studentId == null) continue;
        _notifyGuardians(
          studentId: studentId,
          kind: NotificationKind.safetyAlert,
          titleAr: alert.titleAr,
          titleEn: alert.titleEn,
          bodyAr: alert.detailAr,
          bodyEn: alert.detailEn,
          at: now,
        );
      }
    }

    if (state.activeTrips.isEmpty) {
      await _source.stop();
      state = state.copyWith(simulationRunning: false);
    }
  }

  // ── telemetry ────────────────────────────────────────────────────────────

  void _onFleetEvent(FleetEvent event) {
    switch (event) {
      case PositionReport(:final ping):
        _applyPing(ping);
      case CardScanReport():
        _applyCardScan(event);
      case TrackerSilentReport():
        _applyTrackerSilence(event);
    }
  }

  void _applyPing(BusPing ping) {
    final trip = state.tripById(ping.tripId);
    if (trip == null || trip.status != TripStatus.inProgress) return;

    final previous = state.liveByBus[ping.busId];
    final live = BusLiveState(
      busId: ping.busId,
      tripId: ping.tripId,
      position: ping.position,
      previousPosition: previous?.position ?? ping.position,
      speedKmh: ping.speedKmh,
      heading: ping.heading,
      distanceAlongRouteMetres: ping.distanceAlongRouteMetres,
      updatedAt: ping.recordedAt,
    );

    var advanced = trip.copyWith(
      distanceCoveredMetres: ping.distanceAlongRouteMetres,
      lastPingAt: ping.recordedAt,
    );

    advanced = _applyStopProgress(advanced, ping.recordedAt);

    state = state.copyWith(
      liveByBus: {...state.liveByBus, ping.busId: live},
    );
    _replaceTrip(advanced);
  }

  /// Advances stop status and fires the approach and arrival notifications.
  Trip _applyStopProgress(Trip trip, DateTime now) {
    final etas = _eta.etasFor(
      trip: trip,
      currentSpeedKmh: state.liveByBus[trip.busId]?.speedKmh ?? 0,
      now: now,
    );
    final triggers = _eta.evaluateTriggers(trip: trip, etas: etas, now: now);
    if (triggers.isEmpty) return trip;

    final etaByStop = {for (final e in etas) e.stopId: e};
    final updatedStops = <TripStop>[];

    for (final stop in trip.stops) {
      var next = stop;

      if (triggers.approaching.contains(stop.stopId)) {
        next = next.copyWith(approachNotified: true);
        final minutes = etaByStop[stop.stopId]?.minutesAway ?? 5;
        _notifyStopStudents(
          trip: trip,
          stop: stop,
          kind: NotificationKind.busApproaching,
          titleAr: 'الحافلة تقترب',
          titleEn: 'The bus is nearly there',
          bodyAr:
              'تصل الحافلة إلى ${_stopName(stop.stopId)} خلال $minutes دقائق تقريباً.',
          bodyEn:
              'The bus reaches ${_stopNameEn(stop.stopId)} in about $minutes minutes.',
          at: now,
        );
      }

      if (triggers.arrived.contains(stop.stopId)) {
        next = next.copyWith(
          arrivalNotified: true,
          status: TripStopStatus.arrived,
          actualArrival: now,
        );
        _notifyStopStudents(
          trip: trip,
          stop: stop,
          kind: NotificationKind.busArrived,
          titleAr: 'وصلت الحافلة',
          titleEn: 'The bus has arrived',
          bodyAr: 'الحافلة الآن عند ${_stopName(stop.stopId)}.',
          bodyEn: 'The bus is at ${_stopNameEn(stop.stopId)} now.',
          at: now,
        );
      }

      // A stop the bus has clearly driven past counts as departed, so the next
      // one becomes current even if no explicit driver action arrived.
      if (next.status == TripStopStatus.arrived &&
          trip.distanceCoveredMetres >
              next.distanceAlongRouteMetres + _eta.arrivalRadiusMetres) {
        next = next.copyWith(status: TripStopStatus.departed);
      }

      updatedStops.add(next);
    }
    return trip.copyWith(stops: updatedStops);
  }

  void _applyTrackerSilence(TrackerSilentReport report) {
    final live = state.liveByBus[report.busId];
    if (live == null || live.isStale) return;
    state = state.copyWith(
      liveByBus: {
        ...state.liveByBus,
        report.busId: live.copyWith(isStale: true),
      },
    );
  }

  /// Flags positions the app must stop presenting as live.
  void _markStale() {
    if (state.liveByBus.isEmpty) return;
    final now = DateTime.now();
    var changed = false;
    final updated = <String, BusLiveState>{};

    for (final entry in state.liveByBus.entries) {
      final stale = _eta.isPositionStale(
        lastPingAt: entry.value.updatedAt,
        now: now,
        staleAfter: state.config.staleAfter,
      );
      if (stale != entry.value.isStale) changed = true;
      updated[entry.key] = entry.value.copyWith(isStale: stale);
    }
    if (changed) state = state.copyWith(liveByBus: updated);
  }

  // ── attendance ───────────────────────────────────────────────────────────

  void _applyCardScan(CardScanReport scan) {
    final student = _studentForCard(scan.cardUid);
    if (student == null) return;

    recordBusAttendance(
      studentId: student.id,
      tripId: scan.tripId,
      stopId: scan.stopId,
      method: VerificationMethod.nfcCard,
      at: scan.occurredAt,
      location: scan.location,
    );
  }

  /// Records a bus tap. Whether it means boarding or alighting is derived from
  /// the student's own history on this trip, never from device state — a reader
  /// that reboots mid-route must not flip everyone's direction.
  void recordBusAttendance({
    required String studentId,
    required String tripId,
    required VerificationMethod method,
    required DateTime at,
    String? stopId,
    LatLngPoint? location,
    ManualEntryReason? reason,
    String? recordedByUserId,
  }) {
    final onBoard = _isOnBoard(studentId: studentId, tripId: tripId);
    final type = onBoard
        ? AttendanceEventType.alightedBus
        : AttendanceEventType.boardedBus;

    final event = AttendanceEvent(
      id: _id(),
      schoolId: state.school.id,
      studentId: studentId,
      type: type,
      method: method,
      occurredAt: at,
      tripId: tripId,
      stopId: stopId,
      location: location,
      manualReason: reason,
      recordedByUserId: recordedByUserId,
    );

    state = state.copyWith(
      attendanceEvents: [...state.attendanceEvents, event],
    );
    _notifyAttendance(event);
  }

  /// A tap at the school gate. Entry or exit is derived the same way.
  void recordGateAttendance({
    required String studentId,
    required VerificationMethod method,
    required DateTime at,
    String? recordedByUserId,
    ManualEntryReason? reason,
  }) {
    final inside = _isInsideSchool(studentId);
    final type = inside
        ? AttendanceEventType.exitedSchool
        : AttendanceEventType.enteredSchool;

    final event = AttendanceEvent(
      id: _id(),
      schoolId: state.school.id,
      studentId: studentId,
      type: type,
      method: method,
      occurredAt: at,
      location: state.school.gateLocation,
      recordedByUserId: recordedByUserId,
      manualReason: reason,
    );

    state = state.copyWith(
      attendanceEvents: [...state.attendanceEvents, event],
    );
    _notifyAttendance(event);
  }

  /// Marks an expected student as never having boarded.
  void markNoShow({
    required String studentId,
    required String tripId,
    required String recordedByUserId,
  }) {
    final now = DateTime.now();
    final record = AbsenceRecord(
      id: _id(),
      schoolId: state.school.id,
      studentId: studentId,
      serviceDate: DateTime(now.year, now.month, now.day),
      reason: AbsenceReason.noShowAtStop,
      declaredAt: now,
      declaredByUserId: recordedByUserId,
    );

    state = state.copyWith(absences: [...state.absences, record]);
    _notifyGuardians(
      studentId: studentId,
      kind: NotificationKind.noShow,
      titleAr: 'لم يصعد الطالب',
      titleEn: 'Student did not board',
      bodyAr: 'وصلت الحافلة إلى المحطة و${_studentName(studentId)} لم يصعد.',
      bodyEn:
          'The bus reached the stop and ${_studentNameEn(studentId)} did not board.',
      at: now,
    );
  }

  bool _isOnBoard({required String studentId, required String tripId}) {
    var onBoard = false;
    for (final event in state.attendanceEvents) {
      if (event.studentId != studentId || event.tripId != tripId) continue;
      if (event.type == AttendanceEventType.boardedBus) onBoard = true;
      if (event.type == AttendanceEventType.alightedBus) onBoard = false;
    }
    return onBoard;
  }

  bool _isInsideSchool(String studentId) {
    var inside = false;
    for (final event in state.attendanceEvents) {
      if (event.studentId != studentId) continue;
      if (event.type == AttendanceEventType.enteredSchool) inside = true;
      if (event.type == AttendanceEventType.exitedSchool) inside = false;
    }
    return inside;
  }

  // ── absences and replanning ──────────────────────────────────────────────

  /// A guardian declares an absence. Any trip still to run is replanned.
  Future<void> declareAbsence({
    required String studentId,
    required String declaredByUserId,
    TripDirection? direction,
  }) async {
    if (state.absenceFor(studentId) != null) return;

    final now = DateTime.now();
    final record = AbsenceRecord(
      id: _id(),
      schoolId: state.school.id,
      studentId: studentId,
      serviceDate: DateTime(now.year, now.month, now.day),
      reason: AbsenceReason.declaredByGuardian,
      declaredAt: now,
      declaredByUserId: declaredByUserId,
      direction: direction,
    );

    state = state.copyWith(absences: [...state.absences, record]);
    await _replanForStudent(studentId, absent: true);

    _notifyGuardians(
      studentId: studentId,
      kind: NotificationKind.absenceRecorded,
      titleAr: 'سُجّل الغياب',
      titleEn: 'Absence recorded',
      bodyAr:
          'تم إبلاغ السائق. ${_studentName(studentId)} خارج مسار اليوم، وسيتم تخطي محطته إن لم يكن فيها طالب آخر.',
      bodyEn:
          'The driver has been told. ${_studentNameEn(studentId)} is off today\'s route, and the stop is skipped if nobody else is due there.',
      at: now,
    );
  }

  Future<void> cancelAbsence(String studentId) async {
    final existing = state.absenceFor(studentId);
    if (existing == null) return;

    state = state.copyWith(
      absences: state.absences.where((a) => a.studentId != studentId).toList(),
    );
    await _replanForStudent(studentId, absent: false);
  }

  /// Rebuilds the affected stop on every trip that has not yet served it.
  Future<void> _replanForStudent(
    String studentId, {
    required bool absent,
  }) async {
    final student = SeedData.studentsById[studentId];
    final stopId = student?.stopId;
    if (stopId == null) return;

    final updated = <Trip>[];
    for (final trip in state.trips) {
      if (trip.status == TripStatus.completed) {
        updated.add(trip);
        continue;
      }

      final tripStop = trip.stops.where((s) => s.stopId == stopId).firstOrNull;
      if (tripStop == null || tripStop.status.isDone && absent) {
        updated.add(trip);
        continue;
      }

      final remaining = SeedData.studentsForStop(stopId)
          .map((s) => s.id)
          .where(
            (id) => absent
                ? id != studentId && state.absenceFor(id) == null
                : state.absenceFor(id) == null,
          )
          .toList();

      final replanned = remaining.isEmpty
          ? await _planner.skipStop(
              trip: trip,
              stopId: stopId,
              stopsById: SeedData.stopsById,
              schoolLocation: state.school.location,
              reason: 'allStudentsAbsent',
            )
          : await _planner.restoreStop(
              trip: trip,
              stopId: stopId,
              studentIds: remaining,
              stopsById: SeedData.stopsById,
              schoolLocation: state.school.location,
            );

      updated.add(replanned);
      // The simulator needs the new geometry so the bus follows the revised
      // plan rather than the one it started with.
      final source = _source;
      if (source is SimulatedFleet) source.updateTrip(replanned);
    }
    state = state.copyWith(trips: updated);
  }

  // ── alerts, confirmations, audit ─────────────────────────────────────────

  void acknowledgeAlert(String alertId) {
    state = state.copyWith(
      alerts: state.alerts
          .map(
            (a) => a.id == alertId
                ? a.copyWith(
                    acknowledgedAt: DateTime.now(),
                    acknowledgedByUserId: state.currentUser.id,
                  )
                : a,
          )
          .toList(),
    );
  }

  /// A guardian confirms or disputes a hand-entered record. The dispute is the
  /// second verification layer that makes manual entry safe to allow at all.
  void respondToManualEntry({
    required String attendanceEventId,
    required GuardianConfirmation response,
  }) {
    state = state.copyWith(
      attendanceEvents: state.attendanceEvents
          .map(
            (e) => e.id == attendanceEventId
                ? e.copyWith(guardianConfirmation: response)
                : e,
          )
          .toList(),
    );

    if (response != GuardianConfirmation.disputed) return;

    final event = state.attendanceEvents
        .where((e) => e.id == attendanceEventId)
        .firstOrNull;
    if (event == null) return;

    final alert = SafetyAlert(
      id: _id(),
      schoolId: state.school.id,
      kind: SafetyAlertKind.leftSchoolNotOnBus,
      raisedAt: DateTime.now(),
      titleAr: 'ولي أمر اعترض على تسجيل يدوي',
      titleEn: 'Guardian disputed a manual record',
      detailAr:
          'اعترض ولي أمر ${_studentName(event.studentId)} على تسجيل يدوي. راجع الحالة فوراً.',
      detailEn:
          'The guardian of ${_studentNameEn(event.studentId)} disputed a hand-entered record. Check immediately.',
      studentId: event.studentId,
      tripId: event.tripId,
    );
    state = state.copyWith(alerts: [...state.alerts, alert]);
  }

  void markNotificationRead(String notificationId) {
    state = state.copyWith(
      notifications: state.notifications
          .map(
            (n) => n.id == notificationId && n.isUnread
                ? n.copyWith(readAt: DateTime.now())
                : n,
          )
          .toList(),
    );
  }

  // ── session ──────────────────────────────────────────────────────────────

  void signInAs(AppUser user) {
    state = state.copyWith(
      currentUser: user,
      clearImpersonation: true,
    );
  }

  /// Starts a time-boxed privileged view. Logged without exception: an
  /// unlogged back door into children's location data is a liability, not a
  /// feature.
  void beginImpersonation(UserRole role) {
    if (!state.currentUser.role.canImpersonate) return;
    final now = DateTime.now();
    state = state.copyWith(
      impersonation: ImpersonationSession(
        role: role,
        startedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      ),
      auditLog: [
        ...state.auditLog,
        AuditEntry(
          id: _id(),
          schoolId: state.school.id,
          actorUserId: state.currentUser.id,
          actorRole: state.currentUser.role,
          action: 'impersonation.begin',
          occurredAt: now,
          detail: role.name,
        ),
      ],
    );
  }

  void endImpersonation() {
    if (state.impersonation == null) return;
    state = state.copyWith(
      clearImpersonation: true,
      auditLog: [
        ...state.auditLog,
        AuditEntry(
          id: _id(),
          schoolId: state.school.id,
          actorUserId: state.currentUser.id,
          actorRole: state.currentUser.role,
          action: 'impersonation.end',
          occurredAt: DateTime.now(),
        ),
      ],
    );
  }

  void recordAudit({
    required String action,
    String? subjectStudentId,
    String? detail,
  }) {
    state = state.copyWith(
      auditLog: [
        ...state.auditLog,
        AuditEntry(
          id: _id(),
          schoolId: state.school.id,
          actorUserId: state.currentUser.id,
          actorRole: state.effectiveRole,
          action: action,
          occurredAt: DateTime.now(),
          subjectStudentId: subjectStudentId,
          detail: detail,
        ),
      ],
    );
  }

  void setLocale(Locale locale) => state = state.copyWith(locale: locale);
  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);

  // ── notifications ────────────────────────────────────────────────────────

  void _notifyAttendance(AttendanceEvent event) {
    final kind = switch (event.type) {
      AttendanceEventType.boardedBus => NotificationKind.boarded,
      AttendanceEventType.alightedBus => NotificationKind.alighted,
      AttendanceEventType.enteredSchool => NotificationKind.enteredSchool,
      AttendanceEventType.exitedSchool => NotificationKind.exitedSchool,
    };

    final name = _studentName(event.studentId);
    final nameEn = _studentNameEn(event.studentId);

    final (titleAr, titleEn) = switch (event.type) {
      AttendanceEventType.boardedBus => ('صعد الحافلة', 'Boarded the bus'),
      AttendanceEventType.alightedBus => ('نزل من الحافلة', 'Left the bus'),
      AttendanceEventType.enteredSchool => ('دخل المدرسة', 'Entered school'),
      AttendanceEventType.exitedSchool => ('خرج من المدرسة', 'Left school'),
    };

    // Manual records say so in the notification body itself. A guardian must
    // never be shown a hand-entered record as though the card was scanned.
    final manualNoteAr = event.isManual
        ? ' — سُجّل يدوياً بدون بطاقة بواسطة ${_userName(event.recordedByUserId)}'
        : '';
    final manualNoteEn = event.isManual
        ? ' — entered by hand without a card by ${_userNameEn(event.recordedByUserId)}'
        : '';

    _notifyGuardians(
      studentId: event.studentId,
      kind: event.isManual ? NotificationKind.manualAttendance : kind,
      titleAr: titleAr,
      titleEn: titleEn,
      bodyAr: '$name — ${_formatTime(event.occurredAt)}$manualNoteAr',
      bodyEn: '$nameEn — ${_formatTime(event.occurredAt)}$manualNoteEn',
      at: event.occurredAt,
      attendanceEventId: event.isManual ? event.id : null,
      requiresConfirmation: event.isManual,
    );
  }

  void _notifyStopStudents({
    required Trip trip,
    required TripStop stop,
    required NotificationKind kind,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    required DateTime at,
  }) {
    for (final studentId in stop.expectedStudentIds) {
      _notifyGuardians(
        studentId: studentId,
        kind: kind,
        titleAr: titleAr,
        titleEn: titleEn,
        bodyAr: bodyAr,
        bodyEn: bodyEn,
        at: at,
      );
    }
  }

  void _notifyGuardians({
    required String studentId,
    required NotificationKind kind,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    required DateTime at,
    String? attendanceEventId,
    bool requiresConfirmation = false,
  }) {
    final student = SeedData.studentsById[studentId];
    if (student == null) return;

    // The demo guardian shares children with the per-student accounts, so both
    // are notified — mirroring a household with two registered parents.
    final recipients = <String>{
      ...student.guardianIds,
      if (SeedData.demoGuardian.linkedStudentIds.contains(studentId))
        SeedData.demoGuardian.id,
    };

    final created = recipients.map(
      (recipient) => AppNotification(
        id: _id(),
        schoolId: state.school.id,
        recipientUserId: recipient,
        kind: kind,
        titleAr: titleAr,
        titleEn: titleEn,
        bodyAr: bodyAr,
        bodyEn: bodyEn,
        sentAt: at,
        studentId: studentId,
        attendanceEventId: attendanceEventId,
        requiresConfirmation: requiresConfirmation,
      ),
    );

    state = state.copyWith(
      notifications: [...state.notifications, ...created],
    );
  }

  // ── lookups ──────────────────────────────────────────────────────────────

  Student? _studentForCard(String cardUid) {
    for (final student in SeedData.students) {
      if (student.cardUid == cardUid) return student;
    }
    return null;
  }

  void _replaceTrip(Trip trip) {
    state = state.copyWith(
      trips: state.trips.map((t) => t.id == trip.id ? trip : t).toList(),
    );
  }

  String _studentName(String id) => SeedData.studentsById[id]?.fullNameAr ?? id;
  String _studentNameEn(String id) =>
      SeedData.studentsById[id]?.fullNameEn ?? id;
  String _userName(String? id) =>
      id == null ? 'السائق' : SeedData.usersById[id]?.fullNameAr ?? 'السائق';
  String _userNameEn(String? id) => id == null
      ? 'the driver'
      : SeedData.usersById[id]?.fullNameEn ?? 'the driver';
  String _stopName(String id) => SeedData.stopsById[id]?.nameAr ?? id;
  String _stopNameEn(String id) => SeedData.stopsById[id]?.nameEn ?? id;
  String _busPlate(String id) => SeedData.busesById[id]?.plateNumber ?? id;

  static String _formatTime(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  /// Exposed for the developer screens.
  FleetEventSource get eventSource => _source;
  JourneyEngine get journeyEngine => _journey;
  EtaEngine get etaEngine => _eta;
}
