using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Fletar.BLL.Helpers;
using Fletar.DAL;
using Fletar.DAL.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Fletar.Tests;

/// Desactivar una cuenta tiene que cortar la sesión en el acto, no cuando
/// venza el access token (15 min): el filtro de JWT consulta `Activo` en cada
/// request y el refresh revoca la familia entera. Se prueba con la base en
/// memoria, sin Postgres.
public class CuentaDesactivadaTests : IClassFixture<CuentaDesactivadaTests.Fabrica>
{
    private readonly Fabrica _factory;

    public CuentaDesactivadaTests(Fabrica factory) => _factory = factory;

    [Fact]
    public async Task Un_usuario_desactivado_deja_de_poder_usar_su_access_token()
    {
        var (usuarioId, token) = await CrearUsuarioConTokenAsync();

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Endpoint protegido (el perfil público es AllowAnonymous, no sirve acá).
        var conCuentaActiva = await client.PutAsJsonAsync("/api/usuarios/me/fcm-token", new { token = "token-de-prueba" });
        Assert.NotEqual(HttpStatusCode.Unauthorized, conCuentaActiva.StatusCode);

        await CambiarActivoAsync(usuarioId, false);

        var conCuentaDesactivada = await client.PutAsJsonAsync("/api/usuarios/me/fcm-token", new { token = "token-de-prueba" });
        Assert.Equal(HttpStatusCode.Unauthorized, conCuentaDesactivada.StatusCode);
    }

    [Fact]
    public async Task Un_usuario_desactivado_no_puede_refrescar()
    {
        var (usuarioId, _) = await CrearUsuarioConTokenAsync();
        var refreshCrudo = await CrearRefreshTokenAsync(usuarioId);
        await CambiarActivoAsync(usuarioId, false);

        var client = _factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = refreshCrudo });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private async Task<(int UsuarioId, string Token)> CrearUsuarioConTokenAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<FletarDbContext>();
        var jwt = scope.ServiceProvider.GetRequiredService<Fletar.BLL.Helpers.IJwtTokenGenerator>();

        var usuario = new Usuario
        {
            Nombre = "Cuenta de prueba",
            Email = $"prueba-{Guid.NewGuid():N}@fletar.test",
            Rol = Rol.Usuario,
            FechaRegistro = DateTime.UtcNow,
            Activo = true
        };
        db.Usuarios.Add(usuario);
        await db.SaveChangesAsync();

        var (token, _) = jwt.GenerarAccessToken(usuario);
        return (usuario.Id, token);
    }

    private async Task<string> CrearRefreshTokenAsync(int usuarioId)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<FletarDbContext>();

        var crudo = RefreshTokenHasher.GenerarTokenAleatorio();
        db.RefreshTokens.Add(new RefreshToken
        {
            Id = Guid.NewGuid(),
            UsuarioId = usuarioId,
            FamiliaId = Guid.NewGuid(),
            TokenHash = RefreshTokenHasher.Hash(crudo),
            FechaCreacion = DateTime.UtcNow,
            FechaExpiracion = DateTime.UtcNow.AddDays(1)
        });
        await db.SaveChangesAsync();
        return crudo;
    }

    private async Task CambiarActivoAsync(int usuarioId, bool activo)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<FletarDbContext>();
        var usuario = await db.Usuarios.SingleAsync(u => u.Id == usuarioId);
        usuario.Activo = activo;
        await db.SaveChangesAsync();
    }

    public class Fabrica : WebApplicationFactory<Program>
    {
        private readonly string _nombreBase = $"fletar-test-{Guid.NewGuid():N}";

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<DbContextOptions<FletarDbContext>>();
                services.AddDbContext<FletarDbContext>(options => options.UseInMemoryDatabase(_nombreBase));
            });
        }
    }
}
