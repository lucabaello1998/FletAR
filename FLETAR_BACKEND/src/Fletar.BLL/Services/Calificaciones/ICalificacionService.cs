using Fletar.DTO.Calificaciones;

namespace Fletar.BLL.Services.Calificaciones;

public interface ICalificacionService
{
    Task<CalificacionResponse> CrearAsync(int usuarioId, int publicacionId, CalificacionCreateRequest request);
    Task<IReadOnlyList<CalificacionResponse>> ListarPorPublicacionAsync(int publicacionId);
}
