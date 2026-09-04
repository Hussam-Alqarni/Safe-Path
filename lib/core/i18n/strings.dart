import 'package:flutter/widgets.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/services/navigation_service.dart';

/// Every user-facing string, in both supported languages.
///
/// Kept in one place from the first commit: retrofitting localisation into a
/// Flutter app whose strings are inline is one of the more expensive things a
/// team can do to itself later.
abstract class AppStrings {
  const AppStrings();

  static const supportedLocales = [Locale('ar'), Locale('en')];

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const ArabicStrings();

  static AppStrings forLocale(Locale locale) => locale.languageCode == 'en'
      ? const EnglishStrings()
      : const ArabicStrings();

  bool get isArabic;
  TextDirection get direction =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  // ── product ──────────────────────────────────────────────────────────────
  String get appName;
  String get appTagline;

  // ── roles ────────────────────────────────────────────────────────────────
  String get roleGuardian;
  String get roleDriver;
  String get roleSchoolAdmin;
  String get roleSchoolStaff;
  String get roleDeveloper;

  String roleName(UserRole role) => switch (role) {
        UserRole.guardian => roleGuardian,
        UserRole.driver => roleDriver,
        UserRole.schoolAdmin => roleSchoolAdmin,
        UserRole.schoolStaff => roleSchoolStaff,
        UserRole.developer => roleDeveloper,
      };

  // ── dashboard ────────────────────────────────────────────────────────────
  String get dashAttendanceTrend;
  String get dashAttendanceTrendNote;
  String get dashDriverReliability;
  String get dashDriverReliabilityNote;
  String get dashPunctuality;
  String get dashPunctualityNote;
  String get dashDataGaps;
  String get dashDataGapsNote;
  String get dashNoGaps;
  String get dashTarget;
  String get dashOnTime;
  String get dashLate;
  String get dashEarly;
  String get dashFixNow;

  // ── navigation ───────────────────────────────────────────────────────────
  String get navLive;
  String get navChildren;
  String get navAlerts;
  String get navNotifications;
  String get navRoster;
  String get navRoutes;
  String get navGate;
  String get navFleet;
  String get navReports;
  String get navSystem;
  String get navSettings;

  // ── journey stages ───────────────────────────────────────────────────────
  String stageLabel(JourneyStage stage);

  // ── attendance ───────────────────────────────────────────────────────────
  String eventLabel(AttendanceEventType type);
  String methodLabel(VerificationMethod method);
  String manualReasonLabel(ManualEntryReason reason);
  String absenceReasonLabel(AbsenceReason reason);

  // ── alerts ───────────────────────────────────────────────────────────────
  String alertKindLabel(SafetyAlertKind kind);
  String get emergencyButton;
  String get emergencyHold;
  String get emergencyRaised;
  String get emergencyTitle;
  String emergencyBody(String plate);

  // ── reaching a person ────────────────────────────────────────────────────
  String get contactsTitle;
  String get callOperator;
  String get callDriver;
  String get callFailed;

  // ── no-show ──────────────────────────────────────────────────────────────
  String get noShowConfirmTitle;
  String noShowConfirmBody(String studentName);
  String noShowRecorded(String studentName);
  String get noShowUndo;
  String get noShowUndone;
  String get alertsNone;
  String get alertAcknowledge;
  String get alertAcknowledged;
  String get alertsOpenCount;

  // ── live tracking ────────────────────────────────────────────────────────
  String get liveTracking;
  String get busApproaching;
  String get busArrived;
  String get nextStop;
  String get minutesAway;
  String get lastSeen;
  String get signalLost;
  String get tripNotStarted;
  String get tripCompleted;
  String get onTheWay;
  String get studentsOnBoard;
  String get stopsRemaining;
  String get distanceRemaining;

  // ── driver ───────────────────────────────────────────────────────────────
  String get driverStartTrip;
  String get driverEndTrip;
  String get driverArriveStop;
  String get driverDepartStop;
  String get driverScanCard;
  String get driverTapPrompt;
  String get driverManualEntry;
  String get driverManualEntryTitle;
  String get driverManualEntryExplain;
  String get driverMarkNoShow;
  String get driverBoarded;
  String get driverAlighted;
  String get driverExpectedHere;
  String get driverNobodyHere;
  String get driverEndTripConfirm;
  String get driverEndTripWarning;

  // ── guardian ─────────────────────────────────────────────────────────────
  String get guardianDeclareAbsence;
  String get guardianCancelAbsence;
  String get guardianAbsenceToday;
  String get guardianConfirmManual;
  String get guardianDisputeManual;
  String get guardianConfirmed;
  String get guardianDisputed;
  String get guardianNoChildren;
  String get guardianTodayTimeline;

  // ── admin ────────────────────────────────────────────────────────────────
  String get adminOverview;
  String get adminTotalStudents;
  String get adminOnBus;
  String get adminAtSchool;
  String get adminAbsent;
  String get adminManualRate;
  String get adminActiveTrips;
  String get adminGateAttendance;
  String get adminAllStudents;
  String get adminSearchStudents;
  String get adminNoResults;

  // ── gate ─────────────────────────────────────────────────────────────────
  // ── navigation ───────────────────────────────────────────────────────────
  String get navigate;
  String get exitNavigation;
  String get thenNext;
  String get openInGoogleMaps;
  String get followBus;
  String get showTraffic;
  String maneuverLabel(Maneuver maneuver);
  String maneuverToStop(Maneuver maneuver, String stopName);

  // ── home location ────────────────────────────────────────────────────────
  String get homeLocation;
  String get setHomeFromLink;
  String get changeHome;
  String get pasteMapLinkTitle;
  String get pasteMapLinkHint;
  String get pasteMapLinkExplain;
  String get linkReading;
  String get linkNotRecognised;
  String get linkOutOfRange;
  String get linkFarFromSchool;
  String get linkPreview;
  String get homeSaved;
  String get walkToStop;
  String get noHomeSet;
  String get nearestStop;
  String get assignToStop;
  String get coordinates;

  String get legendServed;
  String get legendUpcoming;
  String get legendSkipped;

  String get gateReader;
  String get gateEntry;
  String get gateExit;
  String get gateSimulateTap;
  String get gateTodayPresent;
  String get gateTodayAbsent;

  // ── developer ────────────────────────────────────────────────────────────
  String get devDiagnostics;
  String get devAuditLog;
  String get devImpersonate;
  String get devImpersonating;
  String get devStopImpersonating;
  String get devImpersonationLogged;
  String get devSimulationControls;
  String get devScenario;
  String get devTriggerLeftOnBus;
  String get devTriggerNoShow;
  String get devSpeedUp;
  String get devReset;
  String get devClearStored;
  String get devClearStoredNote;
  String get devClearStoredDone;
  String get devEventLog;

  // ── generic ──────────────────────────────────────────────────────────────
  String get cancel;
  String get confirm;
  String get close;
  String get save;
  String get retry;
  String get search;
  String get language;
  String get theme;
  String get demoMode;
  String get demoBanner;
  String get signOut;
  String get switchRole;
  String get today;
  String get noData;
  String get student;
  String get students;
  String get bus;
  String get stop;
  String get grade;

  String countStudents(int n);
  String countStops(int n);
  String minutes(int n);
  String metres(int n);
}

class ArabicStrings extends AppStrings {
  const ArabicStrings();

  @override
  bool get isArabic => true;

  @override
  String get appName => 'المسار الآمن';
  @override
  String get appTagline => 'كل طالب محسوب، من الباب إلى الباب';

  @override
  String get roleGuardian => 'ولي أمر';
  @override
  String get roleDriver => 'سائق';
  @override
  String get roleSchoolAdmin => 'إدارة المدرسة';
  @override
  String get roleSchoolStaff => 'موظف المدرسة';
  @override
  String get roleDeveloper => 'مطوّر';

  @override
  String get navLive => 'المباشر';
  @override
  String get navChildren => 'أبنائي';
  @override
  String get navAlerts => 'التنبيهات';
  @override
  String get navNotifications => 'الإشعارات';
  @override
  String get navRoster => 'الطلاب';
  @override
  String get navRoutes => 'المسارات';
  @override
  String get navGate => 'البوابة';
  @override
  String get navFleet => 'الحافلات';
  @override
  String get navReports => 'التقارير';
  @override
  String get navSystem => 'النظام';
  @override
  String get navSettings => 'الإعدادات';

  @override
  String stageLabel(JourneyStage stage) => switch (stage) {
        JourneyStage.notStarted => 'لم يبدأ',
        JourneyStage.onMorningBus => 'في حافلة الذهاب',
        JourneyStage.arrivedAtSchool => 'وصل المدرسة',
        JourneyStage.insideSchool => 'داخل المدرسة',
        JourneyStage.leftSchoolGrounds => 'خرج من المدرسة',
        JourneyStage.onAfternoonBus => 'في حافلة العودة',
        JourneyStage.deliveredHome => 'وصل المنزل',
        JourneyStage.absent => 'غائب',
        JourneyStage.noShow => 'لم يحضر للمحطة',
      };

  @override
  String eventLabel(AttendanceEventType type) => switch (type) {
        AttendanceEventType.boardedBus => 'صعد الحافلة',
        AttendanceEventType.alightedBus => 'نزل من الحافلة',
        AttendanceEventType.enteredSchool => 'دخل المدرسة',
        AttendanceEventType.exitedSchool => 'خرج من المدرسة',
      };

  @override
  String methodLabel(VerificationMethod method) => switch (method) {
        VerificationMethod.nfcCard => 'ببطاقة الطالب',
        VerificationMethod.manualDriver => 'يدوياً بواسطة السائق',
        VerificationMethod.manualStaff => 'يدوياً بواسطة موظف المدرسة',
      };

  @override
  String manualReasonLabel(ManualEntryReason reason) => switch (reason) {
        ManualEntryReason.forgottenCard => 'نسي البطاقة',
        ManualEntryReason.damagedCard => 'البطاقة تالفة',
        ManualEntryReason.readerFault => 'القارئ معطّل',
        ManualEntryReason.other => 'سبب آخر',
      };

  @override
  String absenceReasonLabel(AbsenceReason reason) => switch (reason) {
        AbsenceReason.declaredByGuardian => 'أبلغ ولي الأمر',
        AbsenceReason.noShowAtStop => 'لم يحضر للمحطة',
        AbsenceReason.alternativeTransport => 'وسيلة نقل أخرى',
      };

  @override
  String alertKindLabel(SafetyAlertKind kind) => switch (kind) {
        SafetyAlertKind.emergency => 'استغاثة من السائق',
        SafetyAlertKind.leftOnBus => 'طالب لم يسجّل نزوله',
        SafetyAlertKind.missingGateEntry => 'نزل ولم يدخل المدرسة',
        SafetyAlertKind.leftSchoolNotOnBus => 'خرج ولم يركب الحافلة',
        SafetyAlertKind.guardianDisputed => 'ولي أمر اعترض على تسجيل يدوي',
        SafetyAlertKind.trackerSilent => 'انقطعت إشارة الحافلة',
        SafetyAlertKind.highManualRate => 'نسبة تحضير يدوي مرتفعة',
      };

  @override
  String get emergencyButton => 'استغاثة';
  @override
  String get emergencyHold => 'استمر بالضغط ثانيتين';
  @override
  String get emergencyRaised => 'أُرسلت الاستغاثة للإدارة وأولياء الأمور';
  @override
  String get emergencyTitle => 'استغاثة من الحافلة';
  @override
  String emergencyBody(String plate) =>
      'ضغط سائق الحافلة $plate زر الاستغاثة. الإدارة أُبلغت وتتابع الموقف.';

  @override
  String get contactsTitle => 'أرقام الاتصال';
  @override
  String get callOperator => 'الاتصال بشركة النقل';
  @override
  String get callDriver => 'الاتصال بالسائق';
  @override
  String get callFailed => 'هذا الجهاز لا يجري مكالمات — نُسخ الرقم';

  @override
  String get noShowConfirmTitle => 'تسجيل عدم صعود؟';
  @override
  String noShowConfirmBody(String studentName) =>
      'سيُسجَّل $studentName غائباً عن هذه الرحلة، ويصل إشعار لولي أمره فوراً.';
  @override
  String noShowRecorded(String studentName) => 'سُجِّل عدم صعود $studentName';
  @override
  String get noShowUndo => 'تراجع';
  @override
  String get noShowUndone => 'أُلغي تسجيل عدم الصعود';

  @override
  String get alertsNone => 'لا توجد تنبيهات مفتوحة';
  @override
  String get alertAcknowledge => 'تمت المعالجة';
  @override
  String get alertAcknowledged => 'عولج';
  @override
  String get alertsOpenCount => 'تنبيهات مفتوحة';

  @override
  String get liveTracking => 'التتبّع المباشر';
  @override
  String get busApproaching => 'الحافلة تقترب';
  @override
  String get busArrived => 'الحافلة وصلت';
  @override
  String get nextStop => 'المحطة التالية';
  @override
  String get minutesAway => 'دقيقة على الوصول';
  @override
  String get lastSeen => 'آخر تحديث';
  @override
  String get signalLost => 'انقطعت الإشارة — الموقع غير محدّث';
  @override
  String get tripNotStarted => 'لم تبدأ الرحلة بعد';
  @override
  String get tripCompleted => 'انتهت الرحلة';
  @override
  String get onTheWay => 'في الطريق';
  @override
  String get studentsOnBoard => 'طلاب على متن الحافلة';
  @override
  String get stopsRemaining => 'محطات متبقية';
  @override
  String get distanceRemaining => 'المسافة المتبقية';

  @override
  String get driverStartTrip => 'ابدأ الرحلة';
  @override
  String get driverEndTrip => 'أنهِ الرحلة';
  @override
  String get driverArriveStop => 'وصلت المحطة';
  @override
  String get driverDepartStop => 'غادر المحطة';
  @override
  String get driverScanCard => 'قراءة بطاقة';
  @override
  String get driverTapPrompt => 'مرّر بطاقة الطالب على القارئ';
  @override
  String get driverManualEntry => 'تحضير يدوي';
  @override
  String get driverManualEntryTitle => 'تسجيل بدون بطاقة';
  @override
  String get driverManualEntryExplain =>
      'سيصل ولي الأمر إشعار يوضّح أن التسجيل تم يدوياً بدون بطاقة، مع إمكانية الاعتراض.';
  @override
  String get driverMarkNoShow => 'لم يحضر';
  @override
  String get driverBoarded => 'صعدوا';
  @override
  String get driverAlighted => 'نزلوا';
  @override
  String get driverExpectedHere => 'المتوقعون في هذه المحطة';
  @override
  String get driverNobodyHere => 'لا أحد في هذه المحطة اليوم';
  @override
  String get driverEndTripConfirm => 'تأكيد إنهاء الرحلة';
  @override
  String get driverEndTripWarning =>
      'سيفحص النظام الحافلة: أي طالب صعد ولم يسجّل نزوله سيُرفع عنه تنبيه فوري.';

  @override
  String get guardianDeclareAbsence => 'الإبلاغ عن غياب';
  @override
  String get guardianCancelAbsence => 'إلغاء الغياب';
  @override
  String get guardianAbsenceToday => 'غائب اليوم';
  @override
  String get guardianConfirmManual => 'نعم، هذا صحيح';
  @override
  String get guardianDisputeManual => 'هذا غير صحيح';
  @override
  String get guardianConfirmed => 'أكّدت';
  @override
  String get guardianDisputed => 'اعترضت';
  @override
  String get guardianNoChildren => 'لا يوجد أبناء مرتبطون بحسابك';
  @override
  String get guardianTodayTimeline => 'مسار اليوم';

  @override
  String get adminOverview => 'نظرة عامة';
  @override
  String get adminTotalStudents => 'إجمالي الطلاب';
  @override
  String get adminOnBus => 'في الحافلات';
  @override
  String get adminAtSchool => 'داخل المدرسة';
  @override
  String get adminAbsent => 'غائبون';
  @override
  String get adminManualRate => 'نسبة التحضير اليدوي';
  @override
  String get adminActiveTrips => 'رحلات جارية';
  @override
  String get adminGateAttendance => 'حضور البوابة';
  @override
  String get adminAllStudents => 'جميع الطلاب';
  @override
  String get adminSearchStudents => 'ابحث باسم الطالب أو الصف';
  @override
  String get adminNoResults => 'لا نتائج';

  @override
  String get dashAttendanceTrend => 'نسبة الحضور — آخر ١٠ أيام';
  @override
  String get dashAttendanceTrendNote => 'من إجمالي طلاب الحافلات';
  @override
  String get dashDriverReliability => 'التحضير اليدوي حسب السائق';
  @override
  String get dashDriverReliabilityNote =>
      'ارتفاع النسبة لسائق واحد يعني غالباً قارئاً معطّلاً';
  @override
  String get dashPunctuality => 'الالتزام بالمواعيد حسب المسار';
  @override
  String get dashPunctualityNote => 'متوسط الفارق عن الوقت المخطّط';
  @override
  String get dashDataGaps => 'نواقص البيانات';
  @override
  String get dashDataGapsNote => 'طلاب بلا موقع منزل مسجّل';
  @override
  String get dashNoGaps => 'لا نواقص — كل الطلاب لديهم موقع';
  @override
  String get dashTarget => 'المستهدف';
  @override
  String get dashOnTime => 'في الموعد';
  @override
  String get dashLate => 'متأخر';
  @override
  String get dashEarly => 'مبكر';
  @override
  String get dashFixNow => 'استكمال';

  @override
  String get navigate => 'الملاحة';
  @override
  String get exitNavigation => 'إنهاء الملاحة';
  @override
  String get thenNext => 'ثم';
  @override
  String get openInGoogleMaps => 'فتح في خرائط جوجل';
  @override
  String get followBus => 'تتبّع الحافلة';
  @override
  String get showTraffic => 'حركة المرور';

  @override
  String maneuverLabel(Maneuver maneuver) => switch (maneuver) {
        Maneuver.depart => 'انطلق',
        Maneuver.straight => 'واصل مستقيماً',
        Maneuver.slightLeft => 'انحرف يساراً قليلاً',
        Maneuver.left => 'انعطف يساراً',
        Maneuver.sharpLeft => 'انعطف يساراً بحدة',
        Maneuver.slightRight => 'انحرف يميناً قليلاً',
        Maneuver.right => 'انعطف يميناً',
        Maneuver.sharpRight => 'انعطف يميناً بحدة',
        Maneuver.uTurn => 'استدر للخلف',
        Maneuver.arriveStop => 'وصلت المحطة',
        Maneuver.arriveDestination => 'وصلت المدرسة',
      };

  @override
  String maneuverToStop(Maneuver maneuver, String stopName) =>
      maneuver == Maneuver.arriveStop
          ? 'محطة $stopName'
          : maneuverLabel(maneuver);

  @override
  String get homeLocation => 'موقع المنزل';
  @override
  String get setHomeFromLink => 'تحديد الموقع برابط';
  @override
  String get changeHome => 'تغيير الموقع';
  @override
  String get pasteMapLinkTitle => 'الصق رابط الموقع';
  @override
  String get pasteMapLinkHint => 'https://maps.app.goo.gl/...';
  @override
  String get pasteMapLinkExplain =>
      'شارك موقع المنزل من خرائط جوجل أو واتساب، ثم الصق الرابط هنا. '
      'يُقبل أيضاً لصق الإحداثيات مباشرة.';
  @override
  String get linkReading => 'جارٍ قراءة الرابط…';
  @override
  String get linkNotRecognised =>
      'لم نتمكّن من قراءة موقع من هذا الرابط. تأكد أنه رابط موقع من خرائط جوجل.';
  @override
  String get linkOutOfRange => 'الإحداثيات في هذا الرابط غير صالحة.';
  @override
  String get linkFarFromSchool =>
      'هذا الموقع بعيد جداً عن المدرسة. تحقق قبل الحفظ — غالباً انعكس ترتيب خط الطول والعرض.';
  @override
  String get linkPreview => 'الموقع المقروء';
  @override
  String get homeSaved => 'حُفظ موقع المنزل';
  @override
  String get walkToStop => 'المسافة إلى المحطة';
  @override
  String get noHomeSet => 'لم يُحدَّد موقع المنزل بعد';
  @override
  String get nearestStop => 'أقرب محطة';
  @override
  String get assignToStop => 'إسناد لهذه المحطة';
  @override
  String get coordinates => 'الإحداثيات';

  @override
  String get legendServed => 'تمت';
  @override
  String get legendUpcoming => 'قادمة';
  @override
  String get legendSkipped => 'متخطّاة';

  @override
  String get gateReader => 'قارئ البوابة';
  @override
  String get gateEntry => 'دخول';
  @override
  String get gateExit => 'خروج';
  @override
  String get gateSimulateTap => 'محاكاة تمرير بطاقة';
  @override
  String get gateTodayPresent => 'حاضرون اليوم';
  @override
  String get gateTodayAbsent => 'لم يصلوا بعد';

  @override
  String get devDiagnostics => 'تشخيص النظام';
  @override
  String get devAuditLog => 'سجل التدقيق';
  @override
  String get devImpersonate => 'انتحال دور';
  @override
  String get devImpersonating => 'أنت تنتحل دور';
  @override
  String get devStopImpersonating => 'إنهاء الانتحال';
  @override
  String get devImpersonationLogged =>
      'كل جلسة انتحال مسجّلة في سجل التدقيق وتنتهي تلقائياً بعد ساعة.';
  @override
  String get devSimulationControls => 'تحكّم المحاكاة';
  @override
  String get devScenario => 'سيناريو';
  @override
  String get devTriggerLeftOnBus => 'محاكاة طالب متروك';
  @override
  String get devTriggerNoShow => 'محاكاة طالب لم يحضر';
  @override
  String get devSpeedUp => 'تسريع';
  @override
  String get devReset => 'إعادة تعيين';
  @override
  String get devClearStored => 'مسح البيانات المحفوظة على هذا الجهاز';
  @override
  String get devClearStoredNote =>
      'يمسح نسخة اليوم المحفوظة على هذا الجهاز ويوقف الحفظ حتى إعادة التشغيل. '
      'ما يظهر على الشاشة الآن لا يتغيّر، والسجل المعتمد يبقى على الخادم.';
  @override
  String get devClearStoredDone =>
      'مُسحت البيانات المحفوظة. يبدأ التطبيق نظيفاً عند إعادة تشغيله.';
  @override
  String get devEventLog => 'سجل الأحداث';

  @override
  String get cancel => 'إلغاء';
  @override
  String get confirm => 'تأكيد';
  @override
  String get close => 'إغلاق';
  @override
  String get save => 'حفظ';
  @override
  String get retry => 'إعادة المحاولة';
  @override
  String get search => 'بحث';
  @override
  String get language => 'اللغة';
  @override
  String get theme => 'المظهر';
  @override
  String get demoMode => 'وضع العرض';
  @override
  String get demoBanner => 'بيانات محاكاة — لا حافلات حقيقية';
  @override
  String get signOut => 'خروج';
  @override
  String get switchRole => 'تبديل الدور';
  @override
  String get today => 'اليوم';
  @override
  String get noData => 'لا توجد بيانات';
  @override
  String get student => 'طالب';
  @override
  String get students => 'طلاب';
  @override
  String get bus => 'حافلة';
  @override
  String get stop => 'محطة';
  @override
  String get grade => 'الصف';

  @override
  String countStudents(int n) => switch (n) {
        0 => 'لا طلاب',
        1 => 'طالب واحد',
        2 => 'طالبان',
        _ when n <= 10 => '$n طلاب',
        _ => '$n طالباً',
      };

  @override
  String countStops(int n) => switch (n) {
        0 => 'لا محطات',
        1 => 'محطة واحدة',
        2 => 'محطتان',
        _ when n <= 10 => '$n محطات',
        _ => '$n محطة',
      };

  @override
  String minutes(int n) => switch (n) {
        0 => 'الآن',
        1 => 'دقيقة',
        2 => 'دقيقتان',
        _ when n <= 10 => '$n دقائق',
        _ => '$n دقيقة',
      };

  @override
  String metres(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)} كم' : '$n م';
}

class EnglishStrings extends AppStrings {
  const EnglishStrings();

  @override
  bool get isArabic => false;

  @override
  String get appName => 'Safe Path';
  @override
  String get appTagline => 'Every student accounted for, door to door';

  @override
  String get roleGuardian => 'Guardian';
  @override
  String get roleDriver => 'Driver';
  @override
  String get roleSchoolAdmin => 'School admin';
  @override
  String get roleSchoolStaff => 'School staff';
  @override
  String get roleDeveloper => 'Developer';

  @override
  String get navLive => 'Live';
  @override
  String get navChildren => 'My children';
  @override
  String get navAlerts => 'Alerts';
  @override
  String get navNotifications => 'Notifications';
  @override
  String get navRoster => 'Students';
  @override
  String get navRoutes => 'Routes';
  @override
  String get navGate => 'Gate';
  @override
  String get navFleet => 'Fleet';
  @override
  String get navReports => 'Reports';
  @override
  String get navSystem => 'System';
  @override
  String get navSettings => 'Settings';

  @override
  String stageLabel(JourneyStage stage) => switch (stage) {
        JourneyStage.notStarted => 'Not started',
        JourneyStage.onMorningBus => 'On the morning bus',
        JourneyStage.arrivedAtSchool => 'Arrived at school',
        JourneyStage.insideSchool => 'Inside school',
        JourneyStage.leftSchoolGrounds => 'Left school grounds',
        JourneyStage.onAfternoonBus => 'On the afternoon bus',
        JourneyStage.deliveredHome => 'Home',
        JourneyStage.absent => 'Absent',
        JourneyStage.noShow => 'Did not board',
      };

  @override
  String eventLabel(AttendanceEventType type) => switch (type) {
        AttendanceEventType.boardedBus => 'Boarded the bus',
        AttendanceEventType.alightedBus => 'Left the bus',
        AttendanceEventType.enteredSchool => 'Entered school',
        AttendanceEventType.exitedSchool => 'Left school',
      };

  @override
  String methodLabel(VerificationMethod method) => switch (method) {
        VerificationMethod.nfcCard => 'Card scanned',
        VerificationMethod.manualDriver => 'Entered by the driver',
        VerificationMethod.manualStaff => 'Entered by school staff',
      };

  @override
  String manualReasonLabel(ManualEntryReason reason) => switch (reason) {
        ManualEntryReason.forgottenCard => 'Card left at home',
        ManualEntryReason.damagedCard => 'Card damaged',
        ManualEntryReason.readerFault => 'Reader fault',
        ManualEntryReason.other => 'Other',
      };

  @override
  String absenceReasonLabel(AbsenceReason reason) => switch (reason) {
        AbsenceReason.declaredByGuardian => 'Reported by guardian',
        AbsenceReason.noShowAtStop => 'Did not board',
        AbsenceReason.alternativeTransport => 'Other transport',
      };

  @override
  String alertKindLabel(SafetyAlertKind kind) => switch (kind) {
        SafetyAlertKind.emergency => 'Driver raised an emergency',
        SafetyAlertKind.leftOnBus => 'Never scanned off the bus',
        SafetyAlertKind.missingGateEntry => 'Off the bus, not through the gate',
        SafetyAlertKind.leftSchoolNotOnBus => 'Left school, not on a bus',
        SafetyAlertKind.guardianDisputed => 'Guardian disputed a manual record',
        SafetyAlertKind.trackerSilent => 'Bus signal lost',
        SafetyAlertKind.highManualRate => 'High manual-entry rate',
      };

  @override
  String get emergencyButton => 'Emergency';
  @override
  String get emergencyHold => 'Hold for two seconds';
  @override
  String get emergencyRaised => 'Emergency sent to the school and guardians';
  @override
  String get emergencyTitle => 'Emergency on the bus';
  @override
  String emergencyBody(String plate) =>
      'The driver of bus $plate raised an emergency. The school has been '
      'notified and is handling it.';

  @override
  String get contactsTitle => 'Contacts';
  @override
  String get callOperator => 'Call the transport company';
  @override
  String get callDriver => 'Call the driver';
  @override
  String get callFailed => 'This device cannot place calls — number copied';

  @override
  String get noShowConfirmTitle => 'Mark as not boarded?';
  @override
  String noShowConfirmBody(String studentName) =>
      '$studentName will be recorded absent for this run, and their guardian '
      'is notified straight away.';
  @override
  String noShowRecorded(String studentName) =>
      '$studentName recorded as not boarded';
  @override
  String get noShowUndo => 'Undo';
  @override
  String get noShowUndone => 'No-show record removed';

  @override
  String get alertsNone => 'No open alerts';
  @override
  String get alertAcknowledge => 'Mark handled';
  @override
  String get alertAcknowledged => 'Handled';
  @override
  String get alertsOpenCount => 'open alerts';

  @override
  String get liveTracking => 'Live tracking';
  @override
  String get busApproaching => 'Bus approaching';
  @override
  String get busArrived => 'Bus has arrived';
  @override
  String get nextStop => 'Next stop';
  @override
  String get minutesAway => 'minutes away';
  @override
  String get lastSeen => 'Last update';
  @override
  String get signalLost => 'Signal lost — position is not current';
  @override
  String get tripNotStarted => 'Trip has not started';
  @override
  String get tripCompleted => 'Trip complete';
  @override
  String get onTheWay => 'On the way';
  @override
  String get studentsOnBoard => 'students on board';
  @override
  String get stopsRemaining => 'stops remaining';
  @override
  String get distanceRemaining => 'Distance remaining';

  @override
  String get driverStartTrip => 'Start trip';
  @override
  String get driverEndTrip => 'End trip';
  @override
  String get driverArriveStop => 'Arrived at stop';
  @override
  String get driverDepartStop => 'Depart stop';
  @override
  String get driverScanCard => 'Scan a card';
  @override
  String get driverTapPrompt => 'Tap the student card on the reader';
  @override
  String get driverManualEntry => 'Manual entry';
  @override
  String get driverManualEntryTitle => 'Record without a card';
  @override
  String get driverManualEntryExplain =>
      'The guardian is told plainly that this was entered by hand without a '
      'card, and can dispute it.';
  @override
  String get driverMarkNoShow => 'Did not board';
  @override
  String get driverBoarded => 'Boarded';
  @override
  String get driverAlighted => 'Left the bus';
  @override
  String get driverExpectedHere => 'Expected at this stop';
  @override
  String get driverNobodyHere => 'Nobody is due at this stop today';
  @override
  String get driverEndTripConfirm => 'Confirm end of trip';
  @override
  String get driverEndTripWarning =>
      'Safe Path will check the bus: anyone who boarded without scanning off '
      'raises an immediate alert.';

  @override
  String get guardianDeclareAbsence => 'Report an absence';
  @override
  String get guardianCancelAbsence => 'Cancel absence';
  @override
  String get guardianAbsenceToday => 'Absent today';
  @override
  String get guardianConfirmManual => 'Yes, that is right';
  @override
  String get guardianDisputeManual => 'That is not right';
  @override
  String get guardianConfirmed => 'Confirmed';
  @override
  String get guardianDisputed => 'Disputed';
  @override
  String get guardianNoChildren => 'No children linked to your account';
  @override
  String get guardianTodayTimeline => "Today's journey";

  @override
  String get adminOverview => 'Overview';
  @override
  String get adminTotalStudents => 'Total students';
  @override
  String get adminOnBus => 'On a bus';
  @override
  String get adminAtSchool => 'Inside school';
  @override
  String get adminAbsent => 'Absent';
  @override
  String get adminManualRate => 'Manual entry rate';
  @override
  String get adminActiveTrips => 'Active trips';
  @override
  String get adminGateAttendance => 'Gate attendance';
  @override
  String get adminAllStudents => 'All students';
  @override
  String get adminSearchStudents => 'Search by name or grade';
  @override
  String get adminNoResults => 'No results';

  @override
  String get dashAttendanceTrend => 'Attendance rate — last 10 days';
  @override
  String get dashAttendanceTrendNote => 'of all bus riders';
  @override
  String get dashDriverReliability => 'Manual entry by driver';
  @override
  String get dashDriverReliabilityNote =>
      'A rate climbing for one driver usually means a failing reader';
  @override
  String get dashPunctuality => 'Punctuality by route';
  @override
  String get dashPunctualityNote => 'Average difference from the plan';
  @override
  String get dashDataGaps => 'Data gaps';
  @override
  String get dashDataGapsNote => 'Students with no home location recorded';
  @override
  String get dashNoGaps => 'No gaps — every student has a location';
  @override
  String get dashTarget => 'Target';
  @override
  String get dashOnTime => 'on time';
  @override
  String get dashLate => 'late';
  @override
  String get dashEarly => 'early';
  @override
  String get dashFixNow => 'Complete';

  @override
  String get navigate => 'Navigate';
  @override
  String get exitNavigation => 'Exit navigation';
  @override
  String get thenNext => 'then';
  @override
  String get openInGoogleMaps => 'Open in Google Maps';
  @override
  String get followBus => 'Follow the bus';
  @override
  String get showTraffic => 'Traffic';

  @override
  String maneuverLabel(Maneuver maneuver) => switch (maneuver) {
        Maneuver.depart => 'Start driving',
        Maneuver.straight => 'Continue straight',
        Maneuver.slightLeft => 'Bear left',
        Maneuver.left => 'Turn left',
        Maneuver.sharpLeft => 'Sharp left',
        Maneuver.slightRight => 'Bear right',
        Maneuver.right => 'Turn right',
        Maneuver.sharpRight => 'Sharp right',
        Maneuver.uTurn => 'Make a U-turn',
        Maneuver.arriveStop => 'Arrive at the stop',
        Maneuver.arriveDestination => 'Arrive at the school',
      };

  @override
  String maneuverToStop(Maneuver maneuver, String stopName) =>
      maneuver == Maneuver.arriveStop
          ? 'Stop: $stopName'
          : maneuverLabel(maneuver);

  @override
  String get homeLocation => 'Home location';
  @override
  String get setHomeFromLink => 'Set from a map link';
  @override
  String get changeHome => 'Change location';
  @override
  String get pasteMapLinkTitle => 'Paste a location link';
  @override
  String get pasteMapLinkHint => 'https://maps.app.goo.gl/...';
  @override
  String get pasteMapLinkExplain =>
      'Share the home location from Google Maps or WhatsApp, then paste the '
      'link here. Plain coordinates work too.';
  @override
  String get linkReading => 'Reading the link…';
  @override
  String get linkNotRecognised =>
      'No location could be read from that link. Check that it is a Google '
      'Maps location link.';
  @override
  String get linkOutOfRange => 'The coordinates in that link are not valid.';
  @override
  String get linkFarFromSchool =>
      'This location is a long way from the school. Check before saving — '
      'latitude and longitude are usually the wrong way round.';
  @override
  String get linkPreview => 'Location found';
  @override
  String get homeSaved => 'Home location saved';
  @override
  String get walkToStop => 'Walk to the stop';
  @override
  String get noHomeSet => 'No home location set yet';
  @override
  String get nearestStop => 'Nearest stop';
  @override
  String get assignToStop => 'Assign to this stop';
  @override
  String get coordinates => 'Coordinates';

  @override
  String get legendServed => 'Served';
  @override
  String get legendUpcoming => 'Upcoming';
  @override
  String get legendSkipped => 'Skipped';

  @override
  String get gateReader => 'Gate reader';
  @override
  String get gateEntry => 'Entry';
  @override
  String get gateExit => 'Exit';
  @override
  String get gateSimulateTap => 'Simulate a card tap';
  @override
  String get gateTodayPresent => 'Present today';
  @override
  String get gateTodayAbsent => 'Not yet arrived';

  @override
  String get devDiagnostics => 'Diagnostics';
  @override
  String get devAuditLog => 'Audit log';
  @override
  String get devImpersonate => 'Impersonate a role';
  @override
  String get devImpersonating => 'Impersonating';
  @override
  String get devStopImpersonating => 'Stop impersonating';
  @override
  String get devImpersonationLogged =>
      'Every impersonation session is written to the audit log and expires '
      'after one hour.';
  @override
  String get devSimulationControls => 'Simulation controls';
  @override
  String get devScenario => 'Scenario';
  @override
  String get devTriggerLeftOnBus => 'Simulate a student left on board';
  @override
  String get devTriggerNoShow => 'Simulate a no-show';
  @override
  String get devSpeedUp => 'Speed up';
  @override
  String get devReset => 'Reset';
  @override
  String get devClearStored => 'Clear data stored on this device';
  @override
  String get devClearStoredNote =>
      'Clears this device\'s copy of today and stops saving until the app is '
      'restarted. What is on screen now is left alone, and the record of '
      'authority stays on the server.';
  @override
  String get devClearStoredDone =>
      'Stored data cleared. The app starts clean on its next launch.';
  @override
  String get devEventLog => 'Event log';

  @override
  String get cancel => 'Cancel';
  @override
  String get confirm => 'Confirm';
  @override
  String get close => 'Close';
  @override
  String get save => 'Save';
  @override
  String get retry => 'Retry';
  @override
  String get search => 'Search';
  @override
  String get language => 'Language';
  @override
  String get theme => 'Theme';
  @override
  String get demoMode => 'Demo mode';
  @override
  String get demoBanner => 'Simulated data — no real buses';
  @override
  String get signOut => 'Sign out';
  @override
  String get switchRole => 'Switch role';
  @override
  String get today => 'Today';
  @override
  String get noData => 'No data';
  @override
  String get student => 'student';
  @override
  String get students => 'students';
  @override
  String get bus => 'Bus';
  @override
  String get stop => 'Stop';
  @override
  String get grade => 'Grade';

  @override
  String countStudents(int n) => n == 1 ? '1 student' : '$n students';

  @override
  String countStops(int n) => n == 1 ? '1 stop' : '$n stops';

  @override
  String minutes(int n) => switch (n) {
        0 => 'now',
        1 => '1 minute',
        _ => '$n minutes',
      };

  @override
  String metres(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)} km' : '$n m';
}

/// Wires [AppStrings] into Flutter's localisation machinery.
class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'ar' || locale.languageCode == 'en';

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings.forLocale(locale);

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}
