namespace Fletar.DTO.Usuarios;

/// Confirmación explícita para una acción destructiva. La app pide escribir
/// "ELIMINAR"; el backend lo vuelve a validar para que un DELETE accidental
/// (o una llamada directa a la API) no borre una cuenta.
public class EliminarCuentaRequest
{
    public string? Confirmacion { get; set; }
}
