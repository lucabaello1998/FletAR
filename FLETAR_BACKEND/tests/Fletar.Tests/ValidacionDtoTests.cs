using System.ComponentModel.DataAnnotations;
using Fletar.DTO.Mensajes;
using Fletar.DTO.Ofertas;
using Fletar.DTO.Publicaciones;

namespace Fletar.Tests;

public class ValidacionDtoTests
{
    [Fact]
    public void Oferta_con_monto_cero_es_invalida()
    {
        var request = new OfertaCreateRequest { Monto = 0, Mensaje = "Hola" };

        var ok = Validator.TryValidateObject(
            request,
            new ValidationContext(request),
            new List<ValidationResult>(),
            validateAllProperties: true);

        Assert.False(ok);
    }

    [Fact]
    public void Oferta_con_monto_positivo_y_mensaje_corto_es_valida()
    {
        var request = new OfertaCreateRequest { Monto = 1500, Mensaje = "Puedo hoy" };

        var ok = Validator.TryValidateObject(
            request,
            new ValidationContext(request),
            new List<ValidationResult>(),
            validateAllProperties: true);

        Assert.True(ok);
    }

    [Fact]
    public void Publicacion_con_latitud_fuera_de_rango_es_invalida()
    {
        var request = PublicacionValida();
        request.Latitud = 91;

        var ok = Validator.TryValidateObject(
            request,
            new ValidationContext(request),
            new List<ValidationResult>(),
            validateAllProperties: true);

        Assert.False(ok);
    }

    [Fact]
    public void Publicacion_sin_titulo_es_invalida()
    {
        var request = PublicacionValida();
        request.Titulo = "";

        var ok = Validator.TryValidateObject(
            request,
            new ValidationContext(request),
            new List<ValidationResult>(),
            validateAllProperties: true);

        Assert.False(ok);
    }

    [Fact]
    public void Publicacion_valida_pasa_las_anotaciones()
    {
        var request = PublicacionValida();

        var ok = Validator.TryValidateObject(
            request,
            new ValidationContext(request),
            new List<ValidationResult>(),
            validateAllProperties: true);

        Assert.True(ok);
    }

    [Fact]
    public void Mensaje_vacio_es_invalido()
    {
        var request = new MensajeCreateRequest { Texto = "" };

        var ok = Validator.TryValidateObject(
            request,
            new ValidationContext(request),
            new List<ValidationResult>(),
            validateAllProperties: true);

        Assert.False(ok);
    }

    private static PublicacionCreateRequest PublicacionValida() => new()
    {
        Titulo = "Mudanza chica",
        Descripcion = "Muebles de un ambiente, sin piano.",
        CategoriaCargaId = 1,
        Latitud = -34.6,
        Longitud = -58.4,
        OrigenDireccionTexto = "Av. Rivadavia 1234"
    };
}
