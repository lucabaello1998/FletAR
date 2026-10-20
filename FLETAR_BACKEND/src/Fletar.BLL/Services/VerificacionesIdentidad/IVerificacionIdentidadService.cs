using Fletar.DTO.VerificacionesIdentidad;
using Microsoft.AspNetCore.Http;

namespace Fletar.BLL.Services.VerificacionesIdentidad;

public interface IVerificacionIdentidadService
{
    /// Crea o actualiza (una fila por usuario, ver VerificacionIdentidad) la
    /// solicitud del usuario logueado con los dos documentos nuevos, y la deja
    /// en Pendiente. Tira InvalidOperationException (400) si ya estaba Aprobada
    /// - no tiene sentido volver a pedir verificación si ya se logró.
    Task<VerificacionIdentidadResponse> SolicitarAsync(int usuarioId, IFormFile frente, IFormFile dorso);

    /// Estado propio. Tira KeyNotFoundException (404) si el usuario nunca pidió
    /// una verificación - "no tengo solicitud" se distingue así de cualquier
    /// estado real (Pendiente/Aprobada/Rechazada).
    Task<VerificacionIdentidadResponse> ObtenerPropiaAsync(int usuarioId);

    /// Listado para el panel admin, opcionalmente filtrado por Estado (mismo
    /// patrón que ReporteService.ListarAsync).
    Task<IReadOnlyList<VerificacionIdentidadAdminResponse>> ListarAdminAsync(string? estado);

    /// Ruta física + Content-Type de uno de los dos documentos de una
    /// solicitud, para que el controller lo sirva con PhysicalFile(). Sólo
    /// llamado detrás de la policy "Admin" (ver AdminController) - no hay
    /// chequeo de "dueño" acá porque ningún endpoint no-admin expone esto.
    Task<(string RutaFisica, string ContentType)> ObtenerDocumentoAsync(int verificacionId, string lado);

    Task AprobarAsync(int verificacionId);
    Task RechazarAsync(int verificacionId, string? comentario);
}
