using Fletar.DAL.Models;

namespace Fletar.BLL.Helpers;

public interface IJwtTokenGenerator
{
    (string Token, DateTime Expiracion) GenerarAccessToken(Usuario usuario);
}
