using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Fletar.DAL;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Fletar.Tests;

/// La eliminación de cuenta que exige Google Play: la cuenta queda inactiva y
/// anonimizada, la contraseña y los datos personales se borran, y las sesiones
/// vigentes se revocan. Se prueba con la base en memoria.
public class EliminarCuentaTests : IClassFixture<CuentaDesactivadaTests.Fabrica>
{
    private readonly CuentaDesactivadaTests.Fabrica _factory;

    public EliminarCuentaTests(CuentaDesactivadaTests.Fabrica factory) => _factory = factory;

    [Fact]
    public async Task Eliminar_cuenta_anonimiza_y_revoca_sesiones()
    {
        var email = $"eliminar-{Guid.NewGuid():N}@fletar.test";
        const string password = "Password1!";

        var client = _factory.CreateClient();
        var registro = await client.PostAsJsonAsync("/api/auth/register", new
        {
            nombre = "Cuenta a eliminar",
            email,
            password,
            telefono = "+54 11 0000-0000"
        });
        registro.EnsureSuccessStatusCode();

        var sesion = await registro.Content.ReadFromJsonAsync<JsonElement>();
        var accessToken = sesion.GetProperty("accessToken").GetString()!;
        var refreshToken = sesion.GetProperty("refreshToken").GetString()!;
        var usuarioId = sesion.GetProperty("usuario").GetProperty("id").GetInt32();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        using var deleteRequest = new HttpRequestMessage(HttpMethod.Delete, "/api/usuarios/me")
        {
            Content = JsonContent.Create(new { confirmacion = "ELIMINAR" })
        };
        var deleteResponse = await client.SendAsync(deleteRequest);
        Assert.Equal(HttpStatusCode.NoContent, deleteResponse.StatusCode);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<FletarDbContext>();
            var usuario = await db.Usuarios.SingleAsync(u => u.Id == usuarioId);
            Assert.False(usuario.Activo);
            Assert.Equal($"eliminado-{usuarioId}@fletar.invalid", usuario.Email);
            Assert.Equal("Usuario eliminado", usuario.Nombre);
            Assert.Null(usuario.Telefono);
            Assert.Null(usuario.PasswordHash);

            var tokensVivos = await db.RefreshTokens
                .CountAsync(rt => rt.UsuarioId == usuarioId && rt.FechaRevocacion == null);
            Assert.Equal(0, tokensVivos);
        }

        var loginConCredencialesViejas = await _factory.CreateClient()
            .PostAsJsonAsync("/api/auth/login", new { email, password });
        Assert.Equal(HttpStatusCode.Unauthorized, loginConCredencialesViejas.StatusCode);

        var refreshViejo = await _factory.CreateClient()
            .PostAsJsonAsync("/api/auth/refresh", new { refreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, refreshViejo.StatusCode);
    }
}
