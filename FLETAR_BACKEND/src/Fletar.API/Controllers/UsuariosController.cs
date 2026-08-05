using Fletar.BLL.Services.Usuarios;
using Fletar.DTO.Usuarios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Fletar.API.Controllers;

[ApiController]
[Route("api/usuarios")]
public class UsuariosController(IUsuarioService usuarioService) : ControllerBase
{
    // Perfil público de reputación: cualquiera (logueado o no) tiene que poder
    // ver con quién está tratando antes de ofertar/calificar.
    [AllowAnonymous]
    [HttpGet("{id:int}")]
    public async Task<ActionResult<UsuarioPublicoResponse>> ObtenerPorId(int id)
        => Ok(await usuarioService.ObtenerPerfilPublicoAsync(id));
}
