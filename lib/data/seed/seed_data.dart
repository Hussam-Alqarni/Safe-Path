import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';

/// A complete, plausible school for demos and tests.
///
/// Real Jeddah districts and real distances, so the map, the ETAs and the
/// route lengths all behave the way they will in the pilot. Demo data that is
/// too tidy hides exactly the problems a demo should surface.
abstract final class SeedData {
  static const schoolId = 'school-001';

  static const school = School(
    id: schoolId,
    nameAr: 'مدرسة الرواد الأهلية',
    nameEn: 'Al-Ruwad Private School',
    location: LatLngPoint(21.5433, 39.1728),
    gateLocation: LatLngPoint(21.5431, 39.1731),
    dayStartsAt: ScheduleTime(7, 0),
    dayEndsAt: ScheduleTime(13, 30),
  );

  static const operator_ = TransportOperator(
    id: 'operator-001',
    nameAr: 'شركة الوفاء للنقل التعليمي',
    nameEn: 'Al-Wafa Educational Transport',
    contactPhone: '+966500000000',
  );

  static const buses = <Bus>[
    Bus(
      id: 'bus-north',
      operatorId: 'operator-001',
      plateNumber: 'ABC-1234',
      capacity: 24,
      trackerDeviceId: '860123456789012',
    ),
    Bus(
      id: 'bus-east',
      operatorId: 'operator-001',
      plateNumber: 'XYZ-5678',
      capacity: 24,
      trackerDeviceId: '860123456789013',
    ),
  ];

  // ── stops ────────────────────────────────────────────────────────────────

  static final stops = <BusStop>[
    _stop('stop-rawdah', 'حي الروضة', 'Al-Rawdah', 21.5602, 39.1553),
    _stop('stop-zahra', 'حي الزهراء', 'Al-Zahra', 21.5698, 39.1449),
    _stop('stop-naeem', 'حي النعيم', 'Al-Naeem', 21.6004, 39.1602),
    _stop('stop-salamah', 'حي السلامة', 'Al-Salamah', 21.5897, 39.1704),
    _stop('stop-musharifah', 'حي مشرفة', 'Musharifah', 21.5251, 39.1848),
    _stop('stop-faihaa', 'حي الفيحاء', 'Al-Faihaa', 21.5353, 39.1951),
    _stop('stop-safa', 'حي الصفا', 'Al-Safa', 21.5504, 39.2002),
    _stop('stop-bawadi', 'حي البوادي', 'Al-Bawadi', 21.5799, 39.1803),
  ];

  static BusStop _stop(
    String id,
    String nameAr,
    String nameEn,
    double lat,
    double lng,
  ) =>
      BusStop(
        id: id,
        schoolId: schoolId,
        nameAr: nameAr,
        nameEn: nameEn,
        location: LatLngPoint(lat, lng),
        dwellSeconds: 45,
      );

  static const northStopIds = [
    'stop-rawdah',
    'stop-zahra',
    'stop-naeem',
    'stop-salamah',
  ];

  static const eastStopIds = [
    'stop-musharifah',
    'stop-faihaa',
    'stop-safa',
    'stop-bawadi',
  ];

  // ── people ───────────────────────────────────────────────────────────────

  static const _studentSeeds = <_StudentSeed>[
    // North route
    _StudentSeed('سعد الشهري', 'Saad Alshehri', '4', 'أ', 'stop-rawdah'),
    _StudentSeed('لين القحطاني', 'Leen Alqahtani', '3', 'ب', 'stop-rawdah'),
    _StudentSeed('ريان الحربي', 'Rayan Alharbi', '5', 'أ', 'stop-rawdah'),
    _StudentSeed('جود العتيبي', 'Jood Alotaibi', '2', 'أ', 'stop-zahra'),
    _StudentSeed('فيصل الزهراني', 'Faisal Alzahrani', '6', 'ب', 'stop-zahra'),
    _StudentSeed('دانة الغامدي', 'Danah Alghamdi', '4', 'ب', 'stop-zahra'),
    _StudentSeed('عبدالله المالكي', 'Abdullah Almalki', '5', 'أ', 'stop-naeem'),
    _StudentSeed('شهد الدوسري', 'Shahad Aldosari', '3', 'أ', 'stop-naeem'),
    _StudentSeed('تركي السبيعي', 'Turki Alsubaie', '6', 'أ', 'stop-naeem'),
    _StudentSeed('نورة العنزي', 'Noura Alanazi', '2', 'ب', 'stop-salamah'),
    _StudentSeed('محمد البقمي', 'Mohammed Albaqami', '4', 'أ', 'stop-salamah'),
    _StudentSeed('رغد المطيري', 'Raghad Almutairi', '5', 'ب', 'stop-salamah'),
    // East route
    _StudentSeed(
      'يوسف الثقفي',
      'Yousef Althaqafi',
      '3',
      'أ',
      'stop-musharifah',
    ),
    _StudentSeed('مها الشمري', 'Maha Alshammari', '6', 'ب', 'stop-musharifah'),
    _StudentSeed('خالد الجهني', 'Khalid Aljuhani', '4', 'أ', 'stop-musharifah'),
    _StudentSeed('سلمى الرشيدي', 'Salma Alrashidi', '2', 'أ', 'stop-faihaa'),
    _StudentSeed('عمر الصاعدي', 'Omar Alsaedi', '5', 'أ', 'stop-faihaa'),
    _StudentSeed('لمى العمري', 'Lama Alamri', '3', 'ب', 'stop-faihaa'),
    _StudentSeed('بدر الحازمي', 'Badr Alhazmi', '6', 'أ', 'stop-safa'),
    _StudentSeed('أروى الخالدي', 'Arwa Alkhalidi', '4', 'ب', 'stop-safa'),
    _StudentSeed('ماجد الفهمي', 'Majed Alfahmi', '5', 'ب', 'stop-safa'),
    _StudentSeed('هيا السلمي', 'Haya Alsulami', '2', 'أ', 'stop-bawadi'),
    _StudentSeed('راكان الأحمدي', 'Rakan Alahmadi', '3', 'أ', 'stop-bawadi'),
    _StudentSeed('غلا الزيلعي', 'Ghala Alzailaee', '6', 'ب', 'stop-bawadi'),
    // Walkers and car riders — they never board a bus, but the gate readers
    // still record them. Attendance covers the whole school, not just riders.
    _StudentSeed('سارة القرني', 'Sarah Alqarni', '4', 'أ', null),
    _StudentSeed('إبراهيم باوزير', 'Ibrahim Bawazir', '5', 'ب', null),
    _StudentSeed('جنى الشريف', 'Jana Alsharif', '3', 'أ', null),
    _StudentSeed('وليد الأنصاري', 'Waleed Alansari', '6', 'أ', null),
  ];

  static final students = <Student>[
    for (var i = 0; i < _studentSeeds.length; i++)
      Student(
        id: 'student-${(i + 1).toString().padLeft(3, '0')}',
        schoolId: schoolId,
        fullNameAr: _studentSeeds[i].nameAr,
        fullNameEn: _studentSeeds[i].nameEn,
        grade: _studentSeeds[i].grade,
        section: _studentSeeds[i].section,
        guardianIds: ['guardian-${(i + 1).toString().padLeft(3, '0')}'],
        cardUid: 'SA${(i + 1).toString().padLeft(6, '0')}',
        stopId: _studentSeeds[i].stopId,
        usesBus: _studentSeeds[i].stopId != null,
        photoInitials: _initials(_studentSeeds[i].nameAr),
      ),
  ];

  static String _initials(String arabicName) {
    final parts = arabicName.split(' ');
    if (parts.length < 2) return parts.first.characters(2);
    return '${parts.first.characters(1)}${parts[1].characters(1)}';
  }

  /// One guardian per student, plus a demo guardian who has three children —
  /// the multi-child case is where a parent UI usually falls apart.
  static final guardians = <AppUser>[
    for (var i = 0; i < _studentSeeds.length; i++)
      AppUser(
        id: 'guardian-${(i + 1).toString().padLeft(3, '0')}',
        role: UserRole.guardian,
        fullNameAr: 'ولي أمر ${_studentSeeds[i].nameAr.split(' ').first}',
        fullNameEn: 'Guardian of ${_studentSeeds[i].nameEn.split(' ').first}',
        phone: '+9665${(10000000 + i).toString()}',
        schoolId: schoolId,
        linkedStudentIds: ['student-${(i + 1).toString().padLeft(3, '0')}'],
      ),
  ];

  /// The account the demo signs in as. Three children spread across both
  /// routes and one walker, so every state is visible from one screen.
  static const demoGuardian = AppUser(
    id: 'guardian-demo',
    role: UserRole.guardian,
    fullNameAr: 'أبو سعد',
    fullNameEn: 'Abu Saad',
    phone: '+966500000001',
    schoolId: schoolId,
    linkedStudentIds: ['student-001', 'student-013', 'student-025'],
  );

  static const drivers = <AppUser>[
    AppUser(
      id: 'driver-north',
      role: UserRole.driver,
      fullNameAr: 'أحمد المصري',
      fullNameEn: 'Ahmed Almasri',
      phone: '+966500000010',
      schoolId: schoolId,
      assignedBusId: 'bus-north',
    ),
    AppUser(
      id: 'driver-east',
      role: UserRole.driver,
      fullNameAr: 'سالم اليامي',
      fullNameEn: 'Salem Alyami',
      phone: '+966500000011',
      schoolId: schoolId,
      assignedBusId: 'bus-east',
    ),
  ];

  static const schoolAdmin = AppUser(
    id: 'admin-001',
    role: UserRole.schoolAdmin,
    fullNameAr: 'منى الحارثي',
    fullNameEn: 'Mona Alharthi',
    phone: '+966500000020',
    schoolId: schoolId,
  );

  static const schoolStaff = AppUser(
    id: 'staff-001',
    role: UserRole.schoolStaff,
    fullNameAr: 'عبدالعزيز الشهراني',
    fullNameEn: 'Abdulaziz Alshahrani',
    phone: '+966500000021',
    schoolId: schoolId,
  );

  static const developer = AppUser(
    id: 'dev-001',
    role: UserRole.developer,
    fullNameAr: 'مطوّر النظام',
    fullNameEn: 'System developer',
    phone: '+966500000030',
    schoolId: schoolId,
  );

  static List<AppUser> get allUsers => [
        demoGuardian,
        ...drivers,
        schoolAdmin,
        schoolStaff,
        developer,
        ...guardians,
      ];

  // ── routes ───────────────────────────────────────────────────────────────

  static const routes = <BusRoute>[
    BusRoute(
      id: 'route-north-am',
      schoolId: schoolId,
      busId: 'bus-north',
      driverId: 'driver-north',
      nameAr: 'المسار الشمالي — ذهاب',
      nameEn: 'North route — morning',
      direction: TripDirection.toSchool,
      orderedStopIds: northStopIds,
      departureTime: ScheduleTime(6, 15),
    ),
    BusRoute(
      id: 'route-east-am',
      schoolId: schoolId,
      busId: 'bus-east',
      driverId: 'driver-east',
      nameAr: 'المسار الشرقي — ذهاب',
      nameEn: 'East route — morning',
      direction: TripDirection.toSchool,
      orderedStopIds: eastStopIds,
      departureTime: ScheduleTime(6, 20),
    ),
    BusRoute(
      id: 'route-north-pm',
      schoolId: schoolId,
      busId: 'bus-north',
      driverId: 'driver-north',
      nameAr: 'المسار الشمالي — عودة',
      nameEn: 'North route — afternoon',
      direction: TripDirection.fromSchool,
      orderedStopIds: northStopIds,
      departureTime: ScheduleTime(13, 45),
    ),
    BusRoute(
      id: 'route-east-pm',
      schoolId: schoolId,
      busId: 'bus-east',
      driverId: 'driver-east',
      nameAr: 'المسار الشرقي — عودة',
      nameEn: 'East route — afternoon',
      direction: TripDirection.fromSchool,
      orderedStopIds: eastStopIds,
      departureTime: ScheduleTime(13, 50),
    ),
  ];

  /// Ten prior school days, for the trend on the dashboard.
  ///
  /// Explicitly demo history: the live day is computed from the event log, but
  /// a trend needs a past, and the app has only ever run once. Named so nobody
  /// mistakes it for recorded data — the demo banner says the same thing.
  static final demoAttendanceHistory = <({
    DateTime date,
    int expected,
    int present,
    int manual,
  })>[
    for (var i = 0; i < 10; i++)
      (
        date: DateTime(2026, 8, 24).add(Duration(days: i)),
        expected: 24,
        // A plausible week: a dip mid-week, a stronger Thursday.
        present: const [22, 23, 21, 24, 23, 20, 23, 24, 22, 23][i],
        manual: const [1, 0, 3, 0, 1, 4, 1, 0, 2, 1][i],
      ),
  ];

  static Map<String, BusStop> get stopsById => {for (final s in stops) s.id: s};

  static Map<String, Student> get studentsById =>
      {for (final s in students) s.id: s};

  static Map<String, Bus> get busesById => {for (final b in buses) b.id: b};

  static Map<String, AppUser> get usersById =>
      {for (final u in allUsers) u.id: u};

  static List<Student> studentsForStop(String stopId) =>
      students.where((s) => s.stopId == stopId).toList();
}

class _StudentSeed {
  const _StudentSeed(
    this.nameAr,
    this.nameEn,
    this.grade,
    this.section,
    this.stopId,
  );

  final String nameAr;
  final String nameEn;
  final String grade;
  final String section;
  final String? stopId;
}

extension on String {
  /// First [count] user-perceived characters. Arabic letters can combine, so
  /// substring on code units would occasionally split a grapheme.
  String characters(int count) => length <= count ? this : substring(0, count);
}
