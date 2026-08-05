import 'package:dio/dio.dart';

import '../domain/usuario_publico.dart';

class UsuariosApi {
  UsuariosApi(this._dio);

  final Dio _dio;

  Future<UsuarioPublico> obtenerPorId(int id) async {
    final response = await _dio.get('/usuarios/$id');
    return UsuarioPublico.fromJson(response.data as Map<String, dynamic>);
  }
}
