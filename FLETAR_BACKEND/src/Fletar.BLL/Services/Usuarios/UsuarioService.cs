using Fletar.BLL.Services.Archivos;
using Fletar.DAL;
using Fletar.DAL.Models;
using Fletar.DTO.Usuarios;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;

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

        var estaVerificado = await db.VerificacionesIdentidad
            .AnyAsync(v => v.UsuarioId == id && v.Estado == EstadoVerificacionIdentidad.Aprobada);

        return new UsuarioPublicoResponse
        {
            Id = usuario.Id,
            Nombre = usuario.Nombre,
            FotoUrl = usuario.FotoUrl,
            PromedioCalificacion = puntajes.Count == 0 ? null : puntajes.Average(),
            CantidadCalificaciones = puntajes.Count,
            EstaVerificado = estaVerificado
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

        // Cortar la sesión del todo: el refresh deja de servir (Program valida
        // Activo en cada request, así que el access token tampoco alcanza).
        var tokensVivos = await db.RefreshTokens
            .Where(rt => rt.UsuarioId == id && rt.FechaRevocacion == null)
            .ToListAsync();
        foreach (var token in tokensVivos)
            token.FechaRevocacion = DateTime.UtcNow;

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

    public async Task EliminarCuentaAsync(int id, string? confirmacion)
    {
        if (!string.Equals(confirmacion?.Trim(), "ELIMINAR", StringComparison.Ordinal))
            throw new InvalidOperationException("Escribí ELIMINAR para confirmar la eliminación de la cuenta.");

        var usuario = await BuscarOFallarAsync(id);

        if (usuario.Rol == Rol.Admin)
            throw new InvalidOperationException("Una cuenta administradora no se puede eliminar desde la app.");

        var emailAnonimizado = EmailAnonimizado(id);
        if (!usuario.Activo && usuario.Email == emailAnonimizado)
            return;

        // Publicaciones propias: se cancelan las que siguen abiertas y se borra
        // el contenido personal (direcciones, título, descripción y fotos). La
        // fila se conserva para no romper ofertas/mensajes/calificaciones de
        // otras personas que ya interactuaron con ella.
        var publicaciones = await db.Publicaciones
            .Where(p => p.UsuarioId == id)
            .ToListAsync();
        var publicacionIds = publicaciones.Select(p => p.Id).ToList();

        if (publicacionIds.Count > 0)
        {
            var fotos = await db.PublicacionFotos
                .Where(f => publicacionIds.Contains(f.PublicacionId))
                .ToListAsync();
            foreach (var foto in fotos)
                almacenamiento.Eliminar(CarpetasDeArchivos.Publicaciones, foto.NombreArchivo);
            db.PublicacionFotos.RemoveRange(fotos);

            var reportes = await db.Reportes
                .Where(r => publicacionIds.Contains(r.PublicacionId))
                .ToListAsync();
            db.Reportes.RemoveRange(reportes);
        }

        foreach (var publicacion in publicaciones)
        {
            if (publicacion.Estado != EstadoPublicacion.Completada)
                publicacion.Estado = EstadoPublicacion.Cancelada;

            publicacion.Titulo = "Publicación eliminada";
            publicacion.Descripcion = "Contenido eliminado por el usuario.";
            publicacion.Origen = new Point(0, 0) { SRID = 4326 };
            publicacion.OrigenDireccionTexto = "Dirección eliminada";
            publicacion.Destino = null;
            publicacion.DestinoDireccionTexto = null;
            publicacion.FechaDeseada = null;
        }

        // Ofertas propias: las que no fueron aceptadas se eliminan; la aceptada
        // se conserva como registro de la operación, sin el mensaje personal.
        var ofertas = await db.Ofertas
            .Where(o => o.UsuarioId == id)
            .ToListAsync();
        var ofertasAEliminar = ofertas
            .Where(o => o.Estado != EstadoOferta.Aceptada)
            .ToList();
        var ofertasAEliminarIds = ofertasAEliminar.Select(o => o.Id).ToList();

        foreach (var oferta in ofertas.Where(o => o.Estado == EstadoOferta.Aceptada))
            oferta.Mensaje = null;

        // Mensajes propios + mensajes de ofertas que se eliminan. Se cargan
        // juntos para no intentar borrar dos veces la misma entidad.
        var mensajes = await db.Mensajes
            .Where(m => m.RemitenteId == id || ofertasAEliminarIds.Contains(m.OfertaId))
            .ToListAsync();
        db.Mensajes.RemoveRange(mensajes);
        db.Ofertas.RemoveRange(ofertasAEliminar);

        // Calificaciones y reportes propios: son datos personales y no hacen
        // falta para mantener la integridad de las publicaciones conservadas.
        var calificaciones = await db.Calificaciones
            .Where(c => c.UsuarioQueCalificaId == id || c.UsuarioCalificadoId == id)
            .ToListAsync();
        db.Calificaciones.RemoveRange(calificaciones);

        var reportesPropios = await db.Reportes
            .Where(r => r.UsuarioReportanteId == id)
            .ToListAsync();
        db.Reportes.RemoveRange(reportesPropios);

        // Documentos de identidad: se borran del disco y de la base.
        var verificacion = await db.VerificacionesIdentidad
            .SingleOrDefaultAsync(v => v.UsuarioId == id);
        if (verificacion is not null)
        {
            almacenamiento.Eliminar(
                CarpetasDeArchivos.DocumentosIdentidad, verificacion.NombreArchivoFrente, privado: true);
            almacenamiento.Eliminar(
                CarpetasDeArchivos.DocumentosIdentidad, verificacion.NombreArchivoDorso, privado: true);
            db.VerificacionesIdentidad.Remove(verificacion);
        }

        // Foto de vehículo y datos de contacto/ubicación.
        almacenamiento.Eliminar(CarpetasDeArchivos.Vehiculos, usuario.FotoUrl);
        usuario.Nombre = "Usuario eliminado";
        usuario.Email = emailAnonimizado;
        usuario.Telefono = null;
        usuario.FotoUrl = null;
        usuario.PasswordHash = null;
        usuario.FcmToken = null;
        usuario.UltimaLatitud = null;
        usuario.UltimaLongitud = null;
        usuario.UltimaUbicacionFecha = null;
        usuario.Activo = false;
        usuario.Rol = Rol.Usuario;

        // Cortar todas las sesiones vigentes.
        var ahora = DateTime.UtcNow;
        var tokens = await db.RefreshTokens
            .Where(rt => rt.UsuarioId == id && rt.FechaRevocacion == null)
            .ToListAsync();
        foreach (var token in tokens)
            token.FechaRevocacion = ahora;

        await db.SaveChangesAsync();
    }

    private static string EmailAnonimizado(int id) => $"eliminado-{id}@fletar.invalid";

    private async Task<Usuario> BuscarOFallarAsync(int id)
        => await db.Usuarios.SingleOrDefaultAsync(u => u.Id == id)
            ?? throw new KeyNotFoundException("El usuario indicado no existe.");
}
