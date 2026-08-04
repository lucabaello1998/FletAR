using Fletar.BLL.Helpers;
using Fletar.BLL.Services.Auth;
using Fletar.BLL.Settings;
using Fletar.DAL;
using Microsoft.Extensions.DependencyInjection;

namespace Fletar.BLL;

public static class DependencyInjection
{
    public static IServiceCollection AddBusinessLayer(
        this IServiceCollection services, string connectionString, JwtSettings jwtSettings, GoogleSettings googleSettings)
    {
        services.AddDataLayer(connectionString);
        services.AddSingleton(jwtSettings);
        services.AddSingleton(googleSettings);
        services.AddAutoMapper(_ => { }, typeof(DependencyInjection).Assembly);

        services.AddScoped<IJwtTokenGenerator, JwtTokenGenerator>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IUsuarioDevSeeder, UsuarioDevSeeder>();

        return services;
    }
}
