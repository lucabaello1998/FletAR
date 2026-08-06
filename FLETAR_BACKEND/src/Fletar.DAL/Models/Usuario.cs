namespace Fletar.DAL.Models;

public enum Rol
{
    Usuario,
    Admin
}

public class Usuario
{
    public int Id { get; set; }
    public string Nombre { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string? Telefono { get; set; }
    public string? FotoUrl { get; set; }

    /// Null para una cuenta que solo se registró con Google - no tiene
    /// contraseña propia y no puede loguearse por /auth/login.
    public string? PasswordHash { get; set; }

    public Rol Rol { get; set; } = Rol.Usuario;
    public string? FcmToken { get; set; }
    public DateTime FechaRegistro { get; set; }
    public bool Activo { get; set; } = true;

    /// Última posición conocida de este usuario (ubicación en vivo, Fase 6) - opt-in
    /// explícito del fletero vía el toggle en la app, nunca tracking en segundo plano.
    /// Null si nunca compartió su ubicación.
    public double? UltimaLatitud { get; set; }
    public double? UltimaLongitud { get; set; }
    public DateTime? UltimaUbicacionFecha { get; set; }
}
