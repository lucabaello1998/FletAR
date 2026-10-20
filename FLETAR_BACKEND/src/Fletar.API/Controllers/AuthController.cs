using Fletar.BLL.Services.Auth;
using Fletar.DTO.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Fletar.API.Controllers;

[ApiController]
[Route("api/auth")]
// Login, registro y refresh son el blanco natural de fuerza bruta: 10 pedidos
// por minuto y por IP (el resto de la API usa el límite global, mucho más alto).
[EnableRateLimiting("auth")]
public class AuthController(IAuthService authService) : ControllerBase
{
    [AllowAnonymous]
    [HttpPost("register")]
    public async Task<ActionResult<LoginResponse>> Register(RegisterRequest request)
        => Ok(await authService.RegistrarAsync(request));

    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<ActionResult<LoginResponse>> Login(LoginRequest request)
        => Ok(await authService.LoginAsync(request));

    [AllowAnonymous]
    [HttpPost("google")]
    public async Task<ActionResult<LoginResponse>> LoginConGoogle(GoogleLoginRequest request)
        => Ok(await authService.LoginConGoogleAsync(request.IdToken));

    [AllowAnonymous]
    [HttpPost("refresh")]
    public async Task<ActionResult<RefreshResponse>> Refresh(RefreshRequest request)
        => Ok(await authService.RefreshAsync(request.RefreshToken));

    [AllowAnonymous]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(RefreshRequest request)
    {
        await authService.LogoutAsync(request.RefreshToken);
        return NoContent();
    }
}
