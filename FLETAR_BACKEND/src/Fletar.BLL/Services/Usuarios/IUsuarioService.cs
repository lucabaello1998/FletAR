using Fletar.DTO.Usuarios;
using Microsoft.AspNetCore.Http;

namespace Fletar.BLL.Services.Usuarios;

public interface IUsuarioService
{
    Task<UsuarioPublicoResponse> ObtenerPerfilPublicoAsync(int id);
    Task<IReadOnlyList<UsuarioAdminResponse>> ListarAdminAsync(int page, int pageSize, string? busqueda);
    Task DesactivarAsync(int id);
    Task ReactivarAsync(int id);
    Task RegistrarFcmTokenAsync(int id, string? token);

    /// Reemplaza la foto de vehículo del usuario logueado (Fase 8) - una sola
    /// por usuario; si ya tenía una, se borra del disco.
    Task<FotoVehiculoResponse> ActualizarFotoVehiculoAsync(int id, IFormFile archivo);
}
