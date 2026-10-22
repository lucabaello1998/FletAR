using System.ComponentModel.DataAnnotations;

namespace Fletar.DTO.Usuarios;

public class RegistrarFcmTokenRequest
{
    /// Token de registro de FCM. Sin tope, un cliente podía mandar un string de
    /// MB que se guardaba en la columna de todos los usuarios.
    [StringLength(4096, ErrorMessage = "El token no puede superar los 4096 caracteres.")]
    public string? Token { get; set; }
}
