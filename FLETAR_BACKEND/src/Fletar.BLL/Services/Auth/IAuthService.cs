using Fletar.DTO.Auth;

namespace Fletar.BLL.Services.Auth;

public interface IAuthService
{
    Task<LoginResponse> RegistrarAsync(RegisterRequest request);
    Task<LoginResponse> LoginAsync(LoginRequest request);
    Task<LoginResponse> LoginConGoogleAsync(string idToken);
    Task<RefreshResponse> RefreshAsync(string refreshToken);
    Task LogoutAsync(string refreshToken);
}
