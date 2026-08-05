import 'package:dio/dio.dart';

import '../domain/usuario_publico.dart';

class UsuariosApi {
  UsuariosApi(this._dio);

  final Dio _dio;

  Future<UsuarioPublico> obtenerPorId(int id) async {
    final response = await _dio.get('/usuarios/$id');
    return UsuarioPublico.fromJson(response.data as Map<String, dynamic>);
  }

  /// Alcance mobile únicamente (ver CLAUDE.md, Stack) - `token: null` desregistra
  /// el dispositivo al desloguearse.
  Future<void> registrarFcmToken(String? token) =>
      _dio.put('/usuarios/me/fcm-token', data: {'token': token});
}
