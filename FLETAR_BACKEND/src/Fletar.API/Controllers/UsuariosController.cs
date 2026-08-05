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

    // Alcance mobile únicamente (ver CLAUDE.md, Stack): el cliente manda null/vacío
    // para des-registrar el token al desloguearse en ese dispositivo.
    [HttpPut("me/fcm-token")]
    public async Task<IActionResult> RegistrarFcmToken(RegistrarFcmTokenRequest request)
    {
        await usuarioService.RegistrarFcmTokenAsync(this.UsuarioIdActual(), request.Token);
        return NoContent();
    }
}
