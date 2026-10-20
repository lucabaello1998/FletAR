using Microsoft.AspNetCore.Http;

namespace Fletar.BLL.Services.Archivos;

public interface IAlmacenamientoArchivosService
{
    /// Valida y guarda una imagen en disco bajo la subcarpeta indicada (ver
    /// CarpetasDeArchivos). Devuelve el nombre de archivo generado (GUID +
    /// extensión) - nunca el nombre original que mandó el cliente. Tira
    /// InvalidOperationException (400 vía ManejadorDeExcepciones) si el
    /// archivo no es una imagen válida o supera el tamaño máximo.
    ///
    /// privado=false (default, sin tocar los call-sites de la Fase 8) guarda
    /// bajo AlmacenamientoSettings.RutaPublicos, servida por UseStaticFiles.
    /// privado=true (documentos de identidad, Fase 9) guarda bajo RutaPrivados,
    /// que ningún middleware de archivos estáticos sirve - sólo se lee vía un
    /// endpoint autenticado que la aplicación arme a mano.
    Task<string> GuardarImagenAsync(IFormFile archivo, string subcarpeta, bool privado = false);

    /// Borra un archivo del disco si existe. No tira si nombreArchivo es
    /// null/vacío o el archivo ya no está - borrar algo que ya no existe no
    /// es un error para quien llama (ver UsuarioService.ActualizarFotoVehiculoAsync,
    /// que llama esto incluso cuando el usuario nunca tuvo una foto previa).
    void Eliminar(string subcarpeta, string? nombreArchivo, bool privado = false);

    /// Arma la URL relativa (servida por UseStaticFiles en Program.cs) a
    /// partir del nombre de archivo guardado - nunca se persiste la URL ya
    /// armada en la base, así no queda atada a un host puntual. Sólo tiene
    /// sentido para archivos públicos (privado=false); un archivo privado no
    /// tiene URL propia, se lee con ObtenerRutaFisica.
    string ConstruirUrlRelativa(string subcarpeta, string nombreArchivo);

    /// Devuelve la ruta física absoluta de un archivo ya guardado, para
    /// servirlo a mano (PhysicalFile()/File()) desde un endpoint autenticado -
    /// pensado para archivos privados (documentos de identidad, Fase 9), que
    /// nunca pasan por UseStaticFiles. Igual que Eliminar, sanea el nombre con
    /// Path.GetFileName antes de combinar rutas, por las dudas.
    string ObtenerRutaFisica(string subcarpeta, string nombreArchivo, bool privado = false);
}
