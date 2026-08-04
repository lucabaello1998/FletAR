import 'package:dio/dio.dart';

import 'auth_interceptor.dart';
import 'token_storage.dart';

/// Override en tiempo de build: `--dart-define=FLETAR_API_URL=http://10.0.2.2:5080/api`
/// (10.0.2.2 es "localhost del host" desde el emulador de Android; en desktop
/// alcanza con el default).
const _apiUrlPorDefecto = 'http://localhost:5080/api';
const apiBaseUrl = String.fromEnvironment('FLETAR_API_URL', defaultValue: _apiUrlPorDefecto);

Dio crearDioClient(TokenStorage tokenStorage) {
  final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  dio.interceptors.add(AuthInterceptor(tokenStorage, apiBaseUrl));
  return dio;
}
