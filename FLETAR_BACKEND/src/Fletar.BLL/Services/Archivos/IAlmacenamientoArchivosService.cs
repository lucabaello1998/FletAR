using Microsoft.AspNetCore.Http;

namespace Fletar.BLL.Services.Archivos;

public interface IAlmacenamientoArchivosService
{
    /// Valida y guarda una imagen en disco bajo la subcarpeta indicada (ver
    /// CarpetasDeArchivos). Devuelve el nombre de archivo generado (GUID +
    /// extensión) - nunca el nombre original que mandó el cliente. Tira
    /// InvalidOperationException (400 vía ManejadorDeExcepciones) si el
    /// archivo no es una imagen válida o supera el tamaño máximo.
    Task<string> GuardarImagenAsync(IFormFile archivo, string subcarpeta);

    /// Borra un archivo del disco si existe. No tira si nombreArchivo es
    /// null/vacío o el archivo ya no está - borrar algo que ya no existe no
    /// es un error para quien llama (ver UsuarioService.ActualizarFotoVehiculoAsync,
    /// que llama esto incluso cuando el usuario nunca tuvo una foto previa).
    void Eliminar(string subcarpeta, string? nombreArchivo);

    /// Arma la URL relativa (servida por UseStaticFiles en Program.cs) a
    /// partir del nombre de archivo guardado - nunca se persiste la URL ya
    /// armada en la base, así no queda atada a un host puntual.
    string ConstruirUrlRelativa(string subcarpeta, string nombreArchivo);
}
