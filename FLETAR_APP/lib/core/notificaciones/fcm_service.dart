import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Alcance mobile únicamente (ver CLAUDE.md, Stack): FCM no soporta Windows/Linux
/// desktop, y todavía no se armó la configuración de Firebase para web. Se usa
/// `defaultTargetPlatform` en vez de `dart:io Platform` para no arriesgar el build
/// de web (`Platform` requiere manejo especial ahí).
bool get soportaPush =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

class FcmService {
  Future<void> inicializar() async {
    if (!soportaPush) return;
    await Firebase.initializeApp();
  }

  /// null si el usuario no dio permiso, o si la plataforma no soporta push.
  Future<String?> pedirPermisoYObtenerToken() async {
    if (!soportaPush) return null;

    final permiso = await FirebaseMessaging.instance.requestPermission();
    if (permiso.authorizationStatus == AuthorizationStatus.denied) return null;

    return FirebaseMessaging.instance.getToken();
  }

  /// FCM rota el token de tanto en tanto - sin escuchar esto, un usuario deja
  /// de recibir notificaciones en silencio después de la rotación.
  Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;
}
