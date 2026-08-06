using Fletar.DTO.Mensajes;

namespace Fletar.BLL.Services.Mensajes;

public interface IMensajeService
{
    Task<IReadOnlyList<MensajeResponse>> ListarAsync(int ofertaId, int usuarioIdActual);
    Task<MensajeResponse> EnviarAsync(int ofertaId, int usuarioIdActual, MensajeCreateRequest request);
}
