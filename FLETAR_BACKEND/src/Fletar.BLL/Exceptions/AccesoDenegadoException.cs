namespace Fletar.BLL.Exceptions;

/// El usuario está autenticado pero no tiene permiso sobre el recurso (no es el
/// dueño, no es parte de la conversación, etc.).
///
/// Se distingue de `UnauthorizedAccessException` (que en este proyecto significa
/// "credenciales/sesión inválidas" y se mapea a 401): un 401 por "no sos el
/// dueño" hacía que la app intentara refrescar el token y mostrara "tu sesión
/// expiró" en vez de "no tenés permiso".
public class AccesoDenegadoException(string mensaje) : Exception(mensaje);
