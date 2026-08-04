using AutoMapper;
using Fletar.DAL;
using Fletar.DAL.Models;
using Fletar.DTO.Publicaciones;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;

namespace Fletar.BLL.Services.Publicaciones;

public class PublicacionService(FletarDbContext db, IMapper mapper) : IPublicacionService
{
    private const int PageSizePorDefecto = 20;

    public async Task<PublicacionResponse> CrearAsync(int usuarioId, PublicacionCreateRequest request)
    {
        await ValidarCategoriaYTipoAsync(request.CategoriaCargaId, request.TipoVehiculoSugeridoId);

        var publicacion = new Publicacion
        {
            UsuarioId = usuarioId,
            Titulo = request.Titulo,
            Descripcion = request.Descripcion,
            CategoriaCargaId = request.CategoriaCargaId,
            TipoVehiculoSugeridoId = request.TipoVehiculoSugeridoId,
            Origen = CrearPunto(request.Latitud, request.Longitud),
            OrigenDireccionTexto = request.OrigenDireccionTexto,
            Destino = CrearPuntoOpcional(request.DestinoLatitud, request.DestinoLongitud),
            DestinoDireccionTexto = request.DestinoDireccionTexto,
            FechaDeseada = request.FechaDeseada,
            FechaPublicacion = DateTime.UtcNow,
            Estado = EstadoPublicacion.Publicada
        };

        db.Publicaciones.Add(publicacion);
        await db.SaveChangesAsync();

        return mapper.Map<PublicacionResponse>(publicacion);
    }

    public async Task<IReadOnlyList<PublicacionResponse>> ListarAsync(int page, int pageSize, string? estado, int? usuarioId = null)
    {
        if (page < 1) page = 1;
        if (pageSize < 1) pageSize = PageSizePorDefecto;

        var estadoFiltro = ParsearEstado(estado);

        var query = db.Publicaciones.AsQueryable();

        if (usuarioId is not null)
            query = query.Where(p => p.UsuarioId == usuarioId);

        if (estadoFiltro is not null)
        {
            query = query.Where(p => p.Estado == estadoFiltro);
        }
        else if (usuarioId is null)
        {
            // Listado público (sin usuarioId): sólo lo que sigue abierto a
            // ofertas. El dueño mirando sus propias publicaciones (usuarioId
            // presente) tiene que poder verlas en cualquier estado, si no
            // una publicación desaparece de su pantalla apenas deja de estar
            // Publicada.
            query = query.Where(p => p.Estado == EstadoPublicacion.Publicada);
        }

        var publicaciones = await query
            .OrderByDescending(p => p.FechaPublicacion)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return mapper.Map<List<PublicacionResponse>>(publicaciones);
    }

    public async Task<PublicacionResponse> ObtenerPorIdAsync(int id)
    {
        var publicacion = await BuscarOFallarAsync(id);
        return mapper.Map<PublicacionResponse>(publicacion);
    }

    public async Task<IReadOnlyList<PublicacionResponse>> ListarCercanasAsync(double lat, double lng, double radioKm)
    {
        var puntoBusqueda = new Point(lng, lat) { SRID = 4326 };
        var radioMetros = radioKm * 1000;

        var publicaciones = await db.Publicaciones
            .Where(p => p.Estado == EstadoPublicacion.Publicada)
            .Where(p => p.Origen.IsWithinDistance(puntoBusqueda, radioMetros))
            .OrderBy(p => p.Origen.Distance(puntoBusqueda))
            .ToListAsync();

        return mapper.Map<List<PublicacionResponse>>(publicaciones);
    }

    public async Task<PublicacionResponse> EditarAsync(int id, int usuarioId, PublicacionUpdateRequest request)
    {
        var publicacion = await BuscarOFallarAsync(id);

        ValidarDuenioYEstadoEditable(publicacion, usuarioId);
        await ValidarCategoriaYTipoAsync(request.CategoriaCargaId, request.TipoVehiculoSugeridoId);

        publicacion.Titulo = request.Titulo;
        publicacion.Descripcion = request.Descripcion;
        publicacion.CategoriaCargaId = request.CategoriaCargaId;
        publicacion.TipoVehiculoSugeridoId = request.TipoVehiculoSugeridoId;
        publicacion.Origen = CrearPunto(request.Latitud, request.Longitud);
        publicacion.OrigenDireccionTexto = request.OrigenDireccionTexto;
        publicacion.Destino = CrearPuntoOpcional(request.DestinoLatitud, request.DestinoLongitud);
        publicacion.DestinoDireccionTexto = request.DestinoDireccionTexto;
        publicacion.FechaDeseada = request.FechaDeseada;

        await db.SaveChangesAsync();

        return mapper.Map<PublicacionResponse>(publicacion);
    }

    public async Task CancelarAsync(int id, int usuarioId)
    {
        var publicacion = await BuscarOFallarAsync(id);

        ValidarDuenioYEstadoEditable(publicacion, usuarioId);

        publicacion.Estado = EstadoPublicacion.Cancelada;
        await db.SaveChangesAsync();
    }

    public async Task<IReadOnlyList<CategoriaCargaResponse>> ListarCategoriasAsync()
    {
        var categorias = await db.CategoriasCarga
            .Where(c => c.Activa)
            .OrderBy(c => c.Nombre)
            .ToListAsync();

        return mapper.Map<List<CategoriaCargaResponse>>(categorias);
    }

    public async Task<IReadOnlyList<TipoVehiculoResponse>> ListarTiposVehiculoAsync()
    {
        var tipos = await db.TiposVehiculo
            .Where(t => t.Activo)
            .OrderBy(t => t.Nombre)
            .ToListAsync();

        return mapper.Map<List<TipoVehiculoResponse>>(tipos);
    }

    private async Task<Publicacion> BuscarOFallarAsync(int id)
        => await db.Publicaciones.SingleOrDefaultAsync(p => p.Id == id)
            ?? throw new KeyNotFoundException("La publicación indicada no existe.");

    private static void ValidarDuenioYEstadoEditable(Publicacion publicacion, int usuarioId)
    {
        if (publicacion.UsuarioId != usuarioId)
            throw new UnauthorizedAccessException("No tenés permiso para modificar esta publicación.");

        if (publicacion.Estado != EstadoPublicacion.Publicada)
            throw new InvalidOperationException("Sólo se puede modificar una publicación en estado Publicada.");
    }

    private async Task ValidarCategoriaYTipoAsync(int categoriaCargaId, int? tipoVehiculoSugeridoId)
    {
        var categoriaValida = await db.CategoriasCarga.AnyAsync(c => c.Id == categoriaCargaId && c.Activa);
        if (!categoriaValida)
            throw new InvalidOperationException("La categoría de carga indicada no existe o no está activa.");

        if (tipoVehiculoSugeridoId is not null)
        {
            var tipoValido = await db.TiposVehiculo.AnyAsync(t => t.Id == tipoVehiculoSugeridoId && t.Activo);
            if (!tipoValido)
                throw new InvalidOperationException("El tipo de vehículo sugerido indicado no existe o no está activo.");
        }
    }

    private static EstadoPublicacion? ParsearEstado(string? estado)
    {
        if (string.IsNullOrWhiteSpace(estado))
            return null;

        if (!Enum.TryParse<EstadoPublicacion>(estado, ignoreCase: true, out var resultado))
            throw new InvalidOperationException($"El estado '{estado}' no es válido.");

        return resultado;
    }

    private static Point CrearPunto(double latitud, double longitud)
        => new(longitud, latitud) { SRID = 4326 };

    private static Point? CrearPuntoOpcional(double? latitud, double? longitud)
    {
        if (latitud is null && longitud is null)
            return null;

        if (latitud is null || longitud is null)
            throw new InvalidOperationException("DestinoLatitud y DestinoLongitud deben indicarse juntos.");

        return CrearPunto(latitud.Value, longitud.Value);
    }
}
