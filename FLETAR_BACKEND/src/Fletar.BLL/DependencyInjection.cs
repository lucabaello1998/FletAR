using Fletar.BLL.Helpers;
using Fletar.BLL.Services.Admin;
using Fletar.BLL.Services.Auth;
using Fletar.BLL.Services.Calificaciones;
using Fletar.BLL.Services.Mensajes;
using Fletar.BLL.Services.Notificaciones;
using Fletar.BLL.Services.Ofertas;
using Fletar.BLL.Services.Publicaciones;
using Fletar.BLL.Services.Reportes;
using Fletar.BLL.Services.Usuarios;
using Fletar.BLL.Settings;
using Fletar.DAL;
using Microsoft.Extensions.DependencyInjection;

namespace Fletar.BLL;

public static class DependencyInjection
{
    public static IServiceCollection AddBusinessLayer(
        this IServiceCollection services, string connectionString, JwtSettings jwtSettings,
        GoogleSettings googleSettings, FirebaseSettings firebaseSettings)
    {
        services.AddDataLayer(connectionString);
        services.AddSingleton(jwtSettings);
        services.AddSingleton(googleSettings);
        services.AddSingleton(firebaseSettings);
        services.AddAutoMapper(_ => { }, typeof(DependencyInjection).Assembly);

        services.AddScoped<IJwtTokenGenerator, JwtTokenGenerator>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IUsuarioDevSeeder, UsuarioDevSeeder>();
        services.AddScoped<IPublicacionService, PublicacionService>();
        services.AddScoped<IOfertaService, OfertaService>();
        services.AddScoped<ICalificacionService, CalificacionService>();
        services.AddScoped<IUsuarioService, UsuarioService>();
        services.AddScoped<IReporteService, ReporteService>();
        services.AddScoped<IAdminService, AdminService>();
        services.AddScoped<IFcmSenderService, FcmSenderService>();
        services.AddScoped<IMensajeService, MensajeService>();

        return services;
    }
}
