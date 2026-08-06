import 'package:dio/dio.dart';

import 'token_storage.dart';

/// Adjunta el JWT a cada request y, ante un 401, intenta un refresh una sola
/// vez antes de reintentar. Si el refresh también falla, limpia los tokens y
/// deja que el error siga su curso - la UI redirige a login leyendo el estado
/// de auth (ver `authProvider` en features/auth).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage, this._baseUrl);

  final TokenStorage _tokenStorage;
  final String _baseUrl;
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

    if (!esNoAutorizado || yaReintentado) {
      handler.next(err);
      return;
    }

    final refreshToken = await _tokenStorage.leerRefreshToken();
    if (refreshToken == null) {
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

      final requestOriginal = err.requestOptions
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..extra['reintentadoTrasRefresh'] = true;

      final dioOriginal = Dio(BaseOptions(baseUrl: _baseUrl));
      final reintento = await dioOriginal.fetch(requestOriginal);
      handler.resolve(reintento);
    } on DioException {
      await _tokenStorage.limpiar();
      handler.next(err);
    }
  }

  Future<String> _refrescar(String refreshToken) async {
    try {
      final dioSinInterceptor = Dio(BaseOptions(baseUrl: _baseUrl));
      final response = await dioSinInterceptor.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final accessToken = response.data['accessToken'] as String;
      await _tokenStorage.guardar(
        accessToken: accessToken,
        refreshToken: response.data['refreshToken'] as String,
      );
      return accessToken;
    } finally {
      _refreshEnCurso = null;
    }
  }
}
