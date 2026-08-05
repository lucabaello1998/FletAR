namespace Fletar.DTO.Usuarios;

/// Perfil público de un usuario: sólo lo que cualquiera puede ver de otra
/// persona en el marketplace. Nunca agregar acá Email, PasswordHash, Rol,
/// Telefono ni ningún otro dato privado - para eso está UsuarioResponse
/// (Fletar.DTO.Auth), que sólo se devuelve al propio dueño de la cuenta.
public class UsuarioPublicoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = null!;
    public string? FotoUrl { get; set; }
    public double? PromedioCalificacion { get; set; }
    public int CantidadCalificaciones { get; set; }
}
