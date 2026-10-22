using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Fletar.DAL;
using Fletar.DAL.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Fletar.Tests;

/// Regresión: el POST de una publicación con `fechaDeseada` sin offset (lo que
/// mandaba Flutter con `DateTime.toIso8601String()` sobre una fecha local de
/// `showDatePicker`) llegaba a Npgsql como DateTime Kind=Unspecified y Postgres
/// respondía 500 al escribir una columna `timestamp with time zone`. La fecha
/// se normaliza a UTC en el service, así que con la base en memoria alcanza con
/// verificar que lo guardado queda en Kind=Utc y que el request no falla.
public class FechaDeseadaTests : IClassFixture<CuentaDesactivadaTests.Fabrica>
{
    private readonly CuentaDesactivadaTests.Fabrica _factory;

    public FechaDeseadaTests(CuentaDesactivadaTests.Fabrica factory) => _factory = factory;

    [Theory]
    [InlineData("2026-10-25T00:00:00.000")]
    [InlineData("2026-10-25T00:00:00.000Z")]
    [InlineData("2026-10-25T03:00:00.000-03:00")]
    public async Task Crear_publicacion_con_fecha_deseada_guarda_la_fecha_en_utc(string fecha)
    {
        var client = await CrearUsuarioConTokenAsync();
        var categoriaId = await AsegurarCategoriaAsync();

        // Se manda el string tal cual para controlar el offset exacto del JSON.
        var cuerpoRequest =
            $$"""{"titulo":"Flete con fecha deseada","descripcion":"Prueba de regresion de fecha deseada","categoriaCargaId":{{categoriaId}},"latitud":-34.610981,"longitud":-58.433791,"origenDireccionTexto":"Otamendi 500, CABA","fechaDeseada":"{{fecha}}"}""";

        var response = await client.PostAsync(
            "/api/publicaciones",
            new StringContent(cuerpoRequest, Encoding.UTF8, "application/json"));

        var cuerpo = await response.Content.ReadAsStringAsync();
        Assert.True(
            response.StatusCode == HttpStatusCode.OK,
            $"Esperaba 200 y llegó {(int)response.StatusCode}: {cuerpo}");

        using var json = JsonDocument.Parse(cuerpo);
        var publicacionId = json.RootElement.GetProperty("id").GetInt32();

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<FletarDbContext>();
        var publicacion = await db.Publicaciones.SingleAsync(p => p.Id == publicacionId);

        Assert.NotNull(publicacion.FechaDeseada);
        Assert.Equal(DateTimeKind.Utc, publicacion.FechaDeseada!.Value.Kind);
        Assert.Equal(FechaEsperadaUtc(fecha), publicacion.FechaDeseada.Value);
    }

    /// Con offset/Z, el instante es el que declara el cliente. Sin offset, la
    /// API interpreta la fecha como UTC (no como hora local del servidor).
    private static DateTime FechaEsperadaUtc(string fecha)
    {
        var tieneOffset = fecha.EndsWith('Z') || fecha.Contains('+') || fecha.LastIndexOf('-') > 10;
        return tieneOffset
            ? DateTimeOffset.Parse(fecha).UtcDateTime
            : DateTime.SpecifyKind(DateTime.Parse(fecha), DateTimeKind.Utc);
    }

    private async Task<HttpClient> CrearUsuarioConTokenAsync()
    {
        var email = $"fecha-{Guid.NewGuid():N}@fletar.test";
        var client = _factory.CreateClient();
        var registro = await client.PostAsJsonAsync("/api/auth/register", new
        {
            nombre = "Fecha deseada",
            email,
            password = "Password1!"
        });
        registro.EnsureSuccessStatusCode();

        var sesion = await registro.Content.ReadFromJsonAsync<JsonElement>();
        var accessToken = sesion.GetProperty("accessToken").GetString()!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        return client;
    }

    private async Task<int> AsegurarCategoriaAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<FletarDbContext>();

        var existente = await db.CategoriasCarga.FirstOrDefaultAsync();
        if (existente is not null) return existente.Id;

        var categoria = new CategoriaCarga { Nombre = "Categoría de prueba", Activa = true };
        db.CategoriasCarga.Add(categoria);
        await db.SaveChangesAsync();
        return categoria.Id;
    }
}
