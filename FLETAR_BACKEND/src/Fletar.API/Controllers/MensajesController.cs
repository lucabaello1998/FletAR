using Fletar.BLL.Services.Mensajes;
using Fletar.DTO.Mensajes;
using Microsoft.AspNetCore.Mvc;

namespace Fletar.API.Controllers;

/// Historial de chat de una Oferta puntual (Fase 7) - la entrega en tiempo real
/// va por ChatHub (/hubs/chat), estos endpoints son para el historial (al abrir
/// la pantalla) y para mandar un mensaje nuevo (que además de persistirlo,
/// dispara la notificación al grupo de SignalR y el push a la otra parte,
/// ver MensajeService.EnviarAsync). Ruta a nivel de oferta, no anidada bajo
/// publicaciones, porque la autorización depende de las dos partes de la
/// oferta (dueño de la publicación u oferente), no sólo del dueño.
[ApiController]
[Route("api/ofertas/{ofertaId:int}/mensajes")]
public class MensajesController(IMensajeService mensajeService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<MensajeResponse>>> Listar(int ofertaId)
        => Ok(await mensajeService.ListarAsync(ofertaId, this.UsuarioIdActual()));

    [HttpPost]
    public async Task<ActionResult<MensajeResponse>> Enviar(int ofertaId, MensajeCreateRequest request)
        => Ok(await mensajeService.EnviarAsync(ofertaId, this.UsuarioIdActual(), request));
}
