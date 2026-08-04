import 'package:dio/dio.dart';

/// Convierte un error de red/API en un mensaje apto para mostrarle al usuario.
/// La API (`ManejadorDeExcepciones`) devuelve un ProblemDetails con `title` como
/// el único campo seguro para mostrar - ver CLAUDE.md, sección Autenticación.
String mensajeDeError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['title'] is String) {
      return data['title'] as String;
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'No se pudo conectar con el servidor. Revisá tu conexión.';
    }
  }
  return 'Ocurrió un error inesperado. Probá de nuevo.';
}
