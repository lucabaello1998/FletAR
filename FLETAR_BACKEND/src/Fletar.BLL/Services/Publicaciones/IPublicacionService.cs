using Fletar.DTO.Publicaciones;
using Microsoft.AspNetCore.Http;

namespace Fletar.BLL.Services.Publicaciones;

public interface IPublicacionService
{
    Task<PublicacionResponse> CrearAsync(int usuarioId, PublicacionCreateRequest request);
    Task<IReadOnlyList<PublicacionResponse>> ListarAsync(int page, int pageSize, string? estado, int? usuarioId = null);
    Task<PublicacionResponse> ObtenerPorIdAsync(int id);
    Task<IReadOnlyList<PublicacionResponse>> ListarCercanasAsync(double lat, double lng, double radioKm);
    Task<PublicacionResponse> EditarAsync(int id, int usuarioId, PublicacionUpdateRequest request);
    Task CancelarAsync(int id, int usuarioId);
    Task CancelarComoAdminAsync(int id);
    Task<IReadOnlyList<CategoriaCargaResponse>> ListarCategoriasAsync();
    Task<IReadOnlyList<TipoVehiculoResponse>> ListarTiposVehiculoAsync();

    /// Agrega una foto de carga a la publicación - sólo el dueño (Fase 8).
    Task<PublicacionFotoResponse> AgregarFotoAsync(int publicacionId, int usuarioId, IFormFile archivo);

    /// Borra una foto de carga (registro + archivo en disco) - sólo el dueño (Fase 8).
    Task EliminarFotoAsync(int publicacionId, int fotoId, int usuarioId);
}
