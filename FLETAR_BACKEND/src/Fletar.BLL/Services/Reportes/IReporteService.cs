using Fletar.DTO.Reportes;

namespace Fletar.BLL.Services.Reportes;

public interface IReporteService
{
    Task<ReporteResponse> CrearAsync(int usuarioId, int publicacionId, ReporteCreateRequest request);
    Task<IReadOnlyList<ReporteResponse>> ListarAsync(string? estado);
    Task RevisarAsync(int reporteId);
    Task DescartarAsync(int reporteId);
}
