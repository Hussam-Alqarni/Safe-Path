import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/features/shell/role_shell.dart';

class SafePathApp extends ConsumerStatefulWidget {
  const SafePathApp({super.key});

  @override
  ConsumerState<SafePathApp> createState() => _SafePathAppState();
}

class _SafePathAppState extends ConsumerState<SafePathApp> {
  @override
  void initState() {
    super.initState();
    // Build today's trips once the first frame is scheduled, so the very first
    // paint already has a populated world rather than an empty shell.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(controllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(controllerProvider);

    return MaterialApp(
      title: 'Safe Path',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: state.themeMode,
      locale: state.locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStringsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Text scaling is clamped rather than ignored: a guardian who has set
        // large text must still get it, but a 2x scale must not push a safety
        // alert off screen.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.35,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const RoleShell(),
    );
  }
}
