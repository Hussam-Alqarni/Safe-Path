import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';

/// A button that dials a number, and tells the truth when it cannot.
///
/// The number is always drawn next to the label. A dashboard tablet often has
/// no telephony at all, and the person holding it still needs the digits — so
/// the fallback copies them and says so rather than swallowing the tap.
class CallAction extends ConsumerWidget {
  const CallAction({
    required this.label,
    required this.phoneNumber,
    this.emphasis = false,
    super.key,
  });

  final String label;
  final String phoneNumber;

  /// Filled rather than outlined. For the operator during an emergency.
  final bool emphasis;

  Future<void> _dial(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = AppStrings.of(context);

    final placed = await ref.read(dialerProvider).call(phoneNumber);
    if (placed) return;

    // Say so first. The clipboard is a convenience and can fail on its own
    // (a locked-down kiosk, a web build without permission); the message that
    // the call did not go through must not depend on it.
    messenger.showSnackBar(
      SnackBar(content: Text('${s.callFailed} · $phoneNumber')),
    );
    try {
      await Clipboard.setData(ClipboardData(text: phoneNumber));
    } on Object {
      // The number is drawn on the button itself, so it is never lost.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    const icon = Icon(Icons.call_rounded, size: 18);
    // Phone numbers read left-to-right even in an Arabic layout.
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: Gap.sm),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            phoneNumber,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: emphasis ? Colors.white : c.inkSoft,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      label: '$label $phoneNumber',
      child: emphasis
          ? FilledButton.icon(
              icon: icon,
              label: content,
              onPressed: () => _dial(context, ref),
            )
          : OutlinedButton.icon(
              icon: icon,
              label: content,
              onPressed: () => _dial(context, ref),
            ),
    );
  }
}
