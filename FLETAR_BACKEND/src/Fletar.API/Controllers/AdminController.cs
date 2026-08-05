using Fletar.BLL.Services.Admin;
using Fletar.BLL.Services.Publicaciones;
using Fletar.BLL.Services.Reportes;
using Fletar.BLL.Services.Usuarios;
using Fletar.DTO.Admin;
using Fletar.DTO.Reportes;
using Fletar.DTO.Usuarios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Fletar.API.Controllers;

// La policy "Admin" va a nivel de controller (no endpoint por endpoint): a
// diferencia del resto de la API, donde el FallbackPolicy alcanza porque el caso
// por defecto es permisivo, acá el caso por defecto tiene que ser restrictivo -
// olvidarse esto en un controller nuevo bajo /api/admin lo dejaría abierto a
// cualquier usuario logueado. Ver CLAUDE.md, sección Autenticación.
[ApiController]
[Route("api/admin")]
[Authorize(Policy = "Admin")]
public class AdminController(
    IReporteService reporteService,
    IPublicacionService publicacionService,
    IUsuarioService usuarioService,
    IAdminService adminService) : ControllerBase
{
    [HttpGet("reportes")]
    public async Task<ActionResult<IReadOnlyList<ReporteResponse>>> ListarReportes([FromQuery] string? estado)
        => Ok(await reporteService.ListarAsync(estado));

    [HttpPost("reportes/{id:int}/revisar")]
    public async Task<IActionResult> RevisarReporte(int id)
    {
        await reporteService.RevisarAsync(id);
        return NoContent();
    }

    [HttpPost("reportes/{id:int}/descartar")]
    public async Task<IActionResult> DescartarReporte(int id)
    {
        await reporteService.DescartarAsync(id);
        return NoContent();
    }

    [HttpPost("publicaciones/{id:int}/cancelar")]
    public async Task<IActionResult> CancelarPublicacion(int id)
    {
        await publicacionService.CancelarComoAdminAsync(id);
        return NoContent();
    }

    [HttpGet("usuarios")]
    public async Task<ActionResult<IReadOnlyList<UsuarioAdminResponse>>> ListarUsuarios(
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20, [FromQuery] string? busqueda = null)
        => Ok(await usuarioService.ListarAdminAsync(page, pageSize, busqueda));

    [HttpPost("usuarios/{id:int}/desactivar")]
    public async Task<IActionResult> DesactivarUsuario(int id)
    {
        await usuarioService.DesactivarAsync(id);
        return NoContent();
    }

    [HttpPost("usuarios/{id:int}/reactivar")]
    public async Task<IActionResult> ReactivarUsuario(int id)
    {
        await usuarioService.ReactivarAsync(id);
        return NoContent();
    }

    [HttpGet("metricas")]
    public async Task<ActionResult<MetricasResponse>> ObtenerMetricas()
        => Ok(await adminService.ObtenerMetricasAsync());
}
