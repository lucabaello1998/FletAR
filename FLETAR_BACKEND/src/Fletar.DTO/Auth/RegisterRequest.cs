namespace Fletar.DTO.Auth;

public class RegisterRequest
{
    public string Nombre { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string Password { get; set; } = null!;
    public string? Telefono { get; set; }
}
