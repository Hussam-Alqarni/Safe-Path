import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/shared/widgets/call_action.dart';

/// The driver's call for help.
///
/// Hold rather than tap, and no confirmation dialog. A tap is too easy to
/// trigger by accident against a seat or a knee in a moving bus, and a dialog
/// asks someone in an emergency to read and aim at a second target. Two
/// seconds of deliberate pressure is the honest middle: unmistakably
/// intentional, and still faster than any other route to the same outcome.
class EmergencyButton extends ConsumerStatefulWidget {
  const EmergencyButton({
    required this.tripId,
    this.compact = false,
    super.key,
  });

  final String tripId;

  /// The driving view has less room; the trip screen has more.
  final bool compact;

  @override
  ConsumerState<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends ConsumerState<EmergencyButton>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 2);

  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: _holdDuration,
  )..addStatusListener(_onHoldStatus);

  bool _sent = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _sent) return;
    _sent = true;

    // A long buzz confirms it fired without the driver looking away from the
    // road, which is the whole point of a physical-feeling control.
    unawaited(HapticFeedback.heavyImpact());

    ref.read(controllerProvider.notifier).raiseEmergency(
          tripId: widget.tripId,
          raisedByUserId: ref.read(controllerProvider).currentUser.id,
        );

    final s = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.emergencyRaised),
        backgroundColor: context.colors.critical,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _startHold() {
    _sent = false;
    _hold.forward(from: 0);
    unawaited(HapticFeedback.selectionClick());
  }

  void _cancelHold() {
    if (_hold.isCompleted) {
      _hold.value = 0;
      return;
    }
    _hold.reverse();
  }

  /// The contractor's number, shown only once help has actually been called.
  ///
  /// Before that it is clutter on a driving screen; after it, it is the one
  /// thing a driver needs and cannot be asked to go looking for. The alert
  /// log is the source, not this widget's own [_sent] flag — a driver who
  /// reopens the screen mid-incident must still find the number.
  Widget? _operatorCall(BuildContext context) {
    final state = ref.watch(controllerProvider);
    final trip = state.tripById(widget.tripId);
    if (trip == null) return null;

    final live = state.alerts.any(
      (a) =>
          a.isOpen &&
          a.kind == SafetyAlertKind.emergency &&
          a.tripId == widget.tripId,
    );
    if (!live) return null;

    final operator_ = SeedData.operatorForBus(trip.busId);
    if (operator_ == null) return null;

    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: SizedBox(
        width: double.infinity,
        child: CallAction(
          label: AppStrings.of(context).callOperator,
          phoneNumber: operator_.contactPhone,
          emphasis: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final call = _operatorCall(context);

    final button = Semantics(
      button: true,
      label: s.emergencyButton,
      hint: s.emergencyHold,
      child: GestureDetector(
        onTapDown: (_) => _startHold(),
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) {
            final progress = _hold.value;
            return Container(
              height: widget.compact ? 52 : 64,
              decoration: BoxDecoration(
                color: c.critical,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The fill is the feedback: the driver watches the button
                  // arm itself rather than guessing whether it registered.
                  FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: progress,
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sos_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: Gap.sm),
                        Text(
                          progress > 0 && progress < 1
                              ? s.emergencyHold
                              : s.emergencyButton,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (call == null) return button;
    return Column(mainAxisSize: MainAxisSize.min, children: [button, call]);
  }
}

/// Fire-and-forget, without pulling dart:async into every widget file.
void unawaited(Future<void> future) => future.ignore();
