using Fletar.DAL;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Fletar.API.Controllers;

[ApiController]
[Route("api/health")]
public class HealthController(FletarDbContext db) : ControllerBase
{
    /// Liveness: responde mientras el proceso esté vivo, sin depender de nada
    /// externo. Es la que usa el healthcheck de Railway.
    [AllowAnonymous]
    [HttpGet]
    public IActionResult Get() => Ok(new { status = "ok" });

    /// Readiness: verifica que la base conteste. La liveness sola podía devolver
    /// "ok" con Postgres caído, y ahí toda request autenticada falla (el evento
    /// OnTokenValidated consulta `Activo` en cada request).
    [AllowAnonymous]
    [HttpGet("ready")]
    public async Task<IActionResult> Ready(CancellationToken cancellationToken)
    {
        try
        {
            if (await db.Database.CanConnectAsync(cancellationToken))
                return Ok(new { status = "ok", dependencia = "base de datos" });
        }
        catch (Exception)
        {
            // Sin detalle: el estado de la base no es información pública.
        }

        return StatusCode(StatusCodes.Status503ServiceUnavailable,
            new { status = "degraded", dependencia = "base de datos" });
    }
}
