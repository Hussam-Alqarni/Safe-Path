import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:safe_path/core/config/app_config.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';

/// Where a bus is right now, as far as anyone can honestly say.
class BusLiveState {
  const BusLiveState({
    required this.busId,
    required this.tripId,
    required this.position,
    required this.previousPosition,
    required this.speedKmh,
    required this.heading,
    required this.distanceAlongRouteMetres,
    required this.updatedAt,
    this.isStale = false,
  });

  final String busId;
  final String tripId;
  final LatLngPoint position;

  /// The prior fix. The map animates from here to [position] over the ping
  /// interval instead of teleporting the marker.
  final LatLngPoint previousPosition;

  final double speedKmh;
  final double heading;
  final double distanceAlongRouteMetres;
  final DateTime updatedAt;

  /// True once the tracker has been silent past the configured window. The UI
  /// must stop animating and say so rather than extrapolate.
  final bool isStale;

  BusLiveState copyWith({bool? isStale}) => BusLiveState(
        busId: busId,
        tripId: tripId,
        position: position,
        previousPosition: previousPosition,
        speedKmh: speedKmh,
        heading: heading,
        distanceAlongRouteMetres: distanceAlongRouteMetres,
        updatedAt: updatedAt,
        isStale: isStale ?? this.isStale,
      );
}

/// An active privileged-access session.
class ImpersonationSession {
  const ImpersonationSession({
    required this.role,
    required this.startedAt,
    required this.expiresAt,
  });

  final UserRole role;
  final DateTime startedAt;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => now.isAfter(expiresAt);
}

/// The whole application state, in one immutable value.
class AppState {
  AppState({
    required this.config,
    required this.school,
    required this.students,
    required this.trips,
    required this.attendanceEvents,
    required this.absences,
    required this.alerts,
    required this.notifications,
    required this.auditLog,
    required this.liveByBus,
    required this.currentUser,
    required this.locale,
    required this.themeMode,
    this.impersonation,
    this.simulationRunning = false,
    this.usesSimulatedData = true,
  }) : studentsById = {for (final s in students) s.id: s};

  final AppConfig config;
  final School school;

  /// The roster. Editable, unlike the seed it starts from — a home location
  /// set by an administrator has to live somewhere the app can change.
  final List<Student> students;

  /// Built once per state rather than on every lookup; screens read it inside
  /// build methods that run on every frame.
  final Map<String, Student> studentsById;
  final List<Trip> trips;
  final List<AttendanceEvent> attendanceEvents;
  final List<AbsenceRecord> absences;
  final List<SafetyAlert> alerts;
  final List<AppNotification> notifications;
  final List<AuditEntry> auditLog;
  final Map<String, BusLiveState> liveByBus;

  /// The signed-in account. Never changes while impersonating — impersonation
  /// changes the *view*, not the identity, so the audit trail stays truthful.
  final AppUser currentUser;

  final Locale locale;
  final ThemeMode themeMode;
  final ImpersonationSession? impersonation;
  final bool simulationRunning;

  /// Whether the positions on screen came from a simulator.
  ///
  /// Derived from the live data source, not from a configuration flag. Intent
  /// and reality can differ — asking for live mode does not conjure a live
  /// feed — and the one thing this app must never do is present invented
  /// positions as though a bus reported them.
  final bool usesSimulatedData;

  /// The role whose screens are being shown.
  UserRole get effectiveRole => impersonation?.role ?? currentUser.role;

  bool get isImpersonating => impersonation != null;

  List<Trip> get activeTrips =>
      trips.where((t) => t.status == TripStatus.inProgress).toList();

  List<SafetyAlert> get openAlerts {
    final open = alerts.where((a) => a.isOpen).toList()
      ..sort((a, b) {
        final bySeverity = a.severity.index.compareTo(b.severity.index);
        return bySeverity != 0 ? bySeverity : b.raisedAt.compareTo(a.raisedAt);
      });
    return open;
  }

  Trip? tripById(String id) {
    for (final trip in trips) {
      if (trip.id == id) return trip;
    }
    return null;
  }

  Trip? activeTripForStudent(String studentId) {
    for (final trip in activeTrips) {
      if (trip.expectedStudentIds.contains(studentId)) return trip;
    }
    return null;
  }

  List<AppNotification> notificationsFor(String userId) {
    final list = notifications
        .where((n) => n.recipientUserId == userId)
        .toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return list;
  }

  /// Today's absence for a student, optionally scoped to one run.
  ///
  /// Both filters matter. Without the date, an absence recorded last Tuesday
  /// keeps a child off the bus for the rest of the year. Without the
  /// direction, a morning no-show also strikes them off the afternoon run —
  /// and a guardian who only wants the ride home cancelled cannot say so.
  AbsenceRecord? absenceFor(
    String studentId, {
    TripDirection? direction,
    DateTime? on,
  }) {
    final day = on ?? DateTime.now();
    final date = DateTime(day.year, day.month, day.day);

    for (final absence in absences) {
      if (absence.studentId != studentId) continue;
      if (absence.serviceDate != date) continue;
      if (direction != null && !absence.appliesTo(direction)) continue;
      return absence;
    }
    return null;
  }

  /// Every absence recorded for a student today, in any direction.
  List<AbsenceRecord> absencesFor(String studentId, {DateTime? on}) {
    final day = on ?? DateTime.now();
    final date = DateTime(day.year, day.month, day.day);
    return absences
        .where((a) => a.studentId == studentId && a.serviceDate == date)
        .toList();
  }

  List<Student> studentsForStop(String stopId) =>
      students.where((s) => s.stopId == stopId).toList();

  AppState copyWith({
    List<Student>? students,
    List<Trip>? trips,
    List<AttendanceEvent>? attendanceEvents,
    List<AbsenceRecord>? absences,
    List<SafetyAlert>? alerts,
    List<AppNotification>? notifications,
    List<AuditEntry>? auditLog,
    Map<String, BusLiveState>? liveByBus,
    AppUser? currentUser,
    Locale? locale,
    ThemeMode? themeMode,
    ImpersonationSession? impersonation,
    bool clearImpersonation = false,
    bool? simulationRunning,
    bool? usesSimulatedData,
  }) {
    return AppState(
      config: config,
      school: school,
      students: students ?? this.students,
      trips: trips ?? this.trips,
      attendanceEvents: attendanceEvents ?? this.attendanceEvents,
      absences: absences ?? this.absences,
      alerts: alerts ?? this.alerts,
      notifications: notifications ?? this.notifications,
      auditLog: auditLog ?? this.auditLog,
      liveByBus: liveByBus ?? this.liveByBus,
      currentUser: currentUser ?? this.currentUser,
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      impersonation:
          clearImpersonation ? null : (impersonation ?? this.impersonation),
      simulationRunning: simulationRunning ?? this.simulationRunning,
      usesSimulatedData: usesSimulatedData ?? this.usesSimulatedData,
    );
  }
}
