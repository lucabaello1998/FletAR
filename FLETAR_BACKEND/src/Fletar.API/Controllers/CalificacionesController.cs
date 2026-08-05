using Fletar.BLL.Services.Calificaciones;
using Fletar.DTO.Calificaciones;
using Microsoft.AspNetCore.Mvc;

namespace Fletar.API.Controllers;

[ApiController]
[Route("api/publicaciones/{publicacionId:int}/calificaciones")]
public class CalificacionesController(ICalificacionService calificacionService) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<CalificacionResponse>> Crear(int publicacionId, CalificacionCreateRequest request)
        => Ok(await calificacionService.CrearAsync(this.UsuarioIdActual(), publicacionId, request));

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<CalificacionResponse>>> Listar(int publicacionId)
        => Ok(await calificacionService.ListarPorPublicacionAsync(publicacionId));
}
