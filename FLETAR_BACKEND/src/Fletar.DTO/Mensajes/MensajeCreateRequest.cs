using System.ComponentModel.DataAnnotations;

namespace Fletar.DTO.Mensajes;

public class MensajeCreateRequest
{
    [Required(ErrorMessage = "El mensaje no puede estar vacío.")]
    [StringLength(2000, MinimumLength = 1, ErrorMessage = "El mensaje debe tener entre 1 y 2000 caracteres.")]
    public string Texto { get; set; } = null!;
}
