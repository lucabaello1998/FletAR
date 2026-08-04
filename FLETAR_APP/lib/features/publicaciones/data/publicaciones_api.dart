import 'package:dio/dio.dart';

import '../domain/categoria_carga.dart';
import '../domain/publicacion.dart';
import '../domain/tipo_vehiculo.dart';

class PublicacionesApi {
  PublicacionesApi(this._dio);

  final Dio _dio;

  Future<List<Publicacion>> listar({
    int page = 1,
    int pageSize = 20,
    String? estado,
    bool soloMias = false,
  }) async {
    final response = await _dio.get('/publicaciones', queryParameters: {
      'page': page,
      'pageSize': pageSize,
      'estado': ?estado,
      'soloMias': soloMias,
    });
    return _listaDesdeResponse(response.data);
  }

  Future<Publicacion> obtenerPorId(int id) async {
    final response = await _dio.get('/publicaciones/$id');
    return Publicacion.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Publicacion> crear({
    required String titulo,
    required String descripcion,
    required int categoriaCargaId,
    int? tipoVehiculoSugeridoId,
    required double latitud,
    required double longitud,
    required String origenDireccionTexto,
    double? destinoLatitud,
    double? destinoLongitud,
    String? destinoDireccionTexto,
    DateTime? fechaDeseada,
  }) async {
    final response = await _dio.post('/publicaciones', data: {
      'titulo': titulo,
      'descripcion': descripcion,
      'categoriaCargaId': categoriaCargaId,
      'tipoVehiculoSugeridoId': tipoVehiculoSugeridoId,
      'latitud': latitud,
      'longitud': longitud,
      'origenDireccionTexto': origenDireccionTexto,
      'destinoLatitud': destinoLatitud,
      'destinoLongitud': destinoLongitud,
      'destinoDireccionTexto': destinoDireccionTexto,
      'fechaDeseada': fechaDeseada?.toIso8601String(),
    });
    return Publicacion.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Publicacion>> cercanas({
    required double lat,
    required double lng,
    required double radioKm,
  }) async {
    final response = await _dio.get('/publicaciones/cercanas', queryParameters: {
      'lat': lat,
      'lng': lng,
      'radioKm': radioKm,
    });
    return _listaDesdeResponse(response.data);
  }

  Future<void> cancelar(int id) async {
    await _dio.post('/publicaciones/$id/cancelar');
  }

  Future<void> iniciar(int id) async {
    await _dio.post('/publicaciones/$id/iniciar');
  }

  Future<void> completar(int id) async {
    await _dio.post('/publicaciones/$id/completar');
  }

  Future<List<CategoriaCarga>> categorias() async {
    final response = await _dio.get('/publicaciones/categorias');
    return (response.data as List)
        .map((e) => CategoriaCarga.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TipoVehiculo>> tiposVehiculo() async {
    final response = await _dio.get('/publicaciones/tipos-vehiculo');
    return (response.data as List)
        .map((e) => TipoVehiculo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<Publicacion> _listaDesdeResponse(dynamic data) =>
      (data as List).map((e) => Publicacion.fromJson(e as Map<String, dynamic>)).toList();
}
