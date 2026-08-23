import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';
import 'package:safe_path/domain/services/route_planner.dart';

const testSchoolId = 'school-001';
const schoolLocation = LatLngPoint(21.5433, 39.1728);

int _counter = 0;
String nextId() => 'id-${++_counter}';
void resetIds() => _counter = 0;

BusStop stop(String id, double lat, double lng) => BusStop(
      id: id,
      schoolId: testSchoolId,
      nameAr: 'محطة $id',
      nameEn: 'Stop $id',
      location: LatLngPoint(lat, lng),
      dwellSeconds: 45,
    );

Student student(
  String id, {
  String? stopId,
  bool usesBus = true,
}) =>
    Student(
      id: id,
      schoolId: testSchoolId,
      fullNameAr: 'طالب $id',
      fullNameEn: 'Student $id',
      grade: '4',
      section: 'أ',
      guardianIds: const ['guardian-1'],
      cardUid: 'UID-$id',
      stopId: stopId,
      usesBus: usesBus,
    );

BusRoute route({
  TripDirection direction = TripDirection.toSchool,
  required List<String> stopIds,
}) =>
    BusRoute(
      id: 'route-1',
      schoolId: testSchoolId,
      busId: 'bus-1',
      driverId: 'driver-1',
      nameAr: 'المسار الشمالي',
      nameEn: 'North route',
      direction: direction,
      orderedStopIds: stopIds,
      departureTime: const ScheduleTime(6, 15),
    );

AttendanceEvent event({
  required String studentId,
  required AttendanceEventType type,
  required DateTime at,
  String? tripId,
  String? stopId,
  VerificationMethod method = VerificationMethod.nfcCard,
}) =>
    AttendanceEvent(
      id: nextId(),
      schoolId: testSchoolId,
      studentId: studentId,
      type: type,
      method: method,
      occurredAt: at,
      tripId: tripId,
      stopId: stopId,
    );

AbsenceRecord absence(
  String studentId, {
  AbsenceReason reason = AbsenceReason.declaredByGuardian,
  TripDirection? direction,
}) =>
    AbsenceRecord(
      id: nextId(),
      schoolId: testSchoolId,
      studentId: studentId,
      serviceDate: DateTime(2026, 9, 1),
      reason: reason,
      declaredAt: DateTime(2026, 8, 31, 21),
      declaredByUserId: 'guardian-1',
      direction: direction,
    );

RoutePlanner buildPlanner() =>
    const RoutePlanner(LocalGeometryRoutingService());
