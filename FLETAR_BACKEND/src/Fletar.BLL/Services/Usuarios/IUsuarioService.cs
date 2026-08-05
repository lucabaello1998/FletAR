using Fletar.DTO.Usuarios;

namespace Fletar.BLL.Services.Usuarios;

public interface IUsuarioService
{
    Task<UsuarioPublicoResponse> ObtenerPerfilPublicoAsync(int id);
}
