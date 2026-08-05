import 'package:flutter/material.dart';

/// Vive en su propio archivo (en vez de app.dart) para que AuthController pueda
/// mostrar un SnackBar ante una notificación push en foreground sin crear un
/// import circular con app.dart (que ya importa auth_providers.dart vía el router).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
