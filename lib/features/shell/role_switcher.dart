import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';

/// Signs in as any of the five roles.
///
/// A demo lives or dies on this: an administrator wants to see what a parent
/// sees, and switching should take one tap, not a sign-out and a new password.
Future<void> showRoleSwitcher(BuildContext context, WidgetRef ref) {
  final s = AppStrings.of(context);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Directionality(
      textDirection: s.direction,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.switchRole,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: Gap.lg),
              for (final user in _demoAccounts) _RoleTile(user: user, ref: ref),
            ],
          ),
        ),
      ),
    ),
  );
}

final _demoAccounts = <AppUser>[
  SeedData.demoGuardian,
  SeedData.drivers.first,
  SeedData.schoolAdmin,
  SeedData.schoolStaff,
  SeedData.developer,
];

class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.user, required this.ref});

  final AppUser user;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final isCurrent = ref.read(controllerProvider).currentUser.id == user.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Material(
        color: isCurrent ? c.brandSurface : c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () {
            ref.read(controllerProvider.notifier).signInAs(user);
            Navigator.of(context).pop();
          },
          child: Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              border: Border.all(
                color: isCurrent ? c.brand : c.line,
              ),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                Icon(_iconFor(user.role), size: 20, color: c.brand),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.roleName(user.role),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        s.isArabic ? user.fullNameAr : user.fullNameEn,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Icon(Icons.check_circle_rounded, size: 18, color: c.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(UserRole role) => switch (role) {
        UserRole.guardian => Icons.family_restroom_rounded,
        UserRole.driver => Icons.directions_bus_rounded,
        UserRole.schoolAdmin => Icons.admin_panel_settings_rounded,
        UserRole.schoolStaff => Icons.badge_rounded,
        UserRole.developer => Icons.terminal_rounded,
      };
}
