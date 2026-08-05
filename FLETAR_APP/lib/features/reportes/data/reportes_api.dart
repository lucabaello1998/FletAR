import 'package:dio/dio.dart';

import '../domain/reporte.dart';

class ReportesApi {
  ReportesApi(this._dio);

  final Dio _dio;

  Future<Reporte> crear(int publicacionId, {required String motivo, String? comentario}) async {
    final response = await _dio.post('/publicaciones/$publicacionId/reportes', data: {
      'motivo': motivo,
      'comentario': comentario,
    });
    return Reporte.fromJson(response.data as Map<String, dynamic>);
  }
}
