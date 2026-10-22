import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/network/dio_client.dart';
import '../../core/network/sesion_expirada.dart';
import '../../core/network/token_storage.dart';
import '../../core/notificaciones/fcm_service.dart';
import '../../core/scaffold_messenger_key.dart';
import '../usuarios/data/usuarios_api.dart';
import 'data/auth_api.dart';
import 'domain/usuario.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Puente entre el interceptor HTTP (sin Riverpod) y la UI: cuando el refresh
/// token vence o se revoca, la app vuelve a login en vez de quedar "logueada"
/// con cada acción fallando.
final sesionExpiradaProvider =
    ChangeNotifierProvider<SesionExpiradaNotifier>((ref) => SesionExpiradaNotifier());

final dioProvider = Provider((ref) {
  return crearDioClient(
    ref.watch(tokenStorageProvider),
    onSesionExpirada: () => ref.read(sesionExpiradaProvider).notificar(),
  );
});

final authApiProvider = Provider((ref) => AuthApi(ref.watch(dioProvider)));

final authControllerProvider = AsyncNotifierProvider<AuthController, Usuario?>(AuthController.new);

/// Mismo Client ID (tipo "Web application" en Google Cloud Console) para las
/// tres plataformas: es el audience que el backend valida en /auth/google,
/// ver CLAUDE.md sección "Login con Google". Vacío hasta que se configure -
/// con esto vacío, el botón de Google directamente no se muestra.
const googleClientId = String.fromEnvironment('FLETAR_GOOGLE_CLIENT_ID');

class AuthController extends AsyncNotifier<Usuario?> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEventsSub;
  StreamSubscription<String>? _fcmTokenRefreshSub;
  StreamSubscription<RemoteMessage>? _fcmMessageSub;
  final _fcmService = FcmService();

  @override
  Future<Usuario?> build() async {
    ref.onDispose(() {
      _googleEventsSub?.cancel();
      _fcmTokenRefreshSub?.cancel();
      _fcmMessageSub?.cancel();
    });

    // Sesión vencida (refresh fallido): volver a login en vez de dejar la app
    // en un estado donde todo falla.
    final sesionExpirada = ref.watch(sesionExpiradaProvider);
    void alExpirarSesion() {
      if (state.valueOrNull == null) return;
      state = const AsyncData(null);
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Tu sesión expiró. Volvé a iniciar sesión.')),
      );
    }

    sesionExpirada.addListener(alExpirarSesion);
    ref.onDispose(() => sesionExpirada.removeListener(alExpirarSesion));

    // No se espera este future: si Google Sign-In no está configurado o falla
    // al inicializar, el resto del login (email/password) no tiene que verse
    // afectado.
    unawaited(_inicializarGoogleSignIn());
    unawaited(_inicializarFcm());

    // La sesión no persiste entre reinicios todavía: falta un endpoint
    // `/usuarios/me` (Fase 1) contra el cual validar el access token guardado
    // en el arranque frío. Los tokens sí quedan en secure storage, así que
    // agregar esa validación después no requiere tocar `TokenStorage`.
    return null;
  }

  /// Alcance mobile únicamente (ver CLAUDE.md, Stack) - no hace nada en
  /// desktop/web (`soportaPush` da false ahí).
  Future<void> _inicializarFcm() async {
    try {
      await _fcmService.inicializar();
      _fcmTokenRefreshSub = _fcmService.onTokenRefresh.listen((token) {
        UsuariosApi(ref.read(dioProvider)).registrarFcmToken(token).catchError((_) {});
      });
      // Foreground: FCM no muestra la notificación sola (a diferencia de
      // background/terminated, que lo hace el sistema operativo) - sin esto
      // una notificación que llega con la app abierta no se ve en ningún lado.
      _fcmMessageSub = FirebaseMessaging.onMessage.listen((mensaje) {
        final notificacion = mensaje.notification;
        if (notificacion == null) return;
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('${notificacion.title}: ${notificacion.body}')),
        );
      });
    } catch (_) {
      // Firebase mal configurado en este dispositivo - el resto de la app sigue.
    }
  }

  Future<void> _registrarFcmTokenSiCorresponde() async {
    try {
      final token = await _fcmService.pedirPermisoYObtenerToken();
      if (token != null) await UsuariosApi(ref.read(dioProvider)).registrarFcmToken(token);
    } catch (_) {
      // Push es un plus, no un requisito - mismo criterio que Google Sign-In.
    }
  }

  Future<void> _inicializarGoogleSignIn() async {
    if (googleClientId.isEmpty) return;
    try {
      await GoogleSignIn.instance.initialize(clientId: googleClientId, serverClientId: googleClientId);
      _googleEventsSub = GoogleSignIn.instance.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          final idToken = event.user.authentication.idToken;
          if (idToken != null) unawaited(_loginConGoogleIdToken(idToken));
        }
      });
    } catch (_) {
      // Google mal configurado (client id inválido, sin red, etc.) - el
      // botón de Google queda inutilizable pero el resto de la app sigue.
    }
  }

  /// En mobile (Android/iOS) dispara el picker nativo de cuentas de Google.
  /// En web el flujo lo maneja el botón que renderiza el propio SDK de
  /// Google (ver `web_only.renderButton` en login_screen.dart) - este método
  /// no hace nada ahí, `supportsAuthenticate()` da false.
  Future<void> iniciarConGoogle() async {
    try {
      if (!GoogleSignIn.instance.supportsAuthenticate()) return;
    } on UnimplementedError {
      return;
    }
    try {
      await GoogleSignIn.instance.authenticate();
      // El idToken llega por authenticationEvents y dispara _loginConGoogleIdToken.
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _loginConGoogleIdToken(String idToken) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final sesion = await ref.read(authApiProvider).loginConGoogle(idToken);
      await ref.read(tokenStorageProvider).guardar(
            accessToken: sesion.accessToken,
            refreshToken: sesion.refreshToken,
          );
      await _registrarFcmTokenSiCorresponde();
      return sesion.usuario;
    });
  }

  Future<void> registrar({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final sesion = await ref.read(authApiProvider).registrar(
            nombre: nombre,
            email: email,
            password: password,
            telefono: telefono,
          );
      await ref.read(tokenStorageProvider).guardar(
            accessToken: sesion.accessToken,
            refreshToken: sesion.refreshToken,
          );
      await _registrarFcmTokenSiCorresponde();
      return sesion.usuario;
    });
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final sesion = await ref.read(authApiProvider).login(email: email, password: password);
      await ref.read(tokenStorageProvider).guardar(
            accessToken: sesion.accessToken,
            refreshToken: sesion.refreshToken,
          );
      await _registrarFcmTokenSiCorresponde();
      return sesion.usuario;
    });
  }

  /// Actualiza en memoria la `fotoUrl` del usuario logueado (Fase 8, tras
  /// subir/reemplazar su foto de vehículo) sin necesitar un endpoint
  /// `/usuarios/me` que devuelva el usuario completo (ver CLAUDE.md, gap
  /// conocido: la sesión no persiste tras un reload en frío tampoco por esto
  /// mismo). No hace nada si por algún motivo no hay sesión activa.
  void actualizarFotoUrl(String? nuevaFotoUrl) {
    final actual = state.valueOrNull;
    if (actual == null) return;
    state = AsyncData(Usuario(
      id: actual.id,
      nombre: actual.nombre,
      email: actual.email,
      rol: actual.rol,
      telefono: actual.telefono,
      fotoUrl: nuevaFotoUrl,
    ));
  }

  Future<void> logout() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    final refreshToken = await tokenStorage.leerRefreshToken();
    if (refreshToken != null) {
      try {
        await ref.read(authApiProvider).logout(refreshToken);
      } catch (_) {
        // El logout del lado del servidor es best-effort: el usuario tiene
        // que quedar deslogueado localmente aunque el server no responda.
      }
    }
    if (soportaPush) {
      // Antes de limpiar los tokens: la llamada necesita el access token
      // vigente para autenticarse. Best-effort - un dispositivo que no se
      // pudo desregistrar simplemente sigue recibiendo pushes hasta que el
      // token expire o se pise con el de otra cuenta.
      try {
        await UsuariosApi(ref.read(dioProvider)).registrarFcmToken(null);
      } catch (_) {}
    }
    await tokenStorage.limpiar();
    state = const AsyncData(null);
  }
}
