import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/archivos/imagen_mime.dart';
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

  /// Reemplaza la foto de vehículo del usuario logueado (Fase 8) - señal de
  /// confianza para cuando oferta como fletero. Una sola por usuario; el
  /// backend borra la anterior del disco si tenía una. Devuelve la URL
  /// relativa nueva (ver `resolverUrlMedia`).
  Future<String> actualizarFotoVehiculo(XFile archivo) async {
    final bytes = await archivo.readAsBytes();
    final formData = FormData.fromMap({
      'archivo': MultipartFile.fromBytes(
        bytes,
        filename: archivo.name,
        contentType: mimeTypeDeImagen(nombreArchivo: archivo.name, mimeTypeConocido: archivo.mimeType),
      ),
    });
    final response = await _dio.put('/usuarios/me/foto-vehiculo', data: formData);
    return (response.data as Map<String, dynamic>)['url'] as String;
  }
}
