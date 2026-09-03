import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';

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

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;

    return Semantics(
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
  }
}

/// Fire-and-forget, without pulling dart:async into every widget file.
void unawaited(Future<void> future) => future.ignore();
