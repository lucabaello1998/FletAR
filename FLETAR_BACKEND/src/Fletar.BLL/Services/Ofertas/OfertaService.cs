using AutoMapper;
using Fletar.BLL.Services.Notificaciones;
using Fletar.DAL;
using Fletar.DAL.Models;
using Fletar.DTO.Ofertas;
using Microsoft.EntityFrameworkCore;

namespace Fletar.BLL.Services.Ofertas;

public class OfertaService(FletarDbContext db, IMapper mapper, IFcmSenderService fcmSender) : IOfertaService
{
    public async Task<OfertaResponse> CrearAsync(int usuarioId, int publicacionId, OfertaCreateRequest request)
    {
        var publicacion = await BuscarPublicacionOFallarAsync(publicacionId);

        if (publicacion.Estado != EstadoPublicacion.Publicada)
            throw new InvalidOperationException("Sólo se puede ofertar sobre una publicación en estado Publicada.");

        if (usuarioId == publicacion.UsuarioId)
            throw new InvalidOperationException("No podés ofertar en tu propia publicación.");

        var oferta = new Oferta
        {
            PublicacionId = publicacionId,
            UsuarioId = usuarioId,
            Monto = request.Monto,
            Mensaje = request.Mensaje,
            FechaOferta = DateTime.UtcNow,
            Estado = EstadoOferta.Pendiente
        };

        db.Ofertas.Add(oferta);
        await db.SaveChangesAsync();

        await fcmSender.NotificarAsync(
            publicacion.UsuarioId,
            "Nueva oferta",
            $"Recibiste una oferta de ${request.Monto} en \"{publicacion.Titulo}\".");

        return await MapearConNombreAsync(oferta);
    }

    public async Task<IReadOnlyList<OfertaResponse>> ListarPorPublicacionAsync(int publicacionId, int usuarioIdActual)
    {
        var publicacion = await BuscarPublicacionOFallarAsync(publicacionId);

        var query = db.Ofertas.Where(o => o.PublicacionId == publicacionId);

        // Sólo el dueño de la publicación puede ver el listado completo (Monto y
        // Mensaje de cada oferente). A quien no es dueño le devolvemos como
        // máximo su propia oferta.
        if (publicacion.UsuarioId != usuarioIdActual)
            query = query.Where(o => o.UsuarioId == usuarioIdActual);

        var ofertas = await query
            .OrderByDescending(o => o.FechaOferta)
            .ToListAsync();

        return await MapearConNombresAsync(ofertas);
    }

    public async Task<IReadOnlyList<OfertaResponse>> ListarMiasAsync(int usuarioId)
    {
        // A diferencia de ListarPorPublicacionAsync, esto cruza publicaciones en
        // cualquier estado: es la única forma que tiene un fletero (oferente, no
        // dueño) de volver a encontrar una publicación una vez que deja de estar
        // Publicada - "Mis publicaciones" filtra por dueño, y el listado público
        // filtra a Publicada, así que sin esto no hay ningún camino de navegación
        // para que oferte, y después, califique al dueño.
        var ofertas = await db.Ofertas
            .Where(o => o.UsuarioId == usuarioId)
            .OrderByDescending(o => o.FechaOferta)
            .ToListAsync();

        return await MapearConNombresAsync(ofertas);
    }

    public async Task<OfertaResponse> AceptarAsync(int publicacionId, int ofertaId, int usuarioIdQueAcepta)
    {
        var publicacion = await BuscarPublicacionOFallarAsync(publicacionId);

        if (publicacion.UsuarioId != usuarioIdQueAcepta)
            throw new UnauthorizedAccessException("No tenés permiso para aceptar ofertas de esta publicación.");

        if (publicacion.Estado != EstadoPublicacion.Publicada)
            throw new InvalidOperationException("Sólo se puede aceptar una oferta cuando la publicación está en estado Publicada.");

        var oferta = await BuscarOfertaOFallarAsync(ofertaId);

        if (oferta.PublicacionId != publicacionId)
            throw new InvalidOperationException("La oferta indicada no pertenece a esta publicación.");

        if (oferta.Estado != EstadoOferta.Pendiente)
            throw new InvalidOperationException("Sólo se puede aceptar una oferta que esté Pendiente.");

        var otrasOfertasPendientes = await db.Ofertas
            .Where(o => o.PublicacionId == publicacionId && o.Estado == EstadoOferta.Pendiente && o.Id != ofertaId)
            .ToListAsync();

        foreach (var otra in otrasOfertasPendientes)
            otra.Estado = EstadoOferta.Rechazada;

        oferta.Estado = EstadoOferta.Aceptada;
        publicacion.OfertaAceptadaId = oferta.Id;
        publicacion.Estado = EstadoPublicacion.OfertaAceptada;

        await db.SaveChangesAsync();

        await fcmSender.NotificarAsync(
            oferta.UsuarioId,
            "¡Te aceptaron la oferta!",
            $"Tu oferta en \"{publicacion.Titulo}\" fue aceptada.");

        return await MapearConNombreAsync(oferta);
    }

    public async Task<OfertaResponse> RetirarAsync(int ofertaId, int usuarioIdQueRetira)
    {
        var oferta = await BuscarOfertaOFallarAsync(ofertaId);

        if (oferta.UsuarioId != usuarioIdQueRetira)
            throw new UnauthorizedAccessException("No tenés permiso para retirar esta oferta.");

        if (oferta.Estado != EstadoOferta.Pendiente)
            throw new InvalidOperationException("Sólo se puede retirar una oferta que esté Pendiente.");

        oferta.Estado = EstadoOferta.Retirada;
        await db.SaveChangesAsync();

        return await MapearConNombreAsync(oferta);
    }

    public async Task IniciarAsync(int publicacionId, int usuarioIdDueno)
    {
        var publicacion = await BuscarPublicacionOFallarAsync(publicacionId);

        if (publicacion.UsuarioId != usuarioIdDueno)
            throw new UnauthorizedAccessException("No tenés permiso para iniciar esta publicación.");

        if (publicacion.Estado != EstadoPublicacion.OfertaAceptada)
            throw new InvalidOperationException("Sólo se puede iniciar una publicación que tenga una oferta aceptada.");

        publicacion.Estado = EstadoPublicacion.EnCurso;
        await db.SaveChangesAsync();
    }

    public async Task CompletarAsync(int publicacionId, int usuarioIdDueno)
    {
        var publicacion = await BuscarPublicacionOFallarAsync(publicacionId);

        if (publicacion.UsuarioId != usuarioIdDueno)
            throw new UnauthorizedAccessException("No tenés permiso para completar esta publicación.");

        if (publicacion.Estado != EstadoPublicacion.EnCurso)
            throw new InvalidOperationException("Sólo se puede completar una publicación que esté En Curso.");

        publicacion.Estado = EstadoPublicacion.Completada;
        await db.SaveChangesAsync();

        var mensaje = $"\"{publicacion.Titulo}\" se completó. Ya podés calificar a la otra parte.";
        await fcmSender.NotificarAsync(publicacion.UsuarioId, "Flete completado", mensaje);

        var fleteroId = await db.Ofertas
            .Where(o => o.Id == publicacion.OfertaAceptadaId)
            .Select(o => o.UsuarioId)
            .SingleOrDefaultAsync();
        if (fleteroId != default)
            await fcmSender.NotificarAsync(fleteroId, "Flete completado", mensaje);
    }

    private async Task<Publicacion> BuscarPublicacionOFallarAsync(int publicacionId)
        => await db.Publicaciones.SingleOrDefaultAsync(p => p.Id == publicacionId)
            ?? throw new KeyNotFoundException("La publicación indicada no existe.");

    private async Task<Oferta> BuscarOfertaOFallarAsync(int ofertaId)
        => await db.Ofertas.SingleOrDefaultAsync(o => o.Id == ofertaId)
            ?? throw new KeyNotFoundException("La oferta indicada no existe.");

    // Mismo criterio que en PublicacionService: UsuarioNombre no viene de una
    // navegación de EF, se resuelve acá con un único lookup por lote.
    private async Task<OfertaResponse> MapearConNombreAsync(Oferta oferta)
    {
        var response = mapper.Map<OfertaResponse>(oferta);
        response.UsuarioNombre = await db.Usuarios
            .Where(u => u.Id == oferta.UsuarioId)
            .Select(u => u.Nombre)
            .SingleOrDefaultAsync() ?? string.Empty;

        var publicacion = await db.Publicaciones
            .Where(p => p.Id == oferta.PublicacionId)
            .Select(p => new { p.Titulo, p.Estado })
            .SingleOrDefaultAsync();
        response.PublicacionTitulo = publicacion?.Titulo ?? string.Empty;
        response.PublicacionEstado = publicacion?.Estado.ToString() ?? string.Empty;

        return response;
    }

    private async Task<IReadOnlyList<OfertaResponse>> MapearConNombresAsync(List<Oferta> ofertas)
    {
        var responses = mapper.Map<List<OfertaResponse>>(ofertas);

        var usuarioIds = ofertas.Select(o => o.UsuarioId).Distinct().ToList();
        var nombresPorId = await db.Usuarios
            .Where(u => usuarioIds.Contains(u.Id))
            .Select(u => new { u.Id, u.Nombre })
            .ToDictionaryAsync(u => u.Id, u => u.Nombre);

        var publicacionIds = ofertas.Select(o => o.PublicacionId).Distinct().ToList();
        var publicacionesPorId = await db.Publicaciones
            .Where(p => publicacionIds.Contains(p.Id))
            .Select(p => new { p.Id, p.Titulo, p.Estado })
            .ToDictionaryAsync(p => p.Id);

        foreach (var response in responses)
        {
            response.UsuarioNombre = nombresPorId.GetValueOrDefault(response.UsuarioId, string.Empty);
            if (publicacionesPorId.TryGetValue(response.PublicacionId, out var publicacion))
            {
                response.PublicacionTitulo = publicacion.Titulo;
                response.PublicacionEstado = publicacion.Estado.ToString();
            }
        }

        return responses;
    }
}
