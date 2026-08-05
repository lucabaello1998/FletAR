using AutoMapper;
using Fletar.DAL;
using Fletar.DAL.Models;
using Fletar.DTO.Calificaciones;
using Microsoft.EntityFrameworkCore;

namespace Fletar.BLL.Services.Calificaciones;

public class CalificacionService(FletarDbContext db, IMapper mapper) : ICalificacionService
{
    public async Task<CalificacionResponse> CrearAsync(int usuarioId, int publicacionId, CalificacionCreateRequest request)
    {
        if (request.Puntaje is < 1 or > 5)
            throw new InvalidOperationException("El puntaje debe estar entre 1 y 5.");

        var publicacion = await BuscarPublicacionOFallarAsync(publicacionId);

        if (publicacion.Estado != EstadoPublicacion.Completada)
            throw new InvalidOperationException("Sólo se puede calificar una publicación completada.");

        var usuarioCalificadoId = await DeterminarCalificadoAsync(publicacion, usuarioId);

        // Chequeo de negocio con mensaje legible, además del índice único de la base
        // (Calificaciones sobre (PublicacionId, UsuarioQueCalificaId)) que actúa como
        // red de seguridad final ante una carrera entre dos pedidos concurrentes.
        var yaCalifico = await db.Calificaciones
            .AnyAsync(c => c.PublicacionId == publicacionId && c.UsuarioQueCalificaId == usuarioId);
        if (yaCalifico)
            throw new InvalidOperationException("Ya calificaste esta publicación.");

        var calificacion = new Calificacion
        {
            PublicacionId = publicacionId,
            UsuarioQueCalificaId = usuarioId,
            UsuarioCalificadoId = usuarioCalificadoId,
            Puntaje = request.Puntaje,
            Comentario = request.Comentario,
            FechaCalificacion = DateTime.UtcNow
        };

        db.Calificaciones.Add(calificacion);
        await db.SaveChangesAsync();

        return mapper.Map<CalificacionResponse>(calificacion);
    }

    public async Task<IReadOnlyList<CalificacionResponse>> ListarPorPublicacionAsync(int publicacionId)
    {
        await BuscarPublicacionOFallarAsync(publicacionId);

        var calificaciones = await db.Calificaciones
            .Where(c => c.PublicacionId == publicacionId)
            .OrderBy(c => c.FechaCalificacion)
            .ToListAsync();

        return mapper.Map<List<CalificacionResponse>>(calificaciones);
    }

    /// Determina quién es "la otra parte" a calificar: si quien califica es el
    /// dueño de la publicación, califica al fletero de la oferta aceptada; si es
    /// el fletero de esa oferta, califica al dueño. Cualquier otra persona no
    /// participó de la publicación y no puede calificar.
    private async Task<int> DeterminarCalificadoAsync(Publicacion publicacion, int usuarioId)
    {
        var ofertaAceptada = await db.Ofertas.SingleOrDefaultAsync(o => o.Id == publicacion.OfertaAceptadaId)
            ?? throw new InvalidOperationException("La publicación no tiene una oferta aceptada asociada.");

        if (usuarioId == publicacion.UsuarioId)
            return ofertaAceptada.UsuarioId;

        if (usuarioId == ofertaAceptada.UsuarioId)
            return publicacion.UsuarioId;

        throw new InvalidOperationException("No participaste de esta publicación.");
    }

    private async Task<Publicacion> BuscarPublicacionOFallarAsync(int publicacionId)
        => await db.Publicaciones.SingleOrDefaultAsync(p => p.Id == publicacionId)
            ?? throw new KeyNotFoundException("La publicación indicada no existe.");
}
