using System.Text;

namespace Fletar.BLL.Settings;

public class JwtSettings
{
    public string Key { get; }
    public string Issuer { get; }
    public string Audience { get; }
    public TimeSpan AccessTokenDuracion { get; }
    public TimeSpan RefreshTokenDuracion { get; }

    public JwtSettings(string key, string issuer, string audience,
        TimeSpan? accessTokenDuracion = null, TimeSpan? refreshTokenDuracion = null)
    {
        if (Encoding.UTF8.GetByteCount(key) < 32)
            throw new InvalidOperationException(
                "FLETAR_JWT_KEY debe tener al menos 32 bytes (HmacSha256 lo exige).");

        Key = key;
        Issuer = issuer;
        Audience = audience;
        AccessTokenDuracion = accessTokenDuracion ?? TimeSpan.FromMinutes(15);
        RefreshTokenDuracion = refreshTokenDuracion ?? TimeSpan.FromDays(30);
    }
}
