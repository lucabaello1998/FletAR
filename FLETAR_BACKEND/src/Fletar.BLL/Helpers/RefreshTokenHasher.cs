using System.Security.Cryptography;
using System.Text;

namespace Fletar.BLL.Helpers;

public static class RefreshTokenHasher
{
    public static string GenerarTokenAleatorio()
    {
        var bytes = RandomNumberGenerator.GetBytes(64);
        return Convert.ToBase64String(bytes);
    }

    public static string Hash(string token)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
        return Convert.ToBase64String(bytes);
    }
}
