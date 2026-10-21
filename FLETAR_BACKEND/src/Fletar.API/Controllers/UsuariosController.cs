using Fletar.BLL.Services.Usuarios;
using Fletar.BLL.Services.VerificacionesIdentidad;
using Fletar.DTO.Usuarios;
using Fletar.DTO.VerificacionesIdentidad;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Fletar.API.Controllers;

[ApiController]
[Route("api/usuarios")]
public class UsuariosController(IUsuarioService usuarioService, IVerificacionIdentidadService verificacionService)
    : ControllerBase
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

    /// Eliminación de cuenta desde la app (requisito de Google Play). El
    /// cliente manda `{"confirmacion":"ELIMINAR"}`; el service anonimiza la
    /// cuenta y borra documentos/fotos antes de cortar las sesiones.
    [HttpDelete("me")]
    public async Task<IActionResult> EliminarCuenta(EliminarCuentaRequest request)
    {
        await usuarioService.EliminarCuentaAsync(this.UsuarioIdActual(), request.Confirmacion);
        return NoContent();
    }

    // Foto de vehículo (Fase 8) - señal de confianza para cuando este usuario
    // oferta como fletero. Una sola por usuario, siempre sobre el propio
    // usuario logueado (nunca se recibe un id en la ruta) - reemplaza la
    // anterior si tenía.
    [HttpPut("me/foto-vehiculo")]
    public async Task<ActionResult<FotoVehiculoResponse>> ActualizarFotoVehiculo(IFormFile archivo)
        => Ok(await usuarioService.ActualizarFotoVehiculoAsync(this.UsuarioIdActual(), archivo));

    // Verificación de identidad (Fase 9) - documentos sensibles (frente+dorso),
    // guardados siempre "privados" (ver IAlmacenamientoArchivosService): a
    // diferencia de la foto de vehículo de arriba, éstos NUNCA quedan
    // alcanzables por una URL pública. Sólo el propio usuario puede subir/ver
    // su estado acá; sólo un Admin puede ver los archivos o aprobar/rechazar
    // (AdminController). "frente"/"dorso" son los nombres de campo del
    // multipart - el binding de IFormFile los toma por nombre de parámetro.
    [HttpPost("me/verificacion-identidad")]
    public async Task<ActionResult<VerificacionIdentidadResponse>> SolicitarVerificacionIdentidad(
        IFormFile frente, IFormFile dorso)
        => Ok(await verificacionService.SolicitarAsync(this.UsuarioIdActual(), frente, dorso));

    [HttpGet("me/verificacion-identidad")]
    public async Task<ActionResult<VerificacionIdentidadResponse>> ObtenerVerificacionIdentidadPropia()
        => Ok(await verificacionService.ObtenerPropiaAsync(this.UsuarioIdActual()));
}
