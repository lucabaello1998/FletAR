namespace Fletar.DTO.Auth;

public class LoginResponse
{
    public string AccessToken { get; set; } = null!;
    public string RefreshToken { get; set; } = null!;
    public DateTime AccessTokenExpiracion { get; set; }
    public UsuarioResponse Usuario { get; set; } = null!;
}

public class UsuarioResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string? Telefono { get; set; }
    public string? FotoUrl { get; set; }
    public string Rol { get; set; } = null!;
}
