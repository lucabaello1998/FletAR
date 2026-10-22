import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'auth_interceptor.dart';
import 'token_storage.dart';

/// Override en tiempo de build: `--dart-define=FLETAR_API_URL=http://10.0.2.2:5080/api`
/// (10.0.2.2 es "localhost del host" desde el emulador de Android; en desktop
/// alcanza con el default).
const _apiUrlPorDefecto = 'http://localhost:5080/api';
const apiBaseUrl = String.fromEnvironment('FLETAR_API_URL', defaultValue: _apiUrlPorDefecto);

Dio crearDioClient(TokenStorage tokenStorage, {VoidCallback? onSesionExpirada}) {
  final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  dio.interceptors.add(
    AuthInterceptor(tokenStorage, apiBaseUrl, onSesionExpirada: onSesionExpirada),
  );
  return dio;
}

/// Convierte la URL relativa que devuelve el backend para una imagen subida
/// (fotos de carga, foto de vehículo - Fase 8) en una URL absoluta.
///
/// Esas imágenes se sirven vía `UseStaticFiles` en la raíz del host de la API
/// (`/uploads/...`), fuera de `/api` (ver `AlmacenamientoArchivosService` y
/// `Program.cs` en FLETAR_BACKEND) - `apiBaseUrl` siempre termina en `/api`,
/// así que alcanza con sacarlo. Mismo criterio que `_ubicacionHubUrl` en
/// ubicacion_providers.dart para el hub de SignalR, que también vive fuera
/// de `/api`.
String resolverUrlMedia(String urlRelativa) {
  if (urlRelativa.startsWith('http://') || urlRelativa.startsWith('https://')) return urlRelativa;
  final host = apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  return '$host$urlRelativa';
}
