using AutoMapper;
using Fletar.DAL;
using Fletar.DAL.Models;
using Fletar.DTO.Ofertas;
using Microsoft.EntityFrameworkCore;

namespace Fletar.BLL.Services.Ofertas;

public class OfertaService(FletarDbContext db, IMapper mapper) : IOfertaService
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

        return mapper.Map<OfertaResponse>(oferta);
    }

    public async Task<IReadOnlyList<OfertaResponse>> ListarPorPublicacionAsync(int publicacionId)
    {
        await BuscarPublicacionOFallarAsync(publicacionId);

        var ofertas = await db.Ofertas
            .Where(o => o.PublicacionId == publicacionId)
            .OrderByDescending(o => o.FechaOferta)
            .ToListAsync();

        return mapper.Map<List<OfertaResponse>>(ofertas);
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

        return mapper.Map<OfertaResponse>(oferta);
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

        return mapper.Map<OfertaResponse>(oferta);
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
    }

    private async Task<Publicacion> BuscarPublicacionOFallarAsync(int publicacionId)
        => await db.Publicaciones.SingleOrDefaultAsync(p => p.Id == publicacionId)
            ?? throw new KeyNotFoundException("La publicación indicada no existe.");

    private async Task<Oferta> BuscarOfertaOFallarAsync(int ofertaId)
        => await db.Ofertas.SingleOrDefaultAsync(o => o.Id == ofertaId)
            ?? throw new KeyNotFoundException("La oferta indicada no existe.");
}
