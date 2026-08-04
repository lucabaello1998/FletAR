using Fletar.DTO.Publicaciones;

namespace Fletar.BLL.Services.Publicaciones;

public interface IPublicacionService
{
    Task<PublicacionResponse> CrearAsync(int usuarioId, PublicacionCreateRequest request);
    Task<IReadOnlyList<PublicacionResponse>> ListarAsync(int page, int pageSize, string? estado, int? usuarioId = null);
    Task<PublicacionResponse> ObtenerPorIdAsync(int id);
    Task<IReadOnlyList<PublicacionResponse>> ListarCercanasAsync(double lat, double lng, double radioKm);
    Task<PublicacionResponse> EditarAsync(int id, int usuarioId, PublicacionUpdateRequest request);
    Task CancelarAsync(int id, int usuarioId);
    Task<IReadOnlyList<CategoriaCargaResponse>> ListarCategoriasAsync();
    Task<IReadOnlyList<TipoVehiculoResponse>> ListarTiposVehiculoAsync();
}
