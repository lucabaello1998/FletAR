namespace Fletar.DTO.Usuarios;

/// Vista de un usuario para el panel admin - a diferencia de UsuarioPublicoResponse,
/// esta SÍ lleva datos privados (Email, Activo), pero sigue sin exponer PasswordHash.
/// Sólo se devuelve detrás de la policy "Admin", nunca a un usuario común.
public class UsuarioAdminResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string? Telefono { get; set; }
    public string Rol { get; set; } = null!;
    public bool Activo { get; set; }
    public DateTime FechaRegistro { get; set; }
    public double? PromedioCalificacion { get; set; }
    public int CantidadCalificaciones { get; set; }
}
