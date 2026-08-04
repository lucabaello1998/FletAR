namespace Fletar.API;

public static class CabecerasSeguridadExtensions
{
    public static IApplicationBuilder UseCabecerasDeSeguridad(this IApplicationBuilder app)
    {
        return app.Use(async (context, next) =>
        {
            context.Response.Headers["X-Content-Type-Options"] = "nosniff";
            context.Response.Headers["X-Frame-Options"] = "DENY";
            context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
            await next();
        });
    }
}
