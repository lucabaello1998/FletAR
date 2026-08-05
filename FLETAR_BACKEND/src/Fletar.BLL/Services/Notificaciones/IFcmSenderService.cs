namespace Fletar.BLL.Services.Notificaciones;

public interface IFcmSenderService
{
    /// No-op si Firebase no está configurado o el usuario no tiene FcmToken
    /// registrado (desktop/web todavía no lo soportan - ver CLAUDE.md, Stack).
    Task NotificarAsync(int usuarioId, string titulo, string cuerpo);
}
