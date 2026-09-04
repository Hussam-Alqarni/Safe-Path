import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';

/// One school day's attendance, as a single row.
class DailyAttendance {
  const DailyAttendance({
    required this.date,
    required this.expected,
    required this.present,
    required this.manualRecords,
  });

  final DateTime date;
  final int expected;
  final int present;

  /// How many of the day's records were entered by hand.
  final int manualRecords;

  /// Share of expected students actually accounted for, 0–1.
  double get rate => expected == 0 ? 0 : present / expected;

  int get missing => expected - present;
}

/// A driver's hand-entry rate over a period.
class DriverReliability {
  const DriverReliability({
    required this.driverId,
    required this.totalRecords,
    required this.manualRecords,
  });

  final String driverId;
  final int totalRecords;
  final int manualRecords;

  double get manualRate => totalRecords == 0 ? 0 : manualRecords / totalRecords;
}

/// How close a route ran to its plan.
class RoutePunctuality {
  const RoutePunctuality({
    required this.routeId,
    required this.busId,
    required this.stopsServed,
    required this.averageDelaySeconds,
  });

  final String routeId;
  final String busId;
  final int stopsServed;

  /// Positive means late. Negative means early, which matters as much: a bus
  /// that arrives before a guardian expects it leaves a child on a pavement.
  final int averageDelaySeconds;

  int get averageDelayMinutes => (averageDelaySeconds / 60).round();
}

/// Turns the event log into the handful of numbers an administrator acts on.
///
/// Pure functions over state, so a figure on the dashboard can always be
/// traced back to the records that produced it — a dashboard nobody can audit
/// is decoration.
abstract final class Analytics {
  /// Today's attendance, computed from the live log.
  static DailyAttendance today({
    required List<Trip> trips,
    required List<AttendanceEvent> events,
    required List<Student> students,
    required DateTime date,
  }) {
    final expected = students.where((s) => s.usesBus).length;

    final accountedFor = events
        .where((e) => e.type == AttendanceEventType.boardedBus)
        .map((e) => e.studentId)
        .toSet();

    return DailyAttendance(
      date: DateTime(date.year, date.month, date.day),
      expected: expected,
      present: accountedFor.length,
      manualRecords: events.where((e) => e.isManual).length,
    );
  }

  /// Hand-entry rate per driver.
  ///
  /// The most useful early-warning number the system produces: a rate that
  /// climbs for one driver almost always means a failing reader, and it shows
  /// here days before anyone reports it.
  static List<DriverReliability> driverReliability({
    required List<AttendanceEvent> events,
    required List<Trip> trips,
  }) {
    final driverByTrip = {for (final t in trips) t.id: t.driverId};
    final totals = <String, int>{};
    final manual = <String, int>{};

    for (final event in events) {
      final driverId = driverByTrip[event.tripId];
      if (driverId == null) continue;
      totals[driverId] = (totals[driverId] ?? 0) + 1;
      if (event.isManual) manual[driverId] = (manual[driverId] ?? 0) + 1;
    }

    final rows = totals.entries
        .map(
          (e) => DriverReliability(
            driverId: e.key,
            totalRecords: e.value,
            manualRecords: manual[e.key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.manualRate.compareTo(a.manualRate));
    return rows;
  }

  /// Average arrival delay per route, over stops that were actually served.
  static List<RoutePunctuality> punctuality(List<Trip> trips) {
    final rows = <RoutePunctuality>[];

    for (final trip in trips) {
      var served = 0;
      var totalDelay = 0;

      for (final stop in trip.stops) {
        final planned = stop.plannedArrival;
        final actual = stop.actualArrival;
        if (planned == null || actual == null) continue;
        served++;
        totalDelay += actual.difference(planned).inSeconds;
      }

      if (served == 0) continue;
      rows.add(
        RoutePunctuality(
          routeId: trip.routeId,
          busId: trip.busId,
          stopsServed: served,
          averageDelaySeconds: (totalDelay / served).round(),
        ),
      );
    }
    return rows;
  }

  /// Share of today's records entered by hand, across the whole school.
  static double manualRate(List<AttendanceEvent> events) {
    if (events.isEmpty) return 0;
    return events.where((e) => e.isManual).length / events.length;
  }

  /// Students with no home location recorded.
  ///
  /// Every one of these is a pickup point nobody has confirmed, which is a
  /// data gap with a safety cost rather than a tidiness problem.
  static List<Student> missingHomeLocation(List<Student> students) =>
      students.where((s) => s.usesBus && !s.hasHome).toList();
}
