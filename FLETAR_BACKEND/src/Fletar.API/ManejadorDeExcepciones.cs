using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace Fletar.API;

public class ManejadorDeExcepciones(ILogger<ManejadorDeExcepciones> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        logger.LogError(exception, "Excepción no controlada");

        var statusCode = exception switch
        {
            UnauthorizedAccessException => StatusCodes.Status401Unauthorized,
            KeyNotFoundException => StatusCodes.Status404NotFound,
            InvalidOperationException => StatusCodes.Status400BadRequest,
            _ => StatusCodes.Status500InternalServerError
        };

        httpContext.Response.StatusCode = statusCode;

        await httpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = statusCode,
            Title = statusCode == StatusCodes.Status500InternalServerError ? "Error interno" : exception.Message,
            Extensions = { ["traceId"] = httpContext.TraceIdentifier }
        }, cancellationToken);

        return true;
    }
}
