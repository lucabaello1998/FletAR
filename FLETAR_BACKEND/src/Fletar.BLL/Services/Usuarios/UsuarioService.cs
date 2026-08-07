using Fletar.BLL.Services.Archivos;
using Fletar.DAL;
using Fletar.DAL.Models;
using Fletar.DTO.Usuarios;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace Fletar.BLL.Services.Usuarios;

public class UsuarioService(FletarDbContext db, IAlmacenamientoArchivosService almacenamiento) : IUsuarioService
{
    public async Task<UsuarioPublicoResponse> ObtenerPerfilPublicoAsync(int id)
    {
        var usuario = await db.Usuarios.SingleOrDefaultAsync(u => u.Id == id)
            ?? throw new KeyNotFoundException("El usuario indicado no existe.");

        var puntajes = await db.Calificaciones
            .Where(c => c.UsuarioCalificadoId == id)
            .Select(c => c.Puntaje)
            .ToListAsync();

        return new UsuarioPublicoResponse
        {
            Id = usuario.Id,
            Nombre = usuario.Nombre,
            FotoUrl = usuario.FotoUrl,
            PromedioCalificacion = puntajes.Count == 0 ? null : puntajes.Average(),
            CantidadCalificaciones = puntajes.Count
        };
    }

    private const int PageSizePorDefecto = 20;

    public async Task<IReadOnlyList<UsuarioAdminResponse>> ListarAdminAsync(int page, int pageSize, string? busqueda)
    {
        if (page < 1) page = 1;
        if (pageSize < 1) pageSize = PageSizePorDefecto;

        var query = db.Usuarios.AsQueryable();

        if (!string.IsNullOrWhiteSpace(busqueda))
        {
            // ILIKE vía EF.Functions.Like + LOWER en los dos lados: Postgres no
            // ignora mayúsculas por defecto en LIKE (a diferencia de la collation
            // de SQL Server que sí lo hace), así que hay que normalizar a mano.
            var patron = $"%{busqueda.ToLower()}%";
            query = query.Where(u =>
                EF.Functions.Like(u.Nombre.ToLower(), patron) || EF.Functions.Like(u.Email.ToLower(), patron));
        }

        var usuarios = await query
            .OrderBy(u => u.Nombre)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        var usuarioIds = usuarios.Select(u => u.Id).ToList();
        var calificacionesPorUsuario = await db.Calificaciones
            .Where(c => usuarioIds.Contains(c.UsuarioCalificadoId))
            .GroupBy(c => c.UsuarioCalificadoId)
            .Select(g => new { UsuarioId = g.Key, Promedio = g.Average(c => c.Puntaje), Cantidad = g.Count() })
            .ToDictionaryAsync(g => g.UsuarioId);

        return usuarios.Select(u =>
        {
            calificacionesPorUsuario.TryGetValue(u.Id, out var agregado);
            return new UsuarioAdminResponse
            {
                Id = u.Id,
                Nombre = u.Nombre,
                Email = u.Email,
                Telefono = u.Telefono,
                Rol = u.Rol.ToString(),
                Activo = u.Activo,
                FechaRegistro = u.FechaRegistro,
                PromedioCalificacion = agregado?.Promedio,
                CantidadCalificaciones = agregado?.Cantidad ?? 0
            };
        }).ToList();
    }

    public async Task DesactivarAsync(int id)
    {
        var usuario = await BuscarOFallarAsync(id);
        usuario.Activo = false;
        await db.SaveChangesAsync();
    }

    public async Task ReactivarAsync(int id)
    {
        var usuario = await BuscarOFallarAsync(id);
        usuario.Activo = true;
        await db.SaveChangesAsync();
    }

    public async Task RegistrarFcmTokenAsync(int id, string? token)
    {
        var usuario = await BuscarOFallarAsync(id);
        usuario.FcmToken = string.IsNullOrWhiteSpace(token) ? null : token;
        await db.SaveChangesAsync();
    }

    public async Task<FotoVehiculoResponse> ActualizarFotoVehiculoAsync(int id, IFormFile archivo)
    {
        var usuario = await BuscarOFallarAsync(id);

        var nombreNuevo = await almacenamiento.GuardarImagenAsync(archivo, CarpetasDeArchivos.Vehiculos);

        // Reemplaza la foto anterior (si tenía) - una sola foto de vehículo
        // por usuario, no una galería como PublicacionFoto. FotoUrl guarda la
        // URL relativa completa (p. ej. "/uploads/vehiculos/{guid}.jpg"), pero
        // Eliminar toma sólo el nombre de archivo (Path.GetFileName la limpia
        // igual, así que pasarle la URL entera funciona sin parsing extra).
        almacenamiento.Eliminar(CarpetasDeArchivos.Vehiculos, usuario.FotoUrl);

        usuario.FotoUrl = almacenamiento.ConstruirUrlRelativa(CarpetasDeArchivos.Vehiculos, nombreNuevo);
        await db.SaveChangesAsync();

        return new FotoVehiculoResponse { Url = usuario.FotoUrl };
    }

    private async Task<Usuario> BuscarOFallarAsync(int id)
        => await db.Usuarios.SingleOrDefaultAsync(u => u.Id == id)
            ?? throw new KeyNotFoundException("El usuario indicado no existe.");
}
