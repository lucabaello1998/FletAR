using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Fletar.BLL.Settings;
using Fletar.DAL.Models;
using Microsoft.IdentityModel.Tokens;

namespace Fletar.BLL.Helpers;

public class JwtTokenGenerator(JwtSettings jwtSettings) : IJwtTokenGenerator
{
    public (string Token, DateTime Expiracion) GenerarAccessToken(Usuario usuario)
    {
        var expiracion = DateTime.UtcNow.Add(jwtSettings.AccessTokenDuracion);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, usuario.Id.ToString()),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new Claim("rol", usuario.Rol.ToString().ToLowerInvariant())
        };

        var credenciales = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings.Key)),
            SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: jwtSettings.Issuer,
            audience: jwtSettings.Audience,
            claims: claims,
            expires: expiracion,
            signingCredentials: credenciales);

        return (new JwtSecurityTokenHandler().WriteToken(token), expiracion);
    }
}
