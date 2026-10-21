using System.ComponentModel.DataAnnotations;

namespace Fletar.DTO.Ofertas;

public class OfertaCreateRequest
{
    [Range(typeof(decimal), "0.01", "9999999999.99",
        ErrorMessage = "El monto debe ser mayor a cero.")]
    public decimal Monto { get; set; }

    [StringLength(500, ErrorMessage = "El mensaje no puede superar los 500 caracteres.")]
    public string? Mensaje { get; set; }
}
