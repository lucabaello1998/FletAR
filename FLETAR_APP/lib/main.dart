import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';

/// Monitoreo de errores (Sentry). Sin DSN la app arranca igual y no manda
/// nada; el DSN se inyecta en el build con `--dart-define=SENTRY_DSN=...`.
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  if (_sentryDsn.isEmpty) {
    runApp(const ProviderScope(child: FletarApp()));
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = const String.fromEnvironment(
        'FLETAR_ENV',
        defaultValue: 'production',
      );
      options.tracesSampleRate = 0.1;
      options.sendDefaultPii = false;
    },
    appRunner: () => runApp(const ProviderScope(child: FletarApp())),
  );
}
