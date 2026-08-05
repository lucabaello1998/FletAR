using Fletar.DAL;
using Fletar.DAL.Models;
using Fletar.DTO.Admin;
using Microsoft.EntityFrameworkCore;

namespace Fletar.BLL.Services.Admin;

public class AdminService(FletarDbContext db) : IAdminService
{
    public async Task<MetricasResponse> ObtenerMetricasAsync()
    {
        var puntajes = await db.Calificaciones.Select(c => c.Puntaje).ToListAsync();

        return new MetricasResponse
        {
            TotalUsuarios = await db.Usuarios.CountAsync(),
            TotalPublicaciones = await db.Publicaciones.CountAsync(),
            PublicacionesPublicadas = await db.Publicaciones.CountAsync(p => p.Estado == EstadoPublicacion.Publicada),
            PublicacionesOfertaAceptada = await db.Publicaciones.CountAsync(p => p.Estado == EstadoPublicacion.OfertaAceptada),
            PublicacionesEnCurso = await db.Publicaciones.CountAsync(p => p.Estado == EstadoPublicacion.EnCurso),
            PublicacionesCompletadas = await db.Publicaciones.CountAsync(p => p.Estado == EstadoPublicacion.Completada),
            PublicacionesCanceladas = await db.Publicaciones.CountAsync(p => p.Estado == EstadoPublicacion.Cancelada),
            TotalOfertas = await db.Ofertas.CountAsync(),
            PromedioCalificacionGlobal = puntajes.Count == 0 ? null : puntajes.Average(),
            ReportesPendientes = await db.Reportes.CountAsync(r => r.Estado == EstadoReporte.Pendiente)
        };
    }
}
