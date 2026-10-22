import 'package:flutter/foundation.dart';

/// Avisa que la sesión dejó de ser válida: refresh token vencido o revocado, o
/// un 401 que no se pudo recuperar. Lo dispara `AuthInterceptor` (que no conoce
/// Riverpod) y lo escucha `AuthController` para volver a la pantalla de login.
///
/// Sin esto, cuando vencía el access token y el refresh fallaba, la app seguía
/// mostrando al usuario como logueado y cada acción terminaba en un cartel de
/// error genérico, sin forma de recuperarse salvo cerrar sesión a mano.
class SesionExpiradaNotifier extends ChangeNotifier {
  void notificar() => notifyListeners();
}
