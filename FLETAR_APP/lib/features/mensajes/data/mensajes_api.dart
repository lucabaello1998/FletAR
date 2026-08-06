import 'package:dio/dio.dart';

import '../domain/mensaje.dart';

/// Historial de chat de una Oferta puntual - la entrega en tiempo real va por
/// ChatHubClient (SignalR), esto es sólo para el historial (al abrir la
/// pantalla) y para mandar un mensaje nuevo. Ver MensajesController en el
/// backend (ruta a nivel de oferta, no anidada bajo publicaciones).
class MensajesApi {
  MensajesApi(this._dio);

  final Dio _dio;

  /// Más viejo primero (orden de conversación estándar) - mismo orden que
  /// devuelve el backend, no hace falta ordenar de nuevo del lado del cliente.
  Future<List<Mensaje>> listar(int ofertaId) async {
    final response = await _dio.get('/ofertas/$ofertaId/mensajes');
    return (response.data as List).map((e) => Mensaje.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Mensaje> enviar(int ofertaId, String texto) async {
    final response = await _dio.post('/ofertas/$ofertaId/mensajes', data: {'texto': texto});
    return Mensaje.fromJson(response.data as Map<String, dynamic>);
  }
}
