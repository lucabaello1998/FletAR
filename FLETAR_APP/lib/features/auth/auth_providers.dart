import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/network/dio_client.dart';
import '../../core/network/token_storage.dart';
import 'data/auth_api.dart';
import 'domain/usuario.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final dioProvider = Provider((ref) => crearDioClient(ref.watch(tokenStorageProvider)));

final authApiProvider = Provider((ref) => AuthApi(ref.watch(dioProvider)));

final authControllerProvider = AsyncNotifierProvider<AuthController, Usuario?>(AuthController.new);

/// Mismo Client ID (tipo "Web application" en Google Cloud Console) para las
/// tres plataformas: es el audience que el backend valida en /auth/google,
/// ver CLAUDE.md sección "Login con Google". Vacío hasta que se configure -
/// con esto vacío, el botón de Google directamente no se muestra.
const googleClientId = String.fromEnvironment('FLETAR_GOOGLE_CLIENT_ID');

class AuthController extends AsyncNotifier<Usuario?> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEventsSub;

  @override
  Future<Usuario?> build() async {
    ref.onDispose(() => _googleEventsSub?.cancel());
    // No se espera este future: si Google Sign-In no está configurado o falla
    // al inicializar, el resto del login (email/password) no tiene que verse
    // afectado.
    unawaited(_inicializarGoogleSignIn());

    // La sesión no persiste entre reinicios todavía: falta un endpoint
    // `/usuarios/me` (Fase 1) contra el cual validar el access token guardado
    // en el arranque frío. Los tokens sí quedan en secure storage, así que
    // agregar esa validación después no requiere tocar `TokenStorage`.
    return null;
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
    if (!GoogleSignIn.instance.supportsAuthenticate()) return;
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
      return sesion.usuario;
    });
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
    await tokenStorage.limpiar();
    state = const AsyncData(null);
  }
}
