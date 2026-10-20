namespace Fletar.DTO.VerificacionesIdentidad;

/// Vista de una solicitud de verificación para el panel admin - a diferencia
/// de VerificacionIdentidadResponse, ésta identifica de quién es la solicitud
/// (UsuarioNombre/UsuarioEmail denormalizados, mismo criterio que
/// ReporteResponse) para el listado de moderación.
public class VerificacionIdentidadAdminResponse
{
    public int Id { get; set; }
    public int UsuarioId { get; set; }
    public string UsuarioNombre { get; set; } = null!;
    public string UsuarioEmail { get; set; } = null!;
    public string Estado { get; set; } = null!;
    public DateTime FechaSolicitud { get; set; }
    public DateTime? FechaRevision { get; set; }
    public string? ComentarioAdmin { get; set; }
}
