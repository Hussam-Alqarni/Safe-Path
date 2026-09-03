import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';
import 'package:safe_path/domain/services/location_link_parser.dart';
import 'package:safe_path/features/map/schematic_map.dart';

/// Sets a student's home from a shared map link.
///
/// A parent in Saudi Arabia shares their address as a WhatsApp location, which
/// arrives as a Google Maps link. Accepting that link directly is the shortest
/// honest path from "where do you live" to a pickup point; asking anyone to
/// type coordinates is not a real option.
Future<void> showHomeLocationSheet(
  BuildContext context,
  WidgetRef ref,
  Student student,
) {
  final s = AppStrings.of(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Directionality(
      textDirection: s.direction,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (_, scrollController) => _HomeLocationForm(
            student: student,
            scrollController: scrollController,
          ),
        ),
      ),
    ),
  );
}

class _HomeLocationForm extends ConsumerStatefulWidget {
  const _HomeLocationForm({
    required this.student,
    required this.scrollController,
  });

  final Student student;
  final ScrollController scrollController;

  @override
  ConsumerState<_HomeLocationForm> createState() => _HomeLocationFormState();
}

class _HomeLocationFormState extends ConsumerState<_HomeLocationForm> {
  final _controller = TextEditingController();
  LinkParseResult? _result;
  bool _resolving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final text = _controller.text;
    final parser = ref.read(linkParserProvider);

    // Try locally first; only a short link costs a network round trip.
    final immediate = parser.parse(text);
    if (immediate is! LinkNeedsResolving) {
      setState(() => _result = immediate);
      return;
    }

    setState(() => _resolving = true);
    final resolved = await parser.parseResolving(
      text,
      ref.read(shortLinkResolverProvider),
    );
    if (!mounted) return;
    setState(() {
      _resolving = false;
      _result = resolved;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _controller.text = text;
    await _parse();
  }

  void _save(LinkParsed parsed) {
    final messenger = ScaffoldMessenger.of(context);
    final s = AppStrings.of(context);

    ref.read(controllerProvider.notifier).setStudentHome(
          studentId: widget.student.id,
          location: parsed.point,
          label: parsed.label,
          linkSource: _controller.text.trim(),
        );

    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(s.homeSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final result = _result;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      children: [
        Text(
          s.isArabic
              ? widget.student.fullNameAr
              : widget.student.fullNameEn,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          s.pasteMapLinkTitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Gap.lg),

        Text(
          s.pasteMapLinkExplain,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: c.inkSoft,
              ),
        ),
        const SizedBox(height: Gap.lg),

        TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 2,
          minLines: 1,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.url,
          onSubmitted: (_) => _parse(),
          decoration: InputDecoration(
            hintText: s.pasteMapLinkHint,
            hintTextDirection: TextDirection.ltr,
            prefixIcon: const Icon(Icons.link_rounded),
            suffixIcon: IconButton(
              tooltip: s.pasteMapLinkTitle,
              icon: const Icon(Icons.content_paste_rounded),
              onPressed: _pasteFromClipboard,
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        FilledButton.icon(
          icon: _resolving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search_rounded, size: 18),
          label: Text(_resolving ? s.linkReading : s.linkPreview),
          onPressed: _resolving ? null : _parse,
        ),

        if (result != null) ...[
          const SizedBox(height: Gap.xl),
          switch (result) {
            LinkParsed() => _Preview(
                parsed: result,
                student: widget.student,
                onSave: () => _save(result),
              ),
            LinkUnrecognised() => _Failure(reason: result.reason),
            LinkNeedsResolving() => const SizedBox.shrink(),
          },
        ],
      ],
    );
  }
}

/// Shows what was read, where it sits, and what it implies for the walk.
class _Preview extends ConsumerWidget {
  const _Preview({
    required this.parsed,
    required this.student,
    required this.onSave,
  });

  final LinkParsed parsed;
  final Student student;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final school = ref.watch(controllerProvider).school;

    final nearest = _nearestStop(parsed.point);
    final walk = nearest == null
        ? null
        : parsed.point.distanceTo(nearest.location).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (parsed.outsideExpectedArea) ...[
          _Warning(message: s.linkFarFromSchool),
          const SizedBox(height: Gap.lg),
        ],

        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: SizedBox(
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: c.line)),
              child: SchematicMap(
                // A two-point path from the home to its nearest stop makes the
                // walk legible at a glance, which a bare pin cannot do.
                path: RoutePath([
                  parsed.point,
                  nearest?.location ?? school.location,
                ]),
                stops: [
                  if (nearest != null)
                    TripStop(
                      stopId: nearest.id,
                      sequence: 0,
                      status: TripStopStatus.pending,
                      expectedStudentIds: const [],
                    ),
                ],
                stopsById: {if (nearest != null) nearest.id: nearest},
                school: school.location,
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),

        if (parsed.label != null) ...[
          _Row(label: s.homeLocation, value: parsed.label!),
          const Divider(height: Gap.lg),
        ],
        _Row(
          label: s.coordinates,
          value: '${parsed.point.latitude.toStringAsFixed(5)}, '
              '${parsed.point.longitude.toStringAsFixed(5)}',
          monospace: true,
        ),
        if (nearest != null) ...[
          const Divider(height: Gap.lg),
          _Row(
            label: s.nearestStop,
            value: s.isArabic ? nearest.nameAr : nearest.nameEn,
          ),
          const Divider(height: Gap.lg),
          _Row(
            label: s.walkToStop,
            value: s.metres(walk!),
            monospace: true,
            accent: walk > 600 ? c.manual : c.delivered,
          ),
        ],

        const SizedBox(height: Gap.xl),
        FilledButton.icon(
          icon: const Icon(Icons.check_rounded),
          label: Text(s.save),
          onPressed: onSave,
        ),
        if (nearest != null && student.stopId != nearest.id) ...[
          const SizedBox(height: Gap.sm),
          OutlinedButton.icon(
            icon: const Icon(Icons.alt_route_rounded, size: 18),
            label: Text(
              '${s.assignToStop}: '
              '${s.isArabic ? nearest.nameAr : nearest.nameEn}',
            ),
            onPressed: () async {
              final notifier = ref.read(controllerProvider.notifier);
              notifier.setStudentHome(
                studentId: student.id,
                location: parsed.point,
                label: parsed.label,
              );
              await notifier.assignStudentToStop(
                studentId: student.id,
                stopId: nearest.id,
              );
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }

  BusStop? _nearestStop(LatLngPoint point) {
    BusStop? best;
    var bestDistance = double.infinity;
    for (final stop in SeedData.stops) {
      final distance = point.distanceTo(stop.location);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = stop;
      }
    }
    return best;
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.monospace = false,
    this.accent,
  });

  final String label;
  final String value;
  final bool monospace;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          textDirection: monospace ? TextDirection.ltr : null,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: accent ?? c.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: c.manualSurface,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: c.manual.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: c.manual),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.manual,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.reason});

  final LinkFailure reason;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;

    final message = switch (reason) {
      LinkFailure.empty => s.pasteMapLinkExplain,
      LinkFailure.outOfRange => s.linkOutOfRange,
      LinkFailure.noCoordinates => s.linkNotRecognised,
    };

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: c.criticalSurface,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.link_off_rounded, size: 18, color: c.critical),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.critical,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
