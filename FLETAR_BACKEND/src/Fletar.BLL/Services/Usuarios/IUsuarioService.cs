using Fletar.DTO.Usuarios;

namespace Fletar.BLL.Services.Usuarios;

public interface IUsuarioService
{
    Task<UsuarioPublicoResponse> ObtenerPerfilPublicoAsync(int id);
    Task<IReadOnlyList<UsuarioAdminResponse>> ListarAdminAsync(int page, int pageSize, string? busqueda);
    Task DesactivarAsync(int id);
    Task ReactivarAsync(int id);
}
