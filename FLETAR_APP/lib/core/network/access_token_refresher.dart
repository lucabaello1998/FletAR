import 'dart:convert';

import 'package:dio/dio.dart';

import 'token_storage.dart';

/// Asegura un access token vigente para usos que, a diferencia de una request
/// HTTP normal, no pasan por `AuthInterceptor` y por lo tanto no se benefician
/// de su refresh reactivo ante un 401 - la conexión de SignalR es el caso: el
/// JWT se valida UNA sola vez, en el handshake (ver `UbicacionHubClient`), así
/// que si el access token venció mientras la conexión estaba caída (una
/// pantalla de tracking "En curso" abierta más de los 15 minutos que dura el
/// access token, algo perfectamente normal en un flete real), cada intento de
/// reconexión fallaría con 401 para siempre - nada dispara un refresh porque
/// no hay ninguna request HTTP de por medio que lo gatille.
///
/// Duplica (a propósito, ver nota abajo) la llamada a `/auth/refresh` que ya
/// tiene `AuthInterceptor` en vez de compartir código: unificarlas requeriría
/// que alguno de los dos importe al otro, y `AuthInterceptor` vive en
/// `core/network` mientras que esta lógica es específica de un caso de uso
/// (SignalR) - el costo de la pequeña duplicación es menor que el de romper
/// esa separación por un helper que se usa en un solo lugar hoy.
Future<String?> obtenerAccessTokenVigente(TokenStorage tokenStorage, String baseUrl) async {
  final accessToken = await tokenStorage.leerAccessToken();
  if (accessToken == null) return null;
  if (!_expiraDentroDe(accessToken, const Duration(seconds: 30))) return accessToken;

  final refreshToken = await tokenStorage.leerRefreshToken();
  if (refreshToken == null) return accessToken;

  try {
    final dio = Dio(BaseOptions(baseUrl: baseUrl));
    final response = await dio.post('/auth/refresh', data: {'refreshToken': refreshToken});
    final nuevoAccessToken = response.data['accessToken'] as String;
    await tokenStorage.guardar(
      accessToken: nuevoAccessToken,
      refreshToken: response.data['refreshToken'] as String,
    );
    return nuevoAccessToken;
  } catch (_) {
    // Best-effort: si el refresh falla (refresh token también vencido, sin
    // red, etc.) devolvemos el access token viejo - va a fallar la conexión
    // igual, pero no es peor que no haber intentado nada.
    return accessToken;
  }
}

bool _expiraDentroDe(String jwt, Duration margen) {
  final partes = jwt.split('.');
  if (partes.length != 3) return false;

  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(partes[1])));
    final exp = (jsonDecode(payload) as Map<String, dynamic>)['exp'] as int?;
    if (exp == null) return false;

    final expiracion = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    return DateTime.now().toUtc().add(margen).isAfter(expiracion);
  } catch (_) {
    return false;
  }
}
