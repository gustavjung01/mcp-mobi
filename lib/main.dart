import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/diagnostics/app_diagnostics.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        AppDiagnostics.recordFlutterError(details);
        FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        AppDiagnostics.recordError(
          error,
          stack,
          context: 'platform',
        );
        return true;
      };

      runApp(const McpFieldApp());
    },
    (error, stack) {
      AppDiagnostics.recordError(
        error,
        stack,
        context: 'zone',
      );
    },
  );
}
