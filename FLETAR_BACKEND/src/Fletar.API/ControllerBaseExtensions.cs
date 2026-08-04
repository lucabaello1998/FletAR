using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Mvc;

namespace Fletar.API;

public static class ControllerBaseExtensions
{
    /// Extrae el id del usuario logueado desde el claim "sub" del JWT. Los datos de
    /// auditoría (quién crea/es dueño de un recurso) siempre salen del token, nunca del body.
    public static int UsuarioIdActual(this ControllerBase controller)
    {
        var claim = controller.User.FindFirst(JwtRegisteredClaimNames.Sub)
            ?? throw new UnauthorizedAccessException("El token no contiene el claim 'sub'.");

        return int.Parse(claim.Value);
    }
}
