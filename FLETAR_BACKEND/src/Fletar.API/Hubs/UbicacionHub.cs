using System.IdentityModel.Tokens.Jwt;
using Fletar.DAL;
using Fletar.DAL.Models;
using Fletar.DTO.Ubicaciones;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace Fletar.API.Hubs;

/// Ubicación en vivo (Fase 6): el fletero comparte su posición mientras la app
/// está en foreground (opt-in explícito vía un toggle, nunca tracking en
/// segundo plano) y quien tiene una publicación en juego con ese fletero (el
/// dueño evaluando ofertas, o el dueño de una publicación EnCurso) la sigue en
/// tiempo real. Requiere JWT válido - [Authorize] acá exige lo mismo que el
/// FallbackPolicy del resto de la API (cualquier usuario autenticado).
[Authorize]
public class UbicacionHub(FletarDbContext db, SeguimientoUbicacionRegistry seguidores) : Hub
{
    /// Una posición guardada más vieja que esto no se devuelve: el fletero que
    /// cerró la app hace veinte minutos no sigue "en vivo" en el mapa.
    private static readonly TimeSpan VigenciaUbicacion = TimeSpan.FromMinutes(5);

    private static string GrupoDeFletero(int usuarioId) => $"fletero-{usuarioId}";

    /// Lo llama el fletero para publicar su posición actual. Actualiza la
    /// última ubicación conocida en la base (para que alguien que se conecta a
    /// mitad de un tracking vea algo de inmediato) y la emite a quien lo esté
    /// siguiendo en ese momento.
    public async Task ActualizarUbicacion(double lat, double lng)
    {
        if (lat is < -90 or > 90)
            throw new HubException("La latitud debe estar entre -90 y 90.");
        if (lng is < -180 or > 180)
            throw new HubException("La longitud debe estar entre -180 y 180.");

        var usuarioId = UsuarioIdActual();

        var usuario = await db.Usuarios.FindAsync(usuarioId)
            ?? throw new HubException("Usuario no encontrado.");

        var fecha = DateTime.UtcNow;
        usuario.UltimaLatitud = lat;
        usuario.UltimaLongitud = lng;
        usuario.UltimaUbicacionFecha = fecha;
        await db.SaveChangesAsync();

        // No alcanza con mandar al grupo: hay conexiones que quedaron ahí cuando
        // la publicación se completó/canceló. Se revalida cada vínculo y se
        // envía sólo a las conexiones que todavía tienen permiso.
        var conexiones = seguidores.PorFletero(usuarioId);
        if (conexiones.Count == 0)
            return;

        var watcherIds = conexiones.Select(s => s.WatcherId).Distinct().ToList();
        var vinculos = await (
            from p in db.Publicaciones
            join o in db.Ofertas on p.Id equals o.PublicacionId
            where watcherIds.Contains(p.UsuarioId) && o.UsuarioId == usuarioId
            select new { p.UsuarioId, Publicacion = p.Estado, Oferta = o.Estado }).ToListAsync();

        var autorizados = vinculos
            .Where(v => SeguimientoPermitido(v.Publicacion, v.Oferta))
            .Select(v => v.UsuarioId)
            .ToHashSet();

        foreach (var conexion in conexiones)
        {
            if (!autorizados.Contains(conexion.WatcherId))
            {
                seguidores.Quitar(conexion.ConnectionId, usuarioId);
                await Groups.RemoveFromGroupAsync(conexion.ConnectionId, GrupoDeFletero(usuarioId));
                await Clients.Client(conexion.ConnectionId).SendAsync("SeguimientoRevocado", usuarioId);
                continue;
            }

            await Clients.Client(conexion.ConnectionId)
                .SendAsync("RecibirUbicacion", usuarioId, lat, lng, fecha);
        }
    }

    /// Lo llama quien quiere ver a un fletero en vivo (el dueño de una
    /// publicación donde ese fletero tiene una oferta Pendiente o Aceptada).
    /// Autorización obligatoria: es un dato personal sensible (GPS de una
    /// persona) - no se agrega al grupo si quien llama no tiene ese vínculo.
    /// Devuelve la última posición ya guardada (si existe) para que quien
    /// recién se suma no tenga que esperar el próximo ping.
    public async Task<UbicacionActualResponse?> SeguirFletero(int usuarioId)
    {
        var llamanteId = UsuarioIdActual();

        var vinculos = await (
            from p in db.Publicaciones
            join o in db.Ofertas on p.Id equals o.PublicacionId
            where p.UsuarioId == llamanteId && o.UsuarioId == usuarioId
            select new { Publicacion = p.Estado, Oferta = o.Estado }).ToListAsync();

        // La autorización no puede sobrevivir al viaje: cuando la publicación
        // se completa o se cancela, el dueño deja de ver el GPS del fletero
        // aunque haya tenido una oferta aceptada.
        if (!vinculos.Any(v => SeguimientoPermitido(v.Publicacion, v.Oferta)))
            throw new HubException("No podés seguir la ubicación de este usuario.");

        seguidores.Registrar(Context.ConnectionId, llamanteId, usuarioId);
        await Groups.AddToGroupAsync(Context.ConnectionId, GrupoDeFletero(usuarioId));

        var fletero = await db.Usuarios.FindAsync(usuarioId);
        if (fletero?.UltimaLatitud is null || fletero.UltimaLongitud is null || fletero.UltimaUbicacionFecha is null)
            return null;

        if (fletero.UltimaUbicacionFecha < DateTime.UtcNow - VigenciaUbicacion)
            return null;

        return new UbicacionActualResponse
        {
            UsuarioId = usuarioId,
            Lat = fletero.UltimaLatitud.Value,
            Lng = fletero.UltimaLongitud.Value,
            Fecha = fletero.UltimaUbicacionFecha.Value
        };
    }

    /// Quién puede ver el GPS de quién:
    /// - oferta Aceptada: sólo mientras el viaje está por empezar o en curso;
    /// - oferta Pendiente: sólo mientras la publicación sigue abierta (evaluando).
    /// Rechazada, Retirada, Completada o Cancelada no dan acceso nunca.
    public static bool SeguimientoPermitido(EstadoPublicacion publicacion, EstadoOferta oferta) => oferta switch
    {
        EstadoOferta.Aceptada => publicacion is EstadoPublicacion.OfertaAceptada or EstadoPublicacion.EnCurso,
        EstadoOferta.Pendiente => publicacion == EstadoPublicacion.Publicada,
        _ => false
    };

    /// Se llama al salir de la pantalla de tracking, para dejar de recibir
    /// actualizaciones de este fletero.
    public async Task DejarDeSeguirFletero(int usuarioId)
    {
        seguidores.Quitar(Context.ConnectionId, usuarioId);
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, GrupoDeFletero(usuarioId));
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        seguidores.QuitarConexion(Context.ConnectionId);
        await base.OnDisconnectedAsync(exception);
    }

    private int UsuarioIdActual()
    {
        var claim = Context.User?.FindFirst(JwtRegisteredClaimNames.Sub)
            ?? throw new HubException("El token no contiene el claim 'sub'.");

        return int.Parse(claim.Value);
    }
}
