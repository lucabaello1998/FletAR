import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fletar_app/core/network/auth_interceptor.dart';
import 'package:fletar_app/core/network/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reemplaza flutter_secure_storage (necesita un canal de plataforma que no
/// existe en un test de VM) sobreescribiendo cada método público - el campo
/// `_storage` de la clase base nunca se usa.
class _TokenStorageFalso extends TokenStorage {
  String? access = 'access-vencido';
  String? refresh = 'refresh-valido';

  @override
  Future<String?> leerAccessToken() async => access;

  @override
  Future<String?> leerRefreshToken() async => refresh;

  @override
  Future<void> guardar({required String accessToken, required String refreshToken}) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> limpiar() async {
    access = null;
    refresh = null;
  }
}

void main() {
  test(
    'reintenta una subida multipart (foto) tras un 401 sin tirar StateError por FormData ya finalizada',
    () async {
      var intentosSubida = 0;
      List<int>? bytesRecibidosEnElReintento;

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/auth/refresh') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'accessToken': 'access-nuevo',
            'refreshToken': 'refresh-nuevo',
          }));
          await request.response.close();
          return;
        }

        if (request.uri.path == '/publicaciones/1/fotos') {
          intentosSubida++;
          final bytes = await request.fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));

          // Primer intento: token "vencido" -> 401, dispara el refresh+reintento
          // de AuthInterceptor. Sin el fix, ese reintento reusa la misma
          // instancia de FormData (ya finalizada al mandar este primer
          // intento) y Dio tira StateError antes de que este segundo request
          // llegue siquiera a este servidor.
          if (intentosSubida == 1) {
            request.response.statusCode = 401;
            await request.response.close();
            return;
          }

          bytesRecibidosEnElReintento = bytes;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'ok': true}));
          await request.response.close();
          return;
        }

        request.response.statusCode = 404;
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.address}:${server.port}';
      final tokenStorage = _TokenStorageFalso();
      final dio = Dio(BaseOptions(baseUrl: baseUrl))
        ..interceptors.add(AuthInterceptor(tokenStorage, baseUrl));

      final bytesOriginales = List<int>.generate(200, (i) => i % 256);
      final formData = FormData.fromMap({
        'archivo': MultipartFile.fromBytes(bytesOriginales, filename: 'foto.jpg'),
      });

      final response = await dio.post('/publicaciones/1/fotos', data: formData);

      expect(response.statusCode, 200);
      expect(intentosSubida, 2, reason: 'debe reintentar exactamente una vez tras el 401');
      expect(bytesRecibidosEnElReintento, isNotNull);
      // El reintento tiene que haber llegado con un body multipart real y no
      // vacío - confirma que FormData.clone() preservó el archivo, no sólo
      // que el request no explotó.
      expect(bytesRecibidosEnElReintento!.length, greaterThan(bytesOriginales.length));
      expect(tokenStorage.access, 'access-nuevo', reason: 'el token nuevo debe haberse persistido');

      await server.close(force: true);
    },
  );
}
