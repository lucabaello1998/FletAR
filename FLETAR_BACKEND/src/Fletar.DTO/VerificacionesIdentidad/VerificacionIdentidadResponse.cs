namespace Fletar.DTO.VerificacionesIdentidad;

/// Estado propio de la solicitud de verificación de identidad (Fase 9) - lo
/// que el usuario ve sobre sí mismo (GET /api/usuarios/me/verificacion-identidad).
/// Nunca expone los archivos ni sus nombres: sólo un Admin puede verlos, vía
/// el endpoint de descarga bajo /api/admin.
public class VerificacionIdentidadResponse
{
    public int Id { get; set; }
    public string Estado { get; set; } = null!;
    public DateTime FechaSolicitud { get; set; }
    public DateTime? FechaRevision { get; set; }
    public string? ComentarioAdmin { get; set; }
}
