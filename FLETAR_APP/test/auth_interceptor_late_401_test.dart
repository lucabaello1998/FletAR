import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fletar_app/core/network/auth_interceptor.dart';
import 'package:fletar_app/core/network/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

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
    'un 401 tardío reintenta con el token ya refrescado y no pide otro refresh',
    () async {
      var refreshCalls = 0;
      var fastAttempts = 0;
      var lateAttempts = 0;

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final authorization = request.headers.value('authorization');

        if (request.uri.path == '/auth/refresh') {
          refreshCalls++;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'accessToken': 'access-nuevo',
            'refreshToken': 'refresh-nuevo',
          }));
          await request.response.close();
          return;
        }

        if (request.uri.path == '/fast') {
          fastAttempts++;
          if (authorization == 'Bearer access-nuevo') {
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'ok': true}));
          } else {
            request.response.statusCode = 401;
          }
          await request.response.close();
          return;
        }

        if (request.uri.path == '/late') {
          lateAttempts++;
          if (lateAttempts == 1) {
            // Deja que /fast termine su refresh antes de responder este 401:
            // así el 401 llega cuando el token guardado ya cambió.
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }

          if (authorization == 'Bearer access-nuevo') {
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'ok': true}));
          } else {
            request.response.statusCode = 401;
          }
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

      final responses = await Future.wait([
        dio.get<dynamic>('/fast'),
        dio.get<dynamic>('/late'),
      ]);

      expect(responses.every((response) => response.statusCode == 200), isTrue);
      expect(refreshCalls, 1, reason: 'el 401 tardío no debe disparar un segundo refresh');
      expect(fastAttempts, 2, reason: 'la request que recibe el primer 401 sí refresca y reintenta');
      expect(lateAttempts, 2, reason: 'la request tardía reintenta con el token nuevo');
      expect(tokenStorage.access, 'access-nuevo');

      await server.close(force: true);
    },
  );
}
