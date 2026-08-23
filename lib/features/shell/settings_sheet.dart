import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';

/// Language and theme. Both take effect immediately — a parent switching to
/// English mid-journey must not lose the screen they were reading.
Future<void> showSettingsSheet(BuildContext context, WidgetRef ref) {
  final s = AppStrings.of(context);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => Consumer(
      builder: (innerContext, innerRef, _) {
        final state = innerRef.watch(controllerProvider);
        final controller = innerRef.read(controllerProvider.notifier);

        return Directionality(
          textDirection: s.direction,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.navSettings,
                    style: Theme.of(innerContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: Gap.lg),
                  Text(
                    s.language,
                    style: Theme.of(innerContext).textTheme.titleSmall,
                  ),
                  const SizedBox(height: Gap.sm),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ar', label: Text('العربية')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {state.locale.languageCode},
                    onSelectionChanged: (selection) =>
                        controller.setLocale(Locale(selection.first)),
                  ),
                  const SizedBox(height: Gap.xl),
                  Text(
                    s.theme,
                    style: Theme.of(innerContext).textTheme.titleSmall,
                  ),
                  const SizedBox(height: Gap.sm),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode_rounded, size: 17),
                        label: Text(s.isArabic ? 'فاتح' : 'Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon:
                            const Icon(Icons.brightness_auto_rounded, size: 17),
                        label: Text(s.isArabic ? 'تلقائي' : 'Auto'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode_rounded, size: 17),
                        label: Text(s.isArabic ? 'داكن' : 'Dark'),
                      ),
                    ],
                    selected: {state.themeMode},
                    onSelectionChanged: (selection) =>
                        controller.setThemeMode(selection.first),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
