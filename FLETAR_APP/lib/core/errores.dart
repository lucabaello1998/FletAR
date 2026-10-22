import 'package:dio/dio.dart';

/// Convierte un error de red/API en un mensaje apto para mostrarle al usuario.
/// La API (`ManejadorDeExcepciones`) devuelve un ProblemDetails con `title` como
/// el único campo seguro para mostrar - ver CLAUDE.md, sección Autenticación.
///
/// Los títulos de validación (400) sí son útiles ("El título debe tener entre…"),
/// pero "Error interno" (500) no le dice nada al usuario: para 5xx se muestra un
/// mensaje propio. Un 401 sin cuerpo (el caso de JWT vencido, que ASP.NET
/// devuelve vacío) antes caía en "Ocurrió un error inesperado" y confundía.
String mensajeDeError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;

    if (status == 401) return 'Tu sesión expiró. Volvé a iniciar sesión.';
    if (status == 403) return 'No tenés permiso para hacer eso.';
    if (status == 404) return 'No encontramos lo que buscabas.';
    if (status == 429) return 'Demasiados intentos seguidos. Esperá un momento y probá de nuevo.';
    if (status != null && status >= 500) {
      return 'El servidor tuvo un problema. Probá de nuevo en un rato.';
    }

    final data = error.response?.data;
    if (data is Map && data['title'] is String) {
      return data['title'] as String;
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'No se pudo conectar con el servidor. Revisá tu conexión.';
    }
  }
  return 'Ocurrió un error inesperado. Probá de nuevo.';
}
