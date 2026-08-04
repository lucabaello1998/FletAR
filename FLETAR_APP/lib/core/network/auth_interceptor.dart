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
      final dioSinInterceptor = Dio(BaseOptions(baseUrl: _baseUrl));
      final response = await dioSinInterceptor.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      await _tokenStorage.guardar(
        accessToken: response.data['accessToken'] as String,
        refreshToken: response.data['refreshToken'] as String,
      );

      final requestOriginal = err.requestOptions
        ..headers['Authorization'] = 'Bearer ${response.data['accessToken']}'
        ..extra['reintentadoTrasRefresh'] = true;

      final dioOriginal = Dio(BaseOptions(baseUrl: _baseUrl));
      final reintento = await dioOriginal.fetch(requestOriginal);
      handler.resolve(reintento);
    } on DioException {
      await _tokenStorage.limpiar();
      handler.next(err);
    }
  }
}
