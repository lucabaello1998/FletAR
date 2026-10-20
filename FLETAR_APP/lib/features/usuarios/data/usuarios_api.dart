import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/archivos/imagen_mime.dart';
import '../domain/usuario_publico.dart';
import '../domain/verificacion_identidad.dart';

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
        contentType: mimeTypeDeImagen(
          nombreArchivo: archivo.name,
          mimeTypeConocido: archivo.mimeType,
        ),
      ),
    });
    final response = await _dio.put(
      '/usuarios/me/foto-vehiculo',
      data: formData,
    );
    return (response.data as Map<String, dynamic>)['url'] as String;
  }

  /// Estado de la verificación de identidad (Fase 9) del usuario logueado.
  /// `null` cuando todavía no la pidió: el backend responde 404 con
  /// "Todavía no pediste una verificación de identidad", que acá no es un
  /// error sino el estado inicial normal.
  Future<VerificacionIdentidad?> obtenerVerificacionIdentidad() async {
    try {
      final response = await _dio.get('/usuarios/me/verificacion-identidad');
      return VerificacionIdentidad.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Sube frente y dorso del documento. Los nombres `frente`/`dorso` son los
  /// que espera el binding de `IFormFile` del backend (UsuariosController) -
  /// si cambian acá, hay que cambiarlos allá.
  Future<VerificacionIdentidad> solicitarVerificacionIdentidad({
    required XFile frente,
    required XFile dorso,
  }) async {
    MultipartFile aMultipart(XFile archivo, List<int> bytes) =>
        MultipartFile.fromBytes(
          bytes,
          filename: archivo.name,
          contentType: mimeTypeDeImagen(
            nombreArchivo: archivo.name,
            mimeTypeConocido: archivo.mimeType,
          ),
        );

    final formData = FormData.fromMap({
      'frente': aMultipart(frente, await frente.readAsBytes()),
      'dorso': aMultipart(dorso, await dorso.readAsBytes()),
    });
    final response = await _dio.post(
      '/usuarios/me/verificacion-identidad',
      data: formData,
    );
    return VerificacionIdentidad.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
