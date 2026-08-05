using Fletar.DTO.Ofertas;

namespace Fletar.BLL.Services.Ofertas;

public interface IOfertaService
{
    Task<OfertaResponse> CrearAsync(int usuarioId, int publicacionId, OfertaCreateRequest request);
    Task<IReadOnlyList<OfertaResponse>> ListarPorPublicacionAsync(int publicacionId, int usuarioIdActual);
    Task<IReadOnlyList<OfertaResponse>> ListarMiasAsync(int usuarioId);
    Task<OfertaResponse> AceptarAsync(int publicacionId, int ofertaId, int usuarioIdQueAcepta);
    Task<OfertaResponse> RetirarAsync(int ofertaId, int usuarioIdQueRetira);
    Task IniciarAsync(int publicacionId, int usuarioIdDueno);
    Task CompletarAsync(int publicacionId, int usuarioIdDueno);
}
