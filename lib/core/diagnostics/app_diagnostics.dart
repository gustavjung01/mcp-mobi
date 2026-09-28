import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

abstract final class AppDiagnostics {
  static void recordFlutterError(FlutterErrorDetails details) {
    recordError(
      details.exception,
      details.stack ?? StackTrace.current,
      context: details.context?.toDescription() ?? 'flutter',
    );
  }

  static void recordError(
    Object error,
    StackTrace stack, {
    required String context,
  }) {
    developer.log(
      'Unhandled application error',
      name: 'mcp_field.$context',
      error: error,
      stackTrace: stack,
      level: 1000,
    );
  }
}
