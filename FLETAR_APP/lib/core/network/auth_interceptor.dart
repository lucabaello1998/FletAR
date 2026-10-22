import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'token_storage.dart';

/// Adjunta el JWT a cada request y, ante un 401, intenta un refresh una sola
/// vez antes de reintentar. Si el refresh también falla, limpia los tokens y
/// deja que el error siga su curso - la UI redirige a login leyendo el estado
/// de auth (ver `authProvider` en features/auth).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage, this._baseUrl, {this.onSesionExpirada});

  final TokenStorage _tokenStorage;
  final String _baseUrl;

  /// Se llama sólo si la request salió con un access token y la sesión no se
  /// pudo recuperar (refresh vencido/revocado o reintento fallido). Un login
  /// con contraseña incorrecta no la dispara: esa request no lleva token.
  final VoidCallback? onSesionExpirada;

  Future<String>? _refreshEnCurso;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final accessToken = await _tokenStorage.leerAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final esNoAutorizado = err.response?.statusCode == 401;
    final yaReintentado = err.requestOptions.extra['reintentadoTrasRefresh'] == true;
    final teniaToken = err.requestOptions.headers['Authorization'] != null;

    if (!esNoAutorizado || yaReintentado) {
      handler.next(err);
      return;
    }

    // Un 401 "tardío": la request salió con el access token viejo, pero otra
    // request ya refrescó mientras la respuesta estaba en vuelo. No hay que
    // refrescar de nuevo (el backend revoca la familia al ver el refresh
    // repetido): alcanza con reintentar con el token que ya está guardado.
    final tokenDelRequest = err.requestOptions.headers['Authorization'] as String?;
    final tokenActual = await _tokenStorage.leerAccessToken();
    if (tokenActual != null &&
        tokenDelRequest != null &&
        tokenDelRequest != 'Bearer $tokenActual') {
      await _reintentar(err, tokenActual, handler);
      return;
    }

    final refreshToken = await _tokenStorage.leerRefreshToken();
    if (refreshToken == null) {
      if (teniaToken) await _cerrarSesion();
      handler.next(err);
      return;
    }

    try {
      // Single-flight: si varias requests reciben 401 casi al mismo tiempo
      // (típico al abrir el listado, que dispara varios providers juntos),
      // todas esperan el MISMO refresh en vez de disparar cada una el suyo - el
      // backend revoca toda la familia ante el reuso de un refresh token ya
      // usado, así que refrescar dos veces con el mismo token desloguearía al
      // usuario sin que haya hecho nada malo. El chequeo+asignación es
      // sincrónico (sin await entre medio), así que dos onError casi
      // simultáneos no alcanzan a crear cada uno su propio Future: Dart corre
      // cada continuación hasta el próximo await sin interrupción.
      final accessToken = await (_refreshEnCurso ??= _refrescar(refreshToken));
      await _reintentar(err, accessToken, handler);
    } catch (_) {
      // Cualquier falla del refresh (token vencido, revocado, sin red, body
      // raro) deja la sesión inservible: se limpia y se avisa a la UI.
      await _cerrarSesion();
      handler.next(err);
    }
  }

  Future<void> _reintentar(
    DioException err,
    String accessToken,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      // FormData sólo se puede serializar una vez (Dio la marca "finalizada"
      // la primera vez que se manda) - reusar la misma instancia en un
      // reintento de una subida de foto tira un StateError, no un
      // DioException, así que ni siquiera lo agarraba el catch de abajo.
      // FormData.clone() existe en Dio puntualmente para este caso.
      final datosOriginales = err.requestOptions.data;
      final requestOriginal = err.requestOptions
        ..data = datosOriginales is FormData ? datosOriginales.clone() : datosOriginales
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..extra['reintentadoTrasRefresh'] = true;

      final dioOriginal = Dio(BaseOptions(baseUrl: _baseUrl));
      final reintento = await dioOriginal.fetch(requestOriginal);
      handler.resolve(reintento);
    } on DioException catch (errorDelReintento) {
      // Sólo se cierra la sesión si el reintento volvió a dar 401. Un 502, un
      // timeout o una subida que se cortó son transitorios: desloguear ahí
      // obligaba a volver a entrar por un blip de red en medio de una foto.
      if (errorDelReintento.response?.statusCode == 401) {
        await _cerrarSesion();
      }
      handler.next(err);
    } catch (_) {
      // Cualquier otra cosa (un body inesperado al parsear, etc.) no puede
      // dejar el handler sin resolver: la request quedaría colgada para
      // siempre y la UI girando.
      handler.next(err);
    }
  }

  Future<void> _cerrarSesion() async {
    await _tokenStorage.limpiar();
    onSesionExpirada?.call();
  }

  Future<String> _refrescar(String refreshToken) async {
    try {
      final dioSinInterceptor = Dio(BaseOptions(baseUrl: _baseUrl));
      final response = await dioSinInterceptor.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final cuerpo = response.data;
      final accessToken = cuerpo is Map ? cuerpo['accessToken'] : null;
      final refreshNuevo = cuerpo is Map ? cuerpo['refreshToken'] : null;
      if (accessToken is! String || refreshNuevo is! String) {
        // Un 200 con un cuerpo inesperado no es un DioException para Dio: si se
        // dejaba pasar, el cast explotaba con TypeError, el `onError` no lo
        // agarraba y la request quedaba colgada.
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }

      await _tokenStorage.guardar(accessToken: accessToken, refreshToken: refreshNuevo);
      return accessToken;
    } finally {
      _refreshEnCurso = null;
    }
  }
}
