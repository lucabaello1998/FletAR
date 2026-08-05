using AutoMapper;
using Fletar.DAL;
using Fletar.DAL.Models;
using Fletar.DTO.Reportes;
using Microsoft.EntityFrameworkCore;

namespace Fletar.BLL.Services.Reportes;

public class ReporteService(FletarDbContext db, IMapper mapper) : IReporteService
{
    public async Task<ReporteResponse> CrearAsync(int usuarioId, int publicacionId, ReporteCreateRequest request)
    {
        var publicacion = await db.Publicaciones.SingleOrDefaultAsync(p => p.Id == publicacionId)
            ?? throw new KeyNotFoundException("La publicación indicada no existe.");

        var yaTieneReportePendiente = await db.Reportes.AnyAsync(r =>
            r.PublicacionId == publicacionId && r.UsuarioReportanteId == usuarioId && r.Estado == EstadoReporte.Pendiente);
        if (yaTieneReportePendiente)
            throw new InvalidOperationException("Ya reportaste esta publicación; tu reporte está pendiente de revisión.");

        var reporte = new Reporte
        {
            PublicacionId = publicacionId,
            UsuarioReportanteId = usuarioId,
            Motivo = request.Motivo,
            Comentario = request.Comentario,
            FechaReporte = DateTime.UtcNow,
            Estado = EstadoReporte.Pendiente
        };

        db.Reportes.Add(reporte);
        await db.SaveChangesAsync();

        return await MapearAsync(reporte, publicacion.Titulo);
    }

    public async Task<IReadOnlyList<ReporteResponse>> ListarAsync(string? estado)
    {
        var query = db.Reportes.AsQueryable();

        if (!string.IsNullOrWhiteSpace(estado))
        {
            if (!Enum.TryParse<EstadoReporte>(estado, ignoreCase: true, out var estadoFiltro))
                throw new InvalidOperationException($"El estado '{estado}' no es válido.");
            query = query.Where(r => r.Estado == estadoFiltro);
        }

        var reportes = await query.OrderByDescending(r => r.FechaReporte).ToListAsync();
        return await MapearVariosAsync(reportes);
    }

    public async Task RevisarAsync(int reporteId)
    {
        var reporte = await BuscarOFallarAsync(reporteId);
        reporte.Estado = EstadoReporte.Revisado;
        await db.SaveChangesAsync();
    }

    public async Task DescartarAsync(int reporteId)
    {
        var reporte = await BuscarOFallarAsync(reporteId);
        reporte.Estado = EstadoReporte.Descartado;
        await db.SaveChangesAsync();
    }

    private async Task<Reporte> BuscarOFallarAsync(int reporteId)
        => await db.Reportes.SingleOrDefaultAsync(r => r.Id == reporteId)
            ?? throw new KeyNotFoundException("El reporte indicado no existe.");

    private async Task<ReporteResponse> MapearAsync(Reporte reporte, string publicacionTitulo)
    {
        var response = mapper.Map<ReporteResponse>(reporte);
        response.PublicacionTitulo = publicacionTitulo;
        response.UsuarioReportanteNombre = await db.Usuarios
            .Where(u => u.Id == reporte.UsuarioReportanteId)
            .Select(u => u.Nombre)
            .SingleOrDefaultAsync() ?? string.Empty;
        return response;
    }

    private async Task<IReadOnlyList<ReporteResponse>> MapearVariosAsync(List<Reporte> reportes)
    {
        var responses = mapper.Map<List<ReporteResponse>>(reportes);

        var usuarioIds = reportes.Select(r => r.UsuarioReportanteId).Distinct().ToList();
        var nombresPorId = await db.Usuarios
            .Where(u => usuarioIds.Contains(u.Id))
            .Select(u => new { u.Id, u.Nombre })
            .ToDictionaryAsync(u => u.Id, u => u.Nombre);

        var publicacionIds = reportes.Select(r => r.PublicacionId).Distinct().ToList();
        var titulosPorId = await db.Publicaciones
            .Where(p => publicacionIds.Contains(p.Id))
            .Select(p => new { p.Id, p.Titulo })
            .ToDictionaryAsync(p => p.Id, p => p.Titulo);

        foreach (var response in responses)
        {
            response.UsuarioReportanteNombre = nombresPorId.GetValueOrDefault(response.UsuarioReportanteId, string.Empty);
            response.PublicacionTitulo = titulosPorId.GetValueOrDefault(response.PublicacionId, string.Empty);
        }

        return responses;
    }
}
