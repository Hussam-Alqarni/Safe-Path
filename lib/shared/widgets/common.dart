import 'package:flutter/material.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/domain/enums.dart';

/// Colour pairing for one journey stage. Kept in one place so a stage always
/// looks the same wherever it appears.
({Color fg, Color bg, IconData icon}) stageStyle(
  BuildContext context,
  JourneyStage stage,
) {
  final c = context.colors;
  return switch (stage) {
    JourneyStage.onMorningBus || JourneyStage.onAfternoonBus => (
        fg: c.onBus,
        bg: c.onBusSurface,
        icon: Icons.directions_bus_rounded
      ),
    JourneyStage.arrivedAtSchool || JourneyStage.insideSchool => (
        fg: c.atSchool,
        bg: c.atSchoolSurface,
        icon: Icons.school_rounded
      ),
    JourneyStage.deliveredHome => (
        fg: c.delivered,
        bg: c.deliveredSurface,
        icon: Icons.home_rounded
      ),
    JourneyStage.absent || JourneyStage.noShow => (
        fg: c.absent,
        bg: c.absentSurface,
        icon: Icons.event_busy_rounded
      ),
    JourneyStage.leftSchoolGrounds => (
        fg: c.manual,
        bg: c.manualSurface,
        icon: Icons.logout_rounded
      ),
    JourneyStage.notStarted => (
        fg: c.inkMuted,
        bg: c.sunken,
        icon: Icons.schedule_rounded
      ),
  };
}

({Color fg, Color bg}) severityStyle(BuildContext context, AlertSeverity s) {
  final c = context.colors;
  return switch (s) {
    AlertSeverity.critical => (fg: c.critical, bg: c.criticalSurface),
    AlertSeverity.warning => (fg: c.manual, bg: c.manualSurface),
    AlertSeverity.info => (fg: c.inkSoft, bg: c.sunken),
  };
}

/// A compact status chip. State is encoded in shape and colour as well as
/// text, so it reads at a glance without being parsed.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
    this.dense = false,
    super.key,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? Gap.sm : Gap.md,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: foreground),
            const SizedBox(width: Gap.xs),
          ],
          Text(
            label,
            style: (dense ? text.labelSmall : text.labelMedium)
                ?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// One headline number with its label.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.accent,
    this.caption,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final Color? accent;
  final String? caption;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final tint = accent ?? c.ink;

    return Semantics(
      label: label,
      value: caption == null ? value : '$value, $caption',
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: tint),
                  const SizedBox(width: Gap.sm),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              value,
              style: text.headlineMedium?.copyWith(
                color: tint,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(caption!, style: text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// A titled block. Every screen is built from these, so section rhythm is
/// identical throughout the app.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
    this.padded = true,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final String? subtitle;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.md, Gap.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleMedium),
                      if (subtitle != null)
                        Text(subtitle!, style: text.bodySmall),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(height: 1, color: c.line),
          Padding(
            padding: padded ? const EdgeInsets.all(Gap.lg) : EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Circular initials badge. Photographs of children are deliberately not part
/// of this product — initials carry enough identity for a roster.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    required this.initials,
    this.size = 40,
    this.color,
    super.key,
  });

  final String initials;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = color ?? c.brand;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tint,
              fontSize: size * 0.34,
            ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
    super.key,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: Gap.xxl, horizontal: Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: c.inkMuted),
          const SizedBox(height: Gap.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.inkSoft,
                ),
          ),
          if (action != null) ...[
            const SizedBox(height: Gap.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// The persistent reminder that nothing on screen is a real bus.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = AppStrings.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.sm,
      ),
      color: c.manualSurface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_rounded, size: 14, color: c.manual),
          const SizedBox(width: Gap.sm),
          Flexible(
            child: Text(
              s.demoBanner,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.manual,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats a wall-clock time with tabular digits so columns of times align.
String formatClock(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

String formatRelative(BuildContext context, DateTime at, DateTime now) {
  final s = AppStrings.of(context);
  final diff = now.difference(at);
  if (diff.inSeconds < 45) return s.isArabic ? 'الآن' : 'just now';
  if (diff.inMinutes < 60) return s.minutes(diff.inMinutes);
  return formatClock(at);
}
