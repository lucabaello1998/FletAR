using Fletar.BLL.Services.Ofertas;
using Fletar.DTO.Ofertas;
using Microsoft.AspNetCore.Mvc;

namespace Fletar.API.Controllers;

[ApiController]
[Route("api/publicaciones/{publicacionId:int}/ofertas")]
public class OfertasController(IOfertaService ofertaService) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<OfertaResponse>> Crear(int publicacionId, OfertaCreateRequest request)
        => Ok(await ofertaService.CrearAsync(this.UsuarioIdActual(), publicacionId, request));

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<OfertaResponse>>> Listar(int publicacionId)
        => Ok(await ofertaService.ListarPorPublicacionAsync(publicacionId));

    [HttpPost("{ofertaId:int}/aceptar")]
    public async Task<ActionResult<OfertaResponse>> Aceptar(int publicacionId, int ofertaId)
        => Ok(await ofertaService.AceptarAsync(publicacionId, ofertaId, this.UsuarioIdActual()));

    [HttpPost("{ofertaId:int}/retirar")]
    public async Task<ActionResult<OfertaResponse>> Retirar(int publicacionId, int ofertaId)
        => Ok(await ofertaService.RetirarAsync(ofertaId, this.UsuarioIdActual()));
}
