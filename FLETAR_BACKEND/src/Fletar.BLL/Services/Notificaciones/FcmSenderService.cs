using Fletar.BLL.Settings;
using Fletar.DAL;
using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Fletar.BLL.Services.Notificaciones;

public class FcmSenderService(FletarDbContext db, FirebaseSettings firebaseSettings, ILogger<FcmSenderService> logger)
    : IFcmSenderService
{
    public async Task NotificarAsync(int usuarioId, string titulo, string cuerpo)
    {
        if (!firebaseSettings.EstaConfigurado) return;

        var fcmToken = await db.Usuarios
            .Where(u => u.Id == usuarioId)
            .Select(u => u.FcmToken)
            .SingleOrDefaultAsync();

        if (string.IsNullOrEmpty(fcmToken)) return;

        // Message.Token está marcado obsoleto a favor de Fid (Firebase Installation ID)
        // en este SDK, pero Fid identifica la instalación en general, no un target de
        // push - el cliente (firebase_messaging en Flutter) sigue exponiendo un token
        // de registro clásico vía getToken(), que es justo lo que este campo espera.
#pragma warning disable CS0618
        var mensaje = new Message
        {
            Token = fcmToken,
            Notification = new Notification { Title = titulo, Body = cuerpo }
        };
#pragma warning restore CS0618

        try
        {
            await FirebaseMessaging.DefaultInstance.SendAsync(mensaje);
        }
        catch (Exception ex)
        {
            // Best-effort: un token vencido/inválido (usuario desinstaló la app),
            // credenciales de Firebase vencidas o un error de red no tienen que
            // romper el flujo de negocio que disparó esto (crear oferta,
            // aceptarla, completar la publicación). Estos envíos corren DESPUÉS
            // del SaveChanges: dejarlos escapar convertía una operación ya
            // persistida en un 500 y el cliente la reintentaba, duplicando
            // ofertas y mensajes.
            logger.LogWarning(ex, "No se pudo enviar la notificación push al usuario {UsuarioId}", usuarioId);
        }
    }
}
