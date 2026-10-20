namespace Fletar.DAL.Models;

public enum EstadoVerificacionIdentidad
{
    Pendiente,
    Aprobada,
    Rechazada
}

/// Verificación de identidad de un Usuario (Fase 9): sube frente y dorso de su
/// documento, un admin revisa y aprueba/rechaza. Una fila por usuario (índice
/// único en UsuarioId, ver FletarDbContext) - si ya tenía una solicitud
/// (Pendiente, Aprobada o Rechazada) y vuelve a subir documentos, se actualiza
/// esa misma fila y el Estado vuelve a Pendiente en vez de acumular historial
/// (ver VerificacionIdentidadService.SolicitarAsync).
///
/// Usuario.EstaVerificado NO es una columna propia de Usuario: se deriva acá,
/// consultando si existe una fila con Estado=Aprobada para ese usuario (ver
/// UsuarioService.ObtenerPerfilPublicoAsync) - señal de confianza adicional a
/// la reputación (Fase 3) y a la foto de vehículo (Fase 8).
public class VerificacionIdentidad
{
    public int Id { get; set; }
    public int UsuarioId { get; set; }

    /// Sólo el nombre de archivo generado en disco (GUID + extensión), igual
    /// criterio que PublicacionFoto.NombreArchivo - nunca la URL armada ni el
    /// nombre original que mandó el cliente. A diferencia de las fotos de la
    /// Fase 8 (públicas a propósito), estos dos archivos se guardan bajo
    /// AlmacenamientoSettings.RutaPrivados (IAlmacenamientoArchivosService,
    /// parámetro privado=true) y NUNCA quedan detrás de una URL pública - la
    /// única forma de leerlos es el endpoint autenticado de descarga
    /// (sólo Admin, ver AdminController.DescargarDocumentoVerificacion).
    public string NombreArchivoFrente { get; set; } = null!;
    public string NombreArchivoDorso { get; set; } = null!;

    public EstadoVerificacionIdentidad Estado { get; set; } = EstadoVerificacionIdentidad.Pendiente;
    public DateTime FechaSolicitud { get; set; }
    public DateTime? FechaRevision { get; set; }

    /// Sólo se usa en la práctica al rechazar (opcional incluso ahí) - ver
    /// POST /api/admin/verificaciones-identidad/{id}/rechazar. Null tras
    /// aprobar: no hace falta explicar por qué se aprobó algo.
    public string? ComentarioAdmin { get; set; }
}
