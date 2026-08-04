import 'package:dio/dio.dart';

import '../domain/oferta.dart';

class OfertasApi {
  OfertasApi(this._dio);

  final Dio _dio;

  Future<List<Oferta>> listar(int publicacionId) async {
    final response = await _dio.get('/publicaciones/$publicacionId/ofertas');
    return (response.data as List).map((e) => Oferta.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Oferta> crear(int publicacionId, {required double monto, String? mensaje}) async {
    final response = await _dio.post('/publicaciones/$publicacionId/ofertas', data: {
      'monto': monto,
      'mensaje': mensaje,
    });
    return Oferta.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Oferta> aceptar(int publicacionId, int ofertaId) async {
    final response = await _dio.post('/publicaciones/$publicacionId/ofertas/$ofertaId/aceptar');
    return Oferta.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Oferta> retirar(int publicacionId, int ofertaId) async {
    final response = await _dio.post('/publicaciones/$publicacionId/ofertas/$ofertaId/retirar');
    return Oferta.fromJson(response.data as Map<String, dynamic>);
  }
}
