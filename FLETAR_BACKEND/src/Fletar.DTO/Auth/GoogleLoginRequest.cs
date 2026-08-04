namespace Fletar.DTO.Auth;

public class GoogleLoginRequest
{
    /// El ID token que devuelve el SDK de Google Sign-In del lado del cliente
    /// (Android/iOS/Web) - la API lo valida contra los servidores de Google,
    /// nunca confía en el email/nombre que mande el cliente directamente.
    public string IdToken { get; set; } = null!;
}
