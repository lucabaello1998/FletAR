import 'package:dio/dio.dart';

import '../domain/calificacion.dart';

class CalificacionesApi {
  CalificacionesApi(this._dio);

  final Dio _dio;

  Future<List<Calificacion>> listar(int publicacionId) async {
    final response = await _dio.get('/publicaciones/$publicacionId/calificaciones');
    return (response.data as List)
        .map((e) => Calificacion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Calificacion> crear(int publicacionId, {required int puntaje, String? comentario}) async {
    final response = await _dio.post('/publicaciones/$publicacionId/calificaciones', data: {
      'puntaje': puntaje,
      'comentario': comentario,
    });
    return Calificacion.fromJson(response.data as Map<String, dynamic>);
  }
}
