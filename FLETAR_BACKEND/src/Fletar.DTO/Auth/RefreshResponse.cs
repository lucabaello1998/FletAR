namespace Fletar.DTO.Auth;

public class RefreshResponse
{
    public string AccessToken { get; set; } = null!;
    public string RefreshToken { get; set; } = null!;
    public DateTime AccessTokenExpiracion { get; set; }
}
