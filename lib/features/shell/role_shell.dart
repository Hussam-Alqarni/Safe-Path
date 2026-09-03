import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/features/admin/admin_screens.dart';
import 'package:safe_path/features/admin/dashboard_screen.dart';
import 'package:safe_path/features/developer/developer_screens.dart';
import 'package:safe_path/features/driver/driver_screens.dart';
import 'package:safe_path/features/parent/parent_screens.dart';
import 'package:safe_path/features/shell/role_switcher.dart';
import 'package:safe_path/features/shell/settings_sheet.dart';
import 'package:safe_path/features/staff/staff_screens.dart';
import 'package:safe_path/shared/widgets/common.dart';

/// One destination in a role's navigation bar.
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.badgeCount,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
  final int? badgeCount;
}

/// The app frame.
///
/// Each role gets its own set of destinations rather than one navigation bar
/// with items hidden per role — a driver holding a tablet in a moving bus and
/// an administrator at a desk want genuinely different apps, and pretending
/// otherwise produces something that suits neither.
class RoleShell extends ConsumerStatefulWidget {
  const RoleShell({super.key});

  @override
  ConsumerState<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends ConsumerState<RoleShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(controllerProvider);
    final role = ref.watch(effectiveRoleProvider);
    final s = AppStrings.of(context);
    final c = context.colors;

    final destinations = _destinationsFor(role, s, ref);
    final safeIndex = _index.clamp(0, destinations.length - 1);

    return Directionality(
      textDirection: s.direction,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: Gap.lg,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(destinations[safeIndex].label),
              Text(
                s.isArabic ? state.school.nameAr : state.school.nameEn,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: s.switchRole,
              icon: const Icon(Icons.switch_account_rounded),
              onPressed: () => showRoleSwitcher(context, ref),
            ),
            IconButton(
              tooltip: s.navSettings,
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => showSettingsSheet(context, ref),
            ),
            const SizedBox(width: Gap.xs),
          ],
        ),
        body: Column(
          children: [
            if (state.config.isDemo) const DemoBanner(),
            if (state.isImpersonating) const _ImpersonationBar(),
            Expanded(
              child: Container(
                color: c.canvas,
                child: destinations[safeIndex].builder(context),
              ),
            ),
          ],
        ),
        bottomNavigationBar: destinations.length < 2
            ? null
            : NavigationBar(
                selectedIndex: safeIndex,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (final destination in destinations)
                    NavigationDestination(
                      icon: _BadgedIcon(
                        icon: destination.icon,
                        count: destination.badgeCount,
                      ),
                      selectedIcon: _BadgedIcon(
                        icon: destination.selectedIcon,
                        count: destination.badgeCount,
                        selected: true,
                      ),
                      label: destination.label,
                    ),
                ],
              ),
      ),
    );
  }

  List<ShellDestination> _destinationsFor(
    UserRole role,
    AppStrings s,
    WidgetRef ref,
  ) {
    final unread = ref.watch(unreadCountProvider);
    final openAlerts = ref.watch(openAlertsProvider).length;

    return switch (role) {
      UserRole.guardian => [
          ShellDestination(
            label: s.navChildren,
            icon: Icons.family_restroom_outlined,
            selectedIcon: Icons.family_restroom_rounded,
            builder: (_) => const GuardianChildrenScreen(),
          ),
          ShellDestination(
            label: s.navLive,
            icon: Icons.map_outlined,
            selectedIcon: Icons.map_rounded,
            builder: (_) => const GuardianLiveScreen(),
          ),
          ShellDestination(
            label: s.navNotifications,
            icon: Icons.notifications_outlined,
            selectedIcon: Icons.notifications_rounded,
            badgeCount: unread,
            builder: (_) => const GuardianNotificationsScreen(),
          ),
        ],
      UserRole.driver => [
          ShellDestination(
            label: s.navLive,
            icon: Icons.directions_bus_outlined,
            selectedIcon: Icons.directions_bus_rounded,
            builder: (_) => const DriverTripScreen(),
          ),
          ShellDestination(
            label: s.navRoster,
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups_rounded,
            builder: (_) => const DriverManifestScreen(),
          ),
        ],
      UserRole.schoolAdmin => [
          ShellDestination(
            label: s.adminOverview,
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            builder: (_) => const AdminDashboardScreen(),
          ),
          ShellDestination(
            label: s.navFleet,
            icon: Icons.map_outlined,
            selectedIcon: Icons.map_rounded,
            builder: (_) => const AdminFleetScreen(),
          ),
          ShellDestination(
            label: s.navRoster,
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups_rounded,
            builder: (_) => const AdminRosterScreen(),
          ),
          ShellDestination(
            label: s.navAlerts,
            icon: Icons.warning_amber_outlined,
            selectedIcon: Icons.warning_rounded,
            badgeCount: openAlerts,
            builder: (_) => const AdminAlertsScreen(),
          ),
        ],
      UserRole.schoolStaff => [
          ShellDestination(
            label: s.navGate,
            icon: Icons.sensor_door_outlined,
            selectedIcon: Icons.sensor_door_rounded,
            builder: (_) => const StaffGateScreen(),
          ),
          ShellDestination(
            label: s.navRoster,
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups_rounded,
            builder: (_) => const StaffRosterScreen(),
          ),
          ShellDestination(
            label: s.navAlerts,
            icon: Icons.warning_amber_outlined,
            selectedIcon: Icons.warning_rounded,
            badgeCount: openAlerts,
            builder: (_) => const AdminAlertsScreen(),
          ),
        ],
      UserRole.developer => [
          ShellDestination(
            label: s.devSimulationControls,
            icon: Icons.tune_outlined,
            selectedIcon: Icons.tune_rounded,
            builder: (_) => const DeveloperControlsScreen(),
          ),
          ShellDestination(
            label: s.devEventLog,
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            builder: (_) => const DeveloperEventLogScreen(),
          ),
          ShellDestination(
            label: s.devAuditLog,
            icon: Icons.policy_outlined,
            selectedIcon: Icons.policy_rounded,
            builder: (_) => const DeveloperAuditScreen(),
          ),
        ],
    };
  }
}

/// The bar shown while a developer is viewing someone else's screens. Loud on
/// purpose: privileged access should never feel like ordinary use.
class _ImpersonationBar extends ConsumerWidget {
  const _ImpersonationBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final session = ref.watch(controllerProvider).impersonation;
    if (session == null) return const SizedBox.shrink();

    return Material(
      color: c.criticalSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.visibility_rounded, size: 15, color: c.critical),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                '${s.devImpersonating}: ${s.roleName(session.role)}',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: c.critical),
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(controllerProvider.notifier).endImpersonation(),
              style: TextButton.styleFrom(
                foregroundColor: c.critical,
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(s.devStopImpersonating),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.icon,
    this.count,
    this.selected = false,
  });

  final IconData icon;
  final int? count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = count ?? 0;
    final child = Icon(icon, color: selected ? c.brand : c.inkSoft);
    if (value == 0) return child;

    return Badge.count(
      count: value,
      backgroundColor: c.critical,
      textColor: Colors.white,
      child: child,
    );
  }
}
