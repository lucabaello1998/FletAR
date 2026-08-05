namespace Fletar.BLL.Settings;

/// Igual que GoogleSettings: opcional. La API tiene que poder arrancar sin
/// Firebase configurado - las notificaciones push son un plus, no un
/// requisito para publicar/ofertar/calificar. Sin la credencial, FcmSenderService
/// no envía nada (no falla, no loguea error, simplemente no hace nada).
public class FirebaseSettings(string? credencialesPath)
{
    public string? CredencialesPath { get; } = credencialesPath;

    public bool EstaConfigurado => !string.IsNullOrWhiteSpace(CredencialesPath) && File.Exists(CredencialesPath);
}
