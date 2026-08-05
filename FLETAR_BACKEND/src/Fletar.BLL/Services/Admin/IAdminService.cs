using Fletar.DTO.Admin;

namespace Fletar.BLL.Services.Admin;

public interface IAdminService
{
    Task<MetricasResponse> ObtenerMetricasAsync();
}
