import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/features/admin/admin_screens.dart';
import 'package:safe_path/shared/widgets/common.dart';

/// The school gate.
///
/// This is where Safe Path stops being a bus product: the gate reader records
/// every student, riders and walkers alike, and it closes the gap between the
/// bus door and the school door that a bus reader alone cannot see.
class StaffGateScreen extends ConsumerWidget {
  const StaffGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final state = ref.watch(controllerProvider);

    final inside = <Student>[];
    final outside = <Student>[];
    for (final student in SeedData.students) {
      final events = state.attendanceEvents.where(
        (e) => e.studentId == student.id && e.type.isGateEvent,
      );
      var isInside = false;
      for (final event in events) {
        isInside = event.type == AttendanceEventType.enteredSchool;
      }
      (isInside ? inside : outside).add(student);
    }

    return ListView(
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: s.gateTodayPresent,
                value: '${inside.length}',
                icon: Icons.login_rounded,
                accent: c.delivered,
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: StatTile(
                label: s.gateTodayAbsent,
                value: '${outside.length}',
                icon: Icons.pending_outlined,
                accent: c.inkSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        _ReaderPanel(),
        const SizedBox(height: Gap.lg),
        SectionCard(
          title: s.gateTodayPresent,
          subtitle: s.countStudents(inside.length),
          padded: false,
          child: inside.isEmpty
              ? EmptyState(message: s.noData, icon: Icons.school_rounded)
              : Column(
                  children: [
                    for (final student in inside.take(12))
                      _GateRow(student: student, inside: true),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Stands in for the physical reader.
///
/// In the pilot a card tap arrives from the hardware; here it arrives from a
/// button. Everything downstream — the event, the notification, the anomaly
/// checks — is the same code either way.
class _ReaderPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;

    return SectionCard(
      title: s.gateReader,
      subtitle: s.driverTapPrompt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: Gap.xl),
            decoration: BoxDecoration(
              color: c.brandSurface,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Column(
              children: [
                Icon(Icons.contactless_rounded, size: 42, color: c.brand),
                const SizedBox(height: Gap.sm),
                Text(
                  s.gateSimulateTap,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: c.brand),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
          FilledButton.icon(
            icon: const Icon(Icons.person_search_rounded),
            label: Text(s.gateSimulateTap),
            onPressed: () => _pickStudent(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStudent(BuildContext context, WidgetRef ref) async {
    final s = AppStrings.of(context);
    final student = await showModalBottomSheet<Student>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Directionality(
        textDirection: s.direction,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (_, scrollController) => ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
            itemCount: SeedData.students.length,
            itemBuilder: (_, i) {
              final student = SeedData.students[i];
              return ListTile(
                leading: InitialsAvatar(
                  initials: student.photoInitials,
                  size: 34,
                ),
                title: Text(
                  s.isArabic ? student.fullNameAr : student.fullNameEn,
                ),
                subtitle: Text(
                  '${s.grade} ${student.grade}${student.section} · ${student.cardUid}',
                ),
                onTap: () => Navigator.of(sheetContext).pop(student),
              );
            },
          ),
        ),
      ),
    );

    if (student == null) return;
    ref.read(controllerProvider.notifier).recordGateAttendance(
          studentId: student.id,
          method: VerificationMethod.nfcCard,
          at: DateTime.now(),
        );
  }
}

class _GateRow extends ConsumerWidget {
  const _GateRow({required this.student, required this.inside});

  final Student student;
  final bool inside;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final snapshot = ref.watch(studentSnapshotProvider(student.id));
    final lastGate = snapshot.events
        .where((e) => e.type.isGateEvent)
        .lastOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            initials: student.photoInitials,
            size: 34,
            color: inside ? c.delivered : c.inkSoft,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              s.isArabic ? student.fullNameAr : student.fullNameEn,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (lastGate != null)
            Text(
              formatClock(lastGate.occurredAt),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: c.inkSoft,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
        ],
      ),
    );
  }
}

/// Staff see the same roster as an administrator, read-only.
class StaffRosterScreen extends ConsumerWidget {
  const StaffRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        for (final student in SeedData.students)
          StudentRosterRow(student: student),
      ],
    );
  }
}
