using System.Net;
using System.Net.Http.Json;
using Fletar.DTO.Auth;

namespace Fletar.Tests;

public class RefreshTokenTests : IClassFixture<CuentaDesactivadaTests.Fabrica>
{
    private readonly CuentaDesactivadaTests.Fabrica _factory;

    public RefreshTokenTests(CuentaDesactivadaTests.Fabrica factory) => _factory = factory;

    [Fact]
    public async Task Reusar_un_refresh_token_revoca_toda_la_familia()
    {
        var (client, login) = await RegistrarAsync();

        var primerRefresh = await client.PostAsJsonAsync("/api/auth/refresh", new
        {
            refreshToken = login.RefreshToken
        });
        Assert.Equal(HttpStatusCode.OK, primerRefresh.StatusCode);

        var nuevo = await primerRefresh.Content.ReadFromJsonAsync<RefreshResponse>();
        Assert.NotNull(nuevo);

        var reuso = await client.PostAsJsonAsync("/api/auth/refresh", new
        {
            refreshToken = login.RefreshToken
        });
        Assert.Equal(HttpStatusCode.Unauthorized, reuso.StatusCode);

        // El token que había salido del primer refresh también queda revocado:
        // el reuso no invalida sólo el token viejo, corta la familia entera.
        var despuesDelReuso = await client.PostAsJsonAsync("/api/auth/refresh", new
        {
            refreshToken = nuevo!.RefreshToken
        });
        Assert.Equal(HttpStatusCode.Unauthorized, despuesDelReuso.StatusCode);
    }

    [Fact]
    public async Task Dos_refreshes_simultaneos_con_el_mismo_token_solo_emiten_uno()
    {
        var (client, login) = await RegistrarAsync();

        var respuestas = await Task.WhenAll(
            client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = login.RefreshToken }),
            client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = login.RefreshToken }));

        Assert.Equal(1, respuestas.Count(r => r.StatusCode == HttpStatusCode.OK));
        Assert.Equal(1, respuestas.Count(r => r.StatusCode == HttpStatusCode.Unauthorized));
    }

    private async Task<(HttpClient Client, LoginResponse Login)> RegistrarAsync()
    {
        var client = _factory.CreateClient();
        var email = $"refresh-{Guid.NewGuid():N}@test.local";

        var registro = await client.PostAsJsonAsync("/api/auth/register", new
        {
            nombre = "Refresh Test",
            email,
            password = "Password123!"
        });
        registro.EnsureSuccessStatusCode();

        var login = await registro.Content.ReadFromJsonAsync<LoginResponse>();
        Assert.NotNull(login);

        return (client, login!);
    }
}
