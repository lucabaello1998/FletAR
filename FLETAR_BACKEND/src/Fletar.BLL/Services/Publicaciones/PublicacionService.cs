using AutoMapper;
using Fletar.BLL.Services.Archivos;
using Fletar.DAL;
using Fletar.DAL.Models;
using Fletar.DTO.Publicaciones;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;

namespace Fletar.BLL.Services.Publicaciones;

public class PublicacionService(FletarDbContext db, IMapper mapper, IAlmacenamientoArchivosService almacenamiento)
    : IPublicacionService
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

        return await MapearConNombreAsync(publicacion);
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

        return await MapearConNombresAsync(publicaciones);
    }

    public async Task<PublicacionResponse> ObtenerPorIdAsync(int id)
    {
        var publicacion = await BuscarOFallarAsync(id);
        return await MapearConNombreAsync(publicacion);
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

        return await MapearConNombresAsync(publicaciones);
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

        return await MapearConNombreAsync(publicacion);
    }

    public async Task CancelarAsync(int id, int usuarioId)
    {
        var publicacion = await BuscarOFallarAsync(id);

        ValidarDuenioYEstadoEditable(publicacion, usuarioId);

        publicacion.Estado = EstadoPublicacion.Cancelada;
        await db.SaveChangesAsync();
    }

    // Moderación: el admin puede cancelar cualquier publicación abusiva/reportada,
    // sin el chequeo de dueño (a propósito distinto de CancelarAsync) y desde
    // cualquier estado no terminal - la autorización real ya la resuelve la policy
    // "Admin" en el controller, este método no vuelve a chequear el rol.
    public async Task CancelarComoAdminAsync(int id)
    {
        var publicacion = await BuscarOFallarAsync(id);

        if (publicacion.Estado is EstadoPublicacion.Completada or EstadoPublicacion.Cancelada)
            throw new InvalidOperationException("La publicación ya está en un estado final.");

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

    // Fotos de carga (Fase 8) - el dueño puede agregar/quitar en cualquier
    // estado de la publicación (a diferencia de EditarAsync/CancelarAsync,
    // que sólo valen en Publicada): no hay una razón de negocio para impedir
    // sumar/sacar fotos mientras el flete ya está en curso o completado,
    // así que a propósito no se llama ValidarDuenioYEstadoEditable acá.
    public async Task<PublicacionFotoResponse> AgregarFotoAsync(int publicacionId, int usuarioId, IFormFile archivo)
    {
        var publicacion = await BuscarOFallarAsync(publicacionId);
        ValidarDuenio(publicacion, usuarioId, "agregar fotos a");

        var cantidadActual = await db.PublicacionFotos.CountAsync(f => f.PublicacionId == publicacionId);
        if (cantidadActual >= PublicacionFoto.CantidadMaximaFotos)
            throw new InvalidOperationException(
                $"Una publicación no puede tener más de {PublicacionFoto.CantidadMaximaFotos} fotos.");

        var nombreArchivo = await almacenamiento.GuardarImagenAsync(archivo, CarpetasDeArchivos.Publicaciones);

        var foto = new PublicacionFoto
        {
            PublicacionId = publicacionId,
            NombreArchivo = nombreArchivo,
            Orden = cantidadActual,
            FechaSubida = DateTime.UtcNow
        };

        db.PublicacionFotos.Add(foto);
        await db.SaveChangesAsync();

        return MapearFoto(foto);
    }

    public async Task EliminarFotoAsync(int publicacionId, int fotoId, int usuarioId)
    {
        var publicacion = await BuscarOFallarAsync(publicacionId);
        ValidarDuenio(publicacion, usuarioId, "borrar fotos de");

        var foto = await db.PublicacionFotos.SingleOrDefaultAsync(f => f.Id == fotoId && f.PublicacionId == publicacionId)
            ?? throw new KeyNotFoundException("La foto indicada no existe en esta publicación.");

        // Borra el archivo del disco primero: si esto tirara, preferimos que
        // el registro siga existiendo (huérfano pero reintentable) antes que
        // borrar el registro y dejar un archivo huérfano en disco sin ningún
        // rastro en la base para encontrarlo después.
        almacenamiento.Eliminar(CarpetasDeArchivos.Publicaciones, foto.NombreArchivo);

        db.PublicacionFotos.Remove(foto);
        await db.SaveChangesAsync();
    }

    private async Task<Publicacion> BuscarOFallarAsync(int id)
        => await db.Publicaciones.SingleOrDefaultAsync(p => p.Id == id)
            ?? throw new KeyNotFoundException("La publicación indicada no existe.");

    // UsuarioNombre se denormaliza acá (no viene de una navegación de EF: los models
    // de DAL no tienen navigation properties) con un único lookup por lote sobre los
    // usuarios de la página ya recortada, nunca una query por fila. Fotos (Fase 8)
    // sigue el mismo criterio.
    private async Task<PublicacionResponse> MapearConNombreAsync(Publicacion publicacion)
    {
        var response = mapper.Map<PublicacionResponse>(publicacion);
        response.UsuarioNombre = await db.Usuarios
            .Where(u => u.Id == publicacion.UsuarioId)
            .Select(u => u.Nombre)
            .SingleOrDefaultAsync() ?? string.Empty;

        var fotos = await db.PublicacionFotos
            .Where(f => f.PublicacionId == publicacion.Id)
            .OrderBy(f => f.Orden)
            .ToListAsync();
        response.Fotos = fotos.Select(MapearFoto).ToList();

        return response;
    }

    private async Task<IReadOnlyList<PublicacionResponse>> MapearConNombresAsync(List<Publicacion> publicaciones)
    {
        var responses = mapper.Map<List<PublicacionResponse>>(publicaciones);

        var publicacionIds = publicaciones.Select(p => p.Id).ToList();

        var usuarioIds = publicaciones.Select(p => p.UsuarioId).Distinct().ToList();
        var nombresPorId = await db.Usuarios
            .Where(u => usuarioIds.Contains(u.Id))
            .Select(u => new { u.Id, u.Nombre })
            .ToDictionaryAsync(u => u.Id, u => u.Nombre);

        // Un único lookup por lote sobre todas las fotos de la página ya
        // recortada, agrupado en memoria - nunca una query por publicación.
        var fotosPorPublicacion = (await db.PublicacionFotos
                .Where(f => publicacionIds.Contains(f.PublicacionId))
                .OrderBy(f => f.Orden)
                .ToListAsync())
            .GroupBy(f => f.PublicacionId)
            .ToDictionary(g => g.Key, g => g.Select(MapearFoto).ToList());

        foreach (var response in responses)
        {
            response.UsuarioNombre = nombresPorId.GetValueOrDefault(response.UsuarioId, string.Empty);
            response.Fotos = fotosPorPublicacion.GetValueOrDefault(response.Id, new List<PublicacionFotoResponse>());
        }

        return responses;
    }

    private PublicacionFotoResponse MapearFoto(PublicacionFoto foto)
    {
        var response = mapper.Map<PublicacionFotoResponse>(foto);
        response.Url = almacenamiento.ConstruirUrlRelativa(CarpetasDeArchivos.Publicaciones, foto.NombreArchivo);
        return response;
    }

    private static void ValidarDuenio(Publicacion publicacion, int usuarioId, string accion)
    {
        if (publicacion.UsuarioId != usuarioId)
            throw new UnauthorizedAccessException($"No tenés permiso para {accion} esta publicación.");
    }

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
