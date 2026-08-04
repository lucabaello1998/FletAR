using Microsoft.AspNetCore.Mvc.Testing;

namespace Fletar.Tests;

public class HealthTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task Health_devuelve_ok()
    {
        var client = factory.CreateClient();

        var response = await client.GetAsync("/api/health");

        Assert.True(response.IsSuccessStatusCode);
    }

    [Fact]
    public async Task Endpoint_sin_token_devuelve_401_por_FallbackPolicy()
    {
        var client = factory.CreateClient();

        var response = await client.GetAsync("/api/no-existe");

        Assert.Equal(System.Net.HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
