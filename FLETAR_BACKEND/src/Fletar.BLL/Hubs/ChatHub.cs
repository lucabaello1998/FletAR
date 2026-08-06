using System.IdentityModel.Tokens.Jwt;
using Fletar.DAL;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace Fletar.BLL.Hubs;

/// Chat en vivo de una Oferta puntual (Fase 7): el dueño de la publicación y el
/// oferente de esa oferta se unen al mismo grupo para recibir los mensajes que
/// el otro manda por POST /api/ofertas/{ofertaId}/mensajes en tiempo real -
/// mismo patrón de autorización explícita que UbicacionHub (Fase 6), pero vive
/// en Fletar.BLL (no en Fletar.API/Hubs como UbicacionHub) porque
/// MensajeService necesita poder inyectar IHubContext<ChatHub> para notificar
/// al grupo desde fuera del propio Hub, y Fletar.BLL no puede referenciar
/// Fletar.API (la dependencia del proyecto va al revés: API -> BLL).
[Authorize]
public class ChatHub(FletarDbContext db) : Hub
{
    public static string GrupoDeConversacion(int ofertaId) => $"conversacion-{ofertaId}";

    /// Lo llama quien abre la pantalla de chat de una oferta puntual - dueño de
    /// la publicación u oferente de esa oferta, nadie más. Autorización real
    /// (no sólo un filtro de UI): tira HubException si quien llama no es una de
    /// las dos partes de esta conversación. Mismo criterio inline que
    /// UbicacionHub.SeguirFletero (join Publicacion+Oferta, sin delegar a un
    /// Service) en vez de MensajeService.VerificarAccesoAsync.
    public async Task SeguirConversacion(int ofertaId)
    {
        var usuarioId = UsuarioIdActual();

        var partes = await (
            from o in db.Ofertas
            join p in db.Publicaciones on o.PublicacionId equals p.Id
            where o.Id == ofertaId
            select new { OfertanteId = o.UsuarioId, DuenoId = p.UsuarioId }
        ).SingleOrDefaultAsync();

        if (partes is null)
            throw new HubException("La oferta indicada no existe.");

        if (usuarioId != partes.OfertanteId && usuarioId != partes.DuenoId)
            throw new HubException("No podés acceder a esta conversación.");

        await Groups.AddToGroupAsync(Context.ConnectionId, GrupoDeConversacion(ofertaId));
    }

    /// Se llama al salir de la pantalla de chat, para dejar de recibir mensajes
    /// de esta conversación en esta conexión.
    public Task DejarDeSeguirConversacion(int ofertaId)
        => Groups.RemoveFromGroupAsync(Context.ConnectionId, GrupoDeConversacion(ofertaId));

    private int UsuarioIdActual()
    {
        var claim = Context.User?.FindFirst(JwtRegisteredClaimNames.Sub)
            ?? throw new HubException("El token no contiene el claim 'sub'.");

        return int.Parse(claim.Value);
    }
}
