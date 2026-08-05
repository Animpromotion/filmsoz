import 'dart:async';
import 'dart:ui';

import 'package:filmsoz_studio/app/app.dart';
import 'package:filmsoz_studio/core/release/app_settings_service.dart';
import 'package:filmsoz_studio/core/release/error_log_service.dart';
import 'package:filmsoz_studio/core/release/session_recovery_service.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const settingsService = FilmsozAppSettingsService();
  const logService = FilmsozErrorLogService();
  const sessionService = FilmsozSessionRecoveryService();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      logService.record(
        'flutter',
        details.exception,
        details.stack,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(logService.record('platform', error, stackTrace));
    return true;
  };

  try {
    final settings = await settingsService.load();
    await logService.prune(maxFiles: settings.maxErrorLogFiles);
    await sessionService.beginSession();
  } catch (error, stackTrace) {
    await logService.record('startup', error, stackTrace);
  }

  runApp(const FilmnomaApp());
}
