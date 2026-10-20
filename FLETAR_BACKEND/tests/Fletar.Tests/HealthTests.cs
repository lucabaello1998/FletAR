using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Fletar.Tests;

// Estos dos tests no necesitan base de datos: con el entorno "Testing" el host
// no corre el seeder de desarrollo (que es el que intentaba conectarse a
// Postgres y hacia fallar la suite sin infraestructura levantada).
public class HealthTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public HealthTests(WebApplicationFactory<Program> factory)
    {
        var app = factory.WithWebHostBuilder(builder => builder.UseEnvironment("Testing"));
        _client = app.CreateClient();
    }

    [Fact]
    public async Task Health_devuelve_ok()
    {
        var response = await _client.GetAsync("/api/health");

        Assert.True(response.IsSuccessStatusCode);
    }

    [Fact]
    public async Task Endpoint_sin_token_devuelve_401_por_FallbackPolicy()
    {
        var response = await _client.GetAsync("/api/no-existe");

        Assert.Equal(System.Net.HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
