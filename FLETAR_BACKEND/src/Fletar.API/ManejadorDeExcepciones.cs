using Fletar.BLL.Exceptions;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Fletar.API;

public class ManejadorDeExcepciones(ILogger<ManejadorDeExcepciones> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var statusCode = exception switch
        {
            // "No sos el dueño" no es "no estás autenticado": con 401 el cliente
            // intentaba refrescar el token en loop y mostraba "sesión expirada".
            AccesoDenegadoException => StatusCodes.Status403Forbidden,
            UnauthorizedAccessException => StatusCodes.Status401Unauthorized,
            KeyNotFoundException => StatusCodes.Status404NotFound,
            InvalidOperationException => StatusCodes.Status400BadRequest,
            // Carreras contra los índices únicos (email repetido, calificación
            // doble, etc.) antes terminaban en 500 "Error interno".
            DbUpdateException => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status500InternalServerError
        };

        if (statusCode >= StatusCodes.Status500InternalServerError)
        {
            logger.LogError(exception, "Excepción no controlada");
        }
        else
        {
            logger.LogWarning(exception, "Excepción de negocio ({StatusCode})", statusCode);
        }

        httpContext.Response.StatusCode = statusCode;

        var title = statusCode switch
        {
            StatusCodes.Status500InternalServerError => "Error interno",
            StatusCodes.Status409Conflict => "La operación chocó con un dato existente. Probá de nuevo.",
            _ => exception.Message
        };

        await httpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = statusCode,
            Title = title,
            Extensions = { ["traceId"] = httpContext.TraceIdentifier }
        }, cancellationToken);

        return true;
    }
}
