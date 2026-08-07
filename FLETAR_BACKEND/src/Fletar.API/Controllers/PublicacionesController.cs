using Fletar.BLL.Services.Ofertas;
using Fletar.BLL.Services.Publicaciones;
using Fletar.DTO.Publicaciones;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Fletar.API.Controllers;

[ApiController]
[Route("api/publicaciones")]
public class PublicacionesController(IPublicacionService publicacionService, IOfertaService ofertaService) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<PublicacionResponse>> Crear(PublicacionCreateRequest request)
        => Ok(await publicacionService.CrearAsync(this.UsuarioIdActual(), request));

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<PublicacionResponse>>> Listar(
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20, [FromQuery] string? estado = null,
        [FromQuery] bool soloMias = false)
        => Ok(await publicacionService.ListarAsync(page, pageSize, estado, soloMias ? this.UsuarioIdActual() : null));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<PublicacionResponse>> ObtenerPorId(int id)
        => Ok(await publicacionService.ObtenerPorIdAsync(id));

    [HttpGet("cercanas")]
    public async Task<ActionResult<IReadOnlyList<PublicacionResponse>>> ListarCercanas(
        [FromQuery] double lat, [FromQuery] double lng, [FromQuery] double radioKm)
        => Ok(await publicacionService.ListarCercanasAsync(lat, lng, radioKm));

    [HttpPut("{id:int}")]
    public async Task<ActionResult<PublicacionResponse>> Editar(int id, PublicacionUpdateRequest request)
        => Ok(await publicacionService.EditarAsync(id, this.UsuarioIdActual(), request));

    [HttpPost("{id:int}/cancelar")]
    public async Task<IActionResult> Cancelar(int id)
    {
        await publicacionService.CancelarAsync(id, this.UsuarioIdActual());
        return NoContent();
    }

    [HttpPost("{id:int}/iniciar")]
    public async Task<IActionResult> Iniciar(int id)
    {
        await ofertaService.IniciarAsync(id, this.UsuarioIdActual());
        return NoContent();
    }

    [HttpPost("{id:int}/completar")]
    public async Task<IActionResult> Completar(int id)
    {
        await ofertaService.CompletarAsync(id, this.UsuarioIdActual());
        return NoContent();
    }

    [HttpGet("categorias")]
    public async Task<ActionResult<IReadOnlyList<CategoriaCargaResponse>>> ListarCategorias()
        => Ok(await publicacionService.ListarCategoriasAsync());

    [HttpGet("tipos-vehiculo")]
    public async Task<ActionResult<IReadOnlyList<TipoVehiculoResponse>>> ListarTiposVehiculo()
        => Ok(await publicacionService.ListarTiposVehiculoAsync());

    // Fotos de carga (Fase 8) - públicas en la lectura (van incluidas en
    // PublicacionResponse.Fotos, ver GET .../{id}), pero escribir (agregar o
    // borrar) es sólo del dueño - la autorización real vive en
    // PublicacionService, no acá.
    [HttpPost("{id:int}/fotos")]
    public async Task<ActionResult<PublicacionFotoResponse>> AgregarFoto(int id, IFormFile archivo)
        => Ok(await publicacionService.AgregarFotoAsync(id, this.UsuarioIdActual(), archivo));

    [HttpDelete("{id:int}/fotos/{fotoId:int}")]
    public async Task<IActionResult> EliminarFoto(int id, int fotoId)
    {
        await publicacionService.EliminarFotoAsync(id, fotoId, this.UsuarioIdActual());
        return NoContent();
    }
}
