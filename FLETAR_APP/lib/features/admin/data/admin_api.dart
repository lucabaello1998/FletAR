import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../reportes/domain/reporte.dart';
import '../domain/metricas.dart';
import '../domain/usuario_admin.dart';
import '../domain/verificacion_identidad_admin.dart';

class AdminApi {
  AdminApi(this._dio);

  final Dio _dio;

  Future<List<Reporte>> listarReportes({String? estado}) async {
    final response = await _dio.get(
      '/admin/reportes',
      queryParameters: {'estado': ?estado},
    );
    return (response.data as List)
        .map((e) => Reporte.fromJson(e as Map<String, dynamic>))
        .toList();
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
    final response = await _dio.get(
      '/admin/usuarios',
      queryParameters: {'busqueda': ?busqueda},
    );
    return (response.data as List)
        .map((e) => UsuarioAdmin.fromJson(e as Map<String, dynamic>))
        .toList();
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

  /// `estado` es opcional: sin él vienen todas (el backend valida Pendiente /
  /// Aprobada / Rechazada y rechaza cualquier otra cosa).
  Future<List<VerificacionIdentidadAdmin>> listarVerificacionesIdentidad({
    String? estado,
  }) async {
    final response = await _dio.get(
      '/admin/verificaciones-identidad',
      queryParameters: {'estado': ?estado},
    );
    return (response.data as List)
        .map(
          (e) => VerificacionIdentidadAdmin.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  /// Los documentos son privados: se piden como bytes con el token del admin y
  /// se muestran con `Image.memory` - nunca como URL pública.
  Future<Uint8List> descargarDocumentoVerificacion(
    int verificacionId,
    String lado,
  ) async {
    final response = await _dio.get<List<int>>(
      '/admin/verificaciones-identidad/$verificacionId/documento/$lado',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  Future<void> aprobarVerificacion(int verificacionId) async {
    await _dio.post('/admin/verificaciones-identidad/$verificacionId/aprobar');
  }

  Future<void> rechazarVerificacion(
    int verificacionId, {
    String? comentario,
  }) async {
    await _dio.post(
      '/admin/verificaciones-identidad/$verificacionId/rechazar',
      data: {'comentario': comentario},
    );
  }
}
