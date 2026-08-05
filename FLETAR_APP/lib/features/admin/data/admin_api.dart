import 'package:dio/dio.dart';

import '../../reportes/domain/reporte.dart';
import '../domain/metricas.dart';
import '../domain/usuario_admin.dart';

class AdminApi {
  AdminApi(this._dio);

  final Dio _dio;

  Future<List<Reporte>> listarReportes({String? estado}) async {
    final response = await _dio.get('/admin/reportes', queryParameters: {'estado': ?estado});
    return (response.data as List).map((e) => Reporte.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> revisarReporte(int id) async {
    await _dio.post('/admin/reportes/$id/revisar');
  }

  Future<void> descartarReporte(int id) async {
    await _dio.post('/admin/reportes/$id/descartar');
  }

  Future<void> cancelarPublicacion(int id) async {
    await _dio.post('/admin/publicaciones/$id/cancelar');
  }

  Future<List<UsuarioAdmin>> listarUsuarios({String? busqueda}) async {
    final response = await _dio.get('/admin/usuarios', queryParameters: {'busqueda': ?busqueda});
    return (response.data as List).map((e) => UsuarioAdmin.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> desactivarUsuario(int id) async {
    await _dio.post('/admin/usuarios/$id/desactivar');
  }

  Future<void> reactivarUsuario(int id) async {
    await _dio.post('/admin/usuarios/$id/reactivar');
  }

  Future<Metricas> obtenerMetricas() async {
    final response = await _dio.get('/admin/metricas');
    return Metricas.fromJson(response.data as Map<String, dynamic>);
  }
}
