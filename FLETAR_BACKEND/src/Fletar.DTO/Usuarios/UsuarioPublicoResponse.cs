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

    /// Señal de confianza adicional a la reputación (Fase 3) y a la foto de
    /// vehículo (Fase 8) - true sólo si existe una VerificacionIdentidad
    /// Aprobada para este usuario (Fase 9). No es una columna propia de
    /// Usuario: se deriva en UsuarioService.ObtenerPerfilPublicoAsync.
    public bool EstaVerificado { get; set; }
}
