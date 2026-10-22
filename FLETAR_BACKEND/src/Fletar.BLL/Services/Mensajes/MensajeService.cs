using AutoMapper;
using Fletar.BLL.Exceptions;
using Fletar.BLL.Hubs;
using Fletar.BLL.Services.Notificaciones;
using Fletar.DAL;
using Fletar.DAL.Models;
using Fletar.DTO.Mensajes;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace Fletar.BLL.Services.Mensajes;

/// Chat por Oferta (Fase 7): conversación entre el dueño de la publicación y el
/// oferente de esa oferta puntual, disponible tanto antes de que se acepte (para
/// negociar/preguntar) como después (para coordinar el flete) - no hay
/// restricción de EstadoOferta/EstadoPublicacion acá a propósito, a diferencia
/// de CrearAsync en OfertaService.
public class MensajeService(
    FletarDbContext db, IMapper mapper, IFcmSenderService fcmSender, IHubContext<ChatHub> hubContext)
    : IMensajeService
{
    public async Task<IReadOnlyList<MensajeResponse>> ListarAsync(int ofertaId, int usuarioIdActual)
    {
        await VerificarAccesoAsync(ofertaId, usuarioIdActual);

        // Más viejo primero (orden de conversación estándar) - a diferencia de
        // OfertaService.ListarMiasAsync, que ordena descendente porque ahí lo
        // que importa es "lo más reciente arriba" en un listado, no un hilo.
        var mensajes = await db.Mensajes
            .Where(m => m.OfertaId == ofertaId)
            .OrderBy(m => m.FechaEnvio)
            .ToListAsync();

        return await MapearConNombresAsync(mensajes);
    }

    public async Task<MensajeResponse> EnviarAsync(int ofertaId, int usuarioIdActual, MensajeCreateRequest request)
    {
        var partes = await VerificarAccesoAsync(ofertaId, usuarioIdActual);

        // Validación real en el servidor, no sólo confiar en la UI (ver hallazgo
        // de la pasada de mejora continua post-Fase 5 sobre falta de validación
        // server-side de Monto en OfertaCreateRequest - no repetir el mismo hueco
        // acá).
        var texto = request.Texto?.Trim() ?? string.Empty;
        if (texto.Length == 0)
            throw new InvalidOperationException("El mensaje no puede estar vacío.");
        if (texto.Length > Mensaje.TextoLargoMaximo)
            throw new InvalidOperationException($"El mensaje no puede superar los {Mensaje.TextoLargoMaximo} caracteres.");

        var mensaje = new Mensaje
        {
            OfertaId = ofertaId,
            RemitenteId = usuarioIdActual,
            Texto = texto,
            FechaEnvio = DateTime.UtcNow
        };

        db.Mensajes.Add(mensaje);
        await db.SaveChangesAsync();

        var response = await MapearConNombreAsync(mensaje);

        // Entrega en tiempo real a quien tenga la pantalla de chat abierta -
        // mismo mecanismo de grupos que UbicacionHub, pero disparado desde acá
        // (un Service, no el propio Hub) porque el mensaje se crea por POST, no
        // por un método de Hub.
        await hubContext.Clients.Group(ChatHub.GrupoDeConversacion(ofertaId))
            .SendAsync("RecibirMensaje", response);

        // Push a la otra parte (dueño si escribe el fletero, fletero si escribe
        // el dueño) - mismo patrón que los tres disparadores de OfertaService.
        var otraParteId = usuarioIdActual == partes.DuenoId ? partes.OfertanteId : partes.DuenoId;
        var resumen = texto.Length > 80 ? texto[..80] + "…" : texto;
        await fcmSender.NotificarAsync(
            otraParteId,
            $"Nuevo mensaje en \"{partes.PublicacionTitulo}\"",
            $"{response.RemitenteNombre}: {resumen}");

        return response;
    }

    /// Busca la oferta+publicación de esta conversación y valida que
    /// usuarioIdActual sea el dueño de la publicación o el oferente de esta
    /// oferta puntual - nadie más puede ver ni mandar mensajes acá. Mismo
    /// patrón que OfertaService (buscar oferta+publicación, comparar contra
    /// UsuarioId de cada una) pero cruzando las dos partes de la conversación
    /// en vez de una sola.
    private async Task<(int OfertanteId, int DuenoId, string PublicacionTitulo)> VerificarAccesoAsync(
        int ofertaId, int usuarioIdActual)
    {
        var partes = await (
            from o in db.Ofertas
            join p in db.Publicaciones on o.PublicacionId equals p.Id
            where o.Id == ofertaId
            select new { OfertanteId = o.UsuarioId, DuenoId = p.UsuarioId, p.Titulo }
        ).SingleOrDefaultAsync();

        if (partes is null)
            throw new KeyNotFoundException("La oferta indicada no existe.");

        if (usuarioIdActual != partes.OfertanteId && usuarioIdActual != partes.DuenoId)
            throw new AccesoDenegadoException("No tenés permiso para acceder a esta conversación.");

        return (partes.OfertanteId, partes.DuenoId, partes.Titulo);
    }

    // Mismo criterio que OfertaService.MapearConNombreAsync: RemitenteNombre no
    // viene de una navegación de EF, se resuelve acá con un único lookup.
    private async Task<MensajeResponse> MapearConNombreAsync(Mensaje mensaje)
    {
        var response = mapper.Map<MensajeResponse>(mensaje);
        response.RemitenteNombre = await db.Usuarios
            .Where(u => u.Id == mensaje.RemitenteId)
            .Select(u => u.Nombre)
            .SingleOrDefaultAsync() ?? string.Empty;
        return response;
    }

    private async Task<IReadOnlyList<MensajeResponse>> MapearConNombresAsync(List<Mensaje> mensajes)
    {
        var responses = mapper.Map<List<MensajeResponse>>(mensajes);

        var remitenteIds = mensajes.Select(m => m.RemitenteId).Distinct().ToList();
        var nombresPorId = await db.Usuarios
            .Where(u => remitenteIds.Contains(u.Id))
            .Select(u => new { u.Id, u.Nombre })
            .ToDictionaryAsync(u => u.Id, u => u.Nombre);

        foreach (var response in responses)
            response.RemitenteNombre = nombresPorId.GetValueOrDefault(response.RemitenteId, string.Empty);

        return responses;
    }
}
