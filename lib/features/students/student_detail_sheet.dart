import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/features/students/home_location_sheet.dart';
import 'package:safe_path/shared/widgets/common.dart';

/// One student's record: today's state, where they live, and what the walk to
/// their stop actually is.
Future<void> showStudentDetail(
  BuildContext context,
  WidgetRef ref,
  String studentId,
) {
  final s = AppStrings.of(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Directionality(
      textDirection: s.direction,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scrollController) => _StudentDetail(
          studentId: studentId,
          scrollController: scrollController,
        ),
      ),
    ),
  );
}

class _StudentDetail extends ConsumerWidget {
  const _StudentDetail({
    required this.studentId,
    required this.scrollController,
  });

  final String studentId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final state = ref.watch(controllerProvider);
    final student = state.studentsById[studentId];
    if (student == null) return const SizedBox.shrink();

    final snapshot = ref.watch(studentSnapshotProvider(studentId));
    final style = stageStyle(context, snapshot.stage);
    final stop = student.stopId == null
        ? null
        : SeedData.stopsById[student.stopId];
    final walk = student.walkToStopMetres(stop)?.round();
    final canEdit = ref.watch(effectiveRoleProvider).canEditStudents;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      children: [
        Row(
          children: [
            InitialsAvatar(
              initials: student.photoInitials,
              size: 48,
              color: style.fg,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.isArabic ? student.fullNameAr : student.fullNameEn,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${s.grade} ${student.grade}${student.section} · '
                    '${student.cardUid}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        StatusPill(
          label: s.stageLabel(snapshot.stage),
          foreground: style.fg,
          background: style.bg,
          icon: style.icon,
        ),
        const SizedBox(height: Gap.xl),

        SectionCard(
          title: s.homeLocation,
          trailing: canEdit
              ? TextButton.icon(
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 17),
                  label: Text(
                    student.hasHome ? s.changeHome : s.setHomeFromLink,
                  ),
                  onPressed: () =>
                      showHomeLocationSheet(context, ref, student),
                )
              : null,
          child: student.hasHome
              ? _HomeDetails(student: student, stop: stop, walkMetres: walk)
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                  child: Text(
                    s.noHomeSet,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.inkMuted),
                  ),
                ),
        ),

        if (snapshot.events.isNotEmpty) ...[
          const SizedBox(height: Gap.lg),
          SectionCard(
            title: s.guardianTodayTimeline,
            padded: false,
            child: Column(
              children: [
                for (final event in snapshot.events)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg,
                      vertical: Gap.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: c.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.eventLabel(event.type),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        if (event.isManual)
                          Padding(
                            padding: const EdgeInsets.only(left: Gap.sm),
                            child: StatusPill(
                              label: s.methodLabel(event.method),
                              foreground: c.manual,
                              background: c.manualSurface,
                              dense: true,
                            ),
                          ),
                        Text(
                          formatClock(event.occurredAt),
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: c.inkSoft,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeDetails extends StatelessWidget {
  const _HomeDetails({
    required this.student,
    required this.stop,
    required this.walkMetres,
  });

  final Student student;
  final BusStop? stop;
  final int? walkMetres;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final home = student.homeLocation!;

    Widget row(String label, String value, {Color? accent, bool ltr = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                value,
                textDirection: ltr ? TextDirection.ltr : null,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: accent ?? c.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (student.homeLabel != null)
          row(s.homeLocation, student.homeLabel!),
        row(
          s.coordinates,
          '${home.latitude.toStringAsFixed(5)}, '
          '${home.longitude.toStringAsFixed(5)}',
          ltr: true,
        ),
        if (stop != null) row(s.stop, s.isArabic ? stop!.nameAr : stop!.nameEn),
        if (walkMetres != null)
          // A long walk is worth flagging: it usually means the student is
          // assigned to the wrong stop, which is a safety issue before it is
          // a convenience one.
          row(
            s.walkToStop,
            s.metres(walkMetres!),
            accent: walkMetres! > 600 ? c.manual : c.delivered,
          ),
      ],
    );
  }
}
