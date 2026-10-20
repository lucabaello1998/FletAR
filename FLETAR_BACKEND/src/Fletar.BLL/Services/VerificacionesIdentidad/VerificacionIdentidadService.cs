using AutoMapper;
using Fletar.BLL.Services.Archivos;
using Fletar.DAL;
using Fletar.DAL.Models;
using Fletar.DTO.VerificacionesIdentidad;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace Fletar.BLL.Services.VerificacionesIdentidad;

/// Verificación de identidad (Fase 9): documentos sensibles, guardados siempre
/// con privado=true (ver IAlmacenamientoArchivosService/CarpetasDeArchivos) -
/// a diferencia de las fotos de la Fase 8, nunca quedan detrás de una URL
/// pública. Este service es el único punto que arma la ruta física de un
/// documento para servirlo (ObtenerDocumentoAsync), y sólo AdminController lo
/// expone, detrás de la policy "Admin".
public class VerificacionIdentidadService(
    FletarDbContext db, IMapper mapper, IAlmacenamientoArchivosService almacenamiento)
    : IVerificacionIdentidadService
{
    public async Task<VerificacionIdentidadResponse> SolicitarAsync(int usuarioId, IFormFile frente, IFormFile dorso)
    {
        var existente = await db.VerificacionesIdentidad.SingleOrDefaultAsync(v => v.UsuarioId == usuarioId);
        if (existente is { Estado: EstadoVerificacionIdentidad.Aprobada })
            throw new InvalidOperationException("Tu identidad ya está verificada.");

        // Se validan/guardan los dos archivos ANTES de tocar la fila - si el
        // segundo (dorso) falla la validación, no queremos haber pisado ya el
        // NombreArchivoFrente de una solicitud previa con el nuevo frente.
        var nombreFrente = await almacenamiento.GuardarImagenAsync(frente, CarpetasDeArchivos.DocumentosIdentidad, privado: true);
        var nombreDorso = await almacenamiento.GuardarImagenAsync(dorso, CarpetasDeArchivos.DocumentosIdentidad, privado: true);

        if (existente is null)
        {
            existente = new VerificacionIdentidad
            {
                UsuarioId = usuarioId,
                FechaSolicitud = DateTime.UtcNow
            };
            db.VerificacionesIdentidad.Add(existente);
        }
        else
        {
            // Reemplaza los documentos anteriores (si tenía, de una solicitud
            // Rechazada) - borra del disco los viejos antes de pisar el nombre,
            // mismo criterio que UsuarioService.ActualizarFotoVehiculoAsync.
            almacenamiento.Eliminar(CarpetasDeArchivos.DocumentosIdentidad, existente.NombreArchivoFrente, privado: true);
            almacenamiento.Eliminar(CarpetasDeArchivos.DocumentosIdentidad, existente.NombreArchivoDorso, privado: true);
            existente.FechaSolicitud = DateTime.UtcNow;
        }

        existente.NombreArchivoFrente = nombreFrente;
        existente.NombreArchivoDorso = nombreDorso;
        existente.Estado = EstadoVerificacionIdentidad.Pendiente;
        existente.FechaRevision = null;
        existente.ComentarioAdmin = null;

        await db.SaveChangesAsync();

        return mapper.Map<VerificacionIdentidadResponse>(existente);
    }

    public async Task<VerificacionIdentidadResponse> ObtenerPropiaAsync(int usuarioId)
    {
        var verificacion = await db.VerificacionesIdentidad.SingleOrDefaultAsync(v => v.UsuarioId == usuarioId)
            ?? throw new KeyNotFoundException("Todavía no pediste una verificación de identidad.");

        return mapper.Map<VerificacionIdentidadResponse>(verificacion);
    }

    public async Task<IReadOnlyList<VerificacionIdentidadAdminResponse>> ListarAdminAsync(string? estado)
    {
        var query = db.VerificacionesIdentidad.AsQueryable();

        if (!string.IsNullOrWhiteSpace(estado))
        {
            if (!Enum.TryParse<EstadoVerificacionIdentidad>(estado, ignoreCase: true, out var estadoFiltro))
                throw new InvalidOperationException($"El estado '{estado}' no es válido.");
            query = query.Where(v => v.Estado == estadoFiltro);
        }

        var verificaciones = await query.OrderByDescending(v => v.FechaSolicitud).ToListAsync();
        return await MapearVariasAsync(verificaciones);
    }

    public async Task<(string RutaFisica, string ContentType)> ObtenerDocumentoAsync(int verificacionId, string lado)
    {
        var verificacion = await BuscarOFallarAsync(verificacionId);

        var nombreArchivo = lado.ToLowerInvariant() switch
        {
            "frente" => verificacion.NombreArchivoFrente,
            "dorso" => verificacion.NombreArchivoDorso,
            _ => throw new InvalidOperationException("El lado del documento debe ser 'frente' o 'dorso'.")
        };

        var rutaFisica = almacenamiento.ObtenerRutaFisica(CarpetasDeArchivos.DocumentosIdentidad, nombreArchivo, privado: true);
        if (!File.Exists(rutaFisica))
            throw new KeyNotFoundException("El documento indicado no existe.");

        return (rutaFisica, ContentTypePorExtension(Path.GetExtension(rutaFisica)));
    }

    public async Task AprobarAsync(int verificacionId)
    {
        var verificacion = await BuscarOFallarAsync(verificacionId);
        verificacion.Estado = EstadoVerificacionIdentidad.Aprobada;
        verificacion.FechaRevision = DateTime.UtcNow;
        verificacion.ComentarioAdmin = null; // limpia un comentario de un rechazo anterior, si lo hubiera
        await db.SaveChangesAsync();
    }

    public async Task RechazarAsync(int verificacionId, string? comentario)
    {
        var verificacion = await BuscarOFallarAsync(verificacionId);
        verificacion.Estado = EstadoVerificacionIdentidad.Rechazada;
        verificacion.FechaRevision = DateTime.UtcNow;
        verificacion.ComentarioAdmin = string.IsNullOrWhiteSpace(comentario) ? null : comentario.Trim();
        await db.SaveChangesAsync();
    }

    private async Task<VerificacionIdentidad> BuscarOFallarAsync(int id)
        => await db.VerificacionesIdentidad.SingleOrDefaultAsync(v => v.Id == id)
            ?? throw new KeyNotFoundException("La solicitud de verificación indicada no existe.");

    private static string ContentTypePorExtension(string extension) => extension.ToLowerInvariant() switch
    {
        ".jpg" or ".jpeg" => "image/jpeg",
        ".png" => "image/png",
        ".webp" => "image/webp",
        _ => "application/octet-stream"
    };

    // UsuarioNombre/UsuarioEmail se denormalizan acá (no hay navegación de EF en
    // los models) con un único lookup por lote - mismo criterio que
    // ReporteService.MapearVariosAsync.
    private async Task<IReadOnlyList<VerificacionIdentidadAdminResponse>> MapearVariasAsync(
        List<VerificacionIdentidad> verificaciones)
    {
        var responses = mapper.Map<List<VerificacionIdentidadAdminResponse>>(verificaciones);

        var usuarioIds = verificaciones.Select(v => v.UsuarioId).Distinct().ToList();
        var usuariosPorId = await db.Usuarios
            .Where(u => usuarioIds.Contains(u.Id))
            .Select(u => new { u.Id, u.Nombre, u.Email })
            .ToDictionaryAsync(u => u.Id);

        foreach (var response in responses)
        {
            if (!usuariosPorId.TryGetValue(response.UsuarioId, out var usuario))
                continue;
            response.UsuarioNombre = usuario.Nombre;
            response.UsuarioEmail = usuario.Email;
        }

        return responses;
    }
}
