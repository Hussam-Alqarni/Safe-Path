import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/app.dart';
import 'package:safe_path/core/config/app_config.dart';
import 'package:safe_path/data/repositories/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // The demo profile needs no API key, no backend and no hardware, so a fresh
  // `flutter run` shows a working system rather than a setup screen.
  final config = const bool.fromEnvironment('SAFE_PATH_LIVE')
      ? AppConfig.production()
      : AppConfig.demo();

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const SafePathApp(),
    ),
  );
}
