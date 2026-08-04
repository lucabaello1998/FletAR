namespace Fletar.BLL.Settings;

/// A diferencia de JwtSettings, ClientId es opcional: la API tiene que poder
/// arrancar sin Google Sign-In configurado (es una forma de login más, no
/// un requisito para que la app funcione). Si no está seteado, el endpoint
/// /auth/google falla con un mensaje claro en vez de que la API no arranque.
public class GoogleSettings(string? clientId)
{
    public string? ClientId { get; } = clientId;
}
