using Fletar.BLL.Services.Reportes;
using Fletar.DTO.Reportes;
using Microsoft.AspNetCore.Mvc;

namespace Fletar.API.Controllers;

[ApiController]
[Route("api/publicaciones/{publicacionId:int}/reportes")]
public class ReportesController(IReporteService reporteService) : ControllerBase
{
    // Cualquier usuario autenticado puede reportar - la revisión/moderación
    // (listar, revisar, descartar) es exclusiva del admin, ver AdminController.
    [HttpPost]
    public async Task<ActionResult<ReporteResponse>> Crear(int publicacionId, ReporteCreateRequest request)
        => Ok(await reporteService.CrearAsync(this.UsuarioIdActual(), publicacionId, request));
}
