import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/archivos/imagen_mime.dart';
import '../domain/categoria_carga.dart';
import '../domain/publicacion.dart';
import '../domain/publicacion_foto.dart';
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
      'fechaDeseada': _fechaDeseadaIso(fechaDeseada),
    });
    return Publicacion.fromJson(response.data as Map<String, dynamic>);
  }

  /// `fechaDeseada` es una FECHA (el día en que se necesita el flete), no un
  /// instante. La columna en Postgres es `timestamptz`, así que mandar el 00:00
  /// local como UTC hacía que en Argentina se mostrara el día anterior (las
  /// 21:00 del día previo). Se manda el mediodía UTC de ese día: cualquier huso
  /// entre UTC-11 y UTC+11 sigue mostrando el mismo día calendario.
  String? _fechaDeseadaIso(DateTime? fecha) {
    if (fecha == null) return null;
    final local = fecha.toLocal();
    return DateTime.utc(local.year, local.month, local.day, 12).toIso8601String();
  }

  Future<Publicacion> editar(
    int id, {
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
    final response = await _dio.put('/publicaciones/$id', data: {
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
      'fechaDeseada': _fechaDeseadaIso(fechaDeseada),
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

  // Fotos de carga (Fase 8) - sÃ³lo el dueÃ±o puede agregar/borrar (lo valida
  // el backend, esto no duplica esa regla), pÃºblicas para cualquiera que vea
  // el detalle.
  Future<PublicacionFoto> agregarFoto(int publicacionId, XFile archivo) async {
    final bytes = await archivo.readAsBytes();
    final formData = FormData.fromMap({
      'archivo': MultipartFile.fromBytes(
        bytes,
        filename: archivo.name,
        contentType: mimeTypeDeImagen(nombreArchivo: archivo.name, mimeTypeConocido: archivo.mimeType),
      ),
    });
    final response = await _dio.post('/publicaciones/$publicacionId/fotos', data: formData);
    return PublicacionFoto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> eliminarFoto(int publicacionId, int fotoId) =>
      _dio.delete('/publicaciones/$publicacionId/fotos/$fotoId');

  List<Publicacion> _listaDesdeResponse(dynamic data) =>
      (data as List).map((e) => Publicacion.fromJson(e as Map<String, dynamic>)).toList();
}
