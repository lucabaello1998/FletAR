using Fletar.BLL.Settings;
using Microsoft.AspNetCore.Http;

namespace Fletar.BLL.Services.Archivos;

/// Almacenamiento de imágenes en disco local (Fase 8) - ver AlmacenamientoSettings
/// para el porqué de guardar en disco en vez de un blob storage en la nube.
public class AlmacenamientoArchivosService(AlmacenamientoSettings settings) : IAlmacenamientoArchivosService
{
    private const long TamanioMaximoBytes = 5 * 1024 * 1024; // 5MB por archivo

    // Content-Type declarado por el cliente -> extensión con la que se guarda.
    // El Content-Type NO es confiable por sí solo (lo controla el cliente) -
    // por eso además se valida la firma real de los primeros bytes del
    // archivo (magic numbers, ver TieneFirmaValida) antes de aceptar
    // cualquier imagen. Sólo estos tres formatos - nada de svg/gif/pdf/etc.
    private static readonly Dictionary<string, string> ExtensionPorContentType = new(StringComparer.OrdinalIgnoreCase)
    {
        ["image/jpeg"] = ".jpg",
        ["image/png"] = ".png",
        ["image/webp"] = ".webp"
    };

    public async Task<string> GuardarImagenAsync(IFormFile archivo, string subcarpeta, bool privado = false)
    {
        if (archivo is null || archivo.Length == 0)
            throw new InvalidOperationException("No se recibió ningún archivo.");

        if (archivo.Length > TamanioMaximoBytes)
            throw new InvalidOperationException(
                $"El archivo supera el tamaño máximo permitido ({TamanioMaximoBytes / (1024 * 1024)}MB).");

        if (!ExtensionPorContentType.TryGetValue(archivo.ContentType, out var extension))
            throw new InvalidOperationException("Sólo se permiten imágenes JPG, PNG o WEBP.");

        await using var origen = archivo.OpenReadStream();

        var encabezado = new byte[12];
        var leidos = await origen.ReadAsync(encabezado.AsMemory(0, encabezado.Length));
        if (leidos < encabezado.Length || !TieneFirmaValida(encabezado, extension))
            throw new InvalidOperationException("El archivo no es una imagen válida.");

        origen.Position = 0;

        // Nombre generado con GUID, nunca el nombre original del cliente -
        // evita path traversal (un nombre como "../../otra-carpeta/x") y
        // colisiones entre dos usuarios subiendo un archivo con el mismo
        // nombre original.
        var nombreGenerado = $"{Guid.NewGuid():N}{extension}";
        var carpetaDestino = Path.Combine(RaizPara(privado), subcarpeta);
        Directory.CreateDirectory(carpetaDestino);
        var rutaDestino = Path.Combine(carpetaDestino, nombreGenerado);

        await using var destino = File.Create(rutaDestino);
        await origen.CopyToAsync(destino);

        return nombreGenerado;
    }

    public void Eliminar(string subcarpeta, string? nombreArchivo, bool privado = false)
    {
        if (string.IsNullOrWhiteSpace(nombreArchivo))
            return;

        // nombreArchivo siempre debería ser ya un nombre "limpio" (lo generamos
        // nosotros en GuardarImagenAsync) o, como mucho, la URL relativa que
        // nosotros mismos armamos con ConstruirUrlRelativa - pero Path.GetFileName
        // igual por las dudas, para no seguir un path traversal si alguna vez
        // se llega a llamar con algo inesperado.
        var nombreSeguro = Path.GetFileName(nombreArchivo);
        if (string.IsNullOrWhiteSpace(nombreSeguro))
            return;

        var ruta = Path.Combine(RaizPara(privado), subcarpeta, nombreSeguro);
        if (File.Exists(ruta))
            File.Delete(ruta);
    }

    public string ConstruirUrlRelativa(string subcarpeta, string nombreArchivo)
        => $"/uploads/{subcarpeta}/{nombreArchivo}";

    public string ObtenerRutaFisica(string subcarpeta, string nombreArchivo, bool privado = false)
    {
        var nombreSeguro = Path.GetFileName(nombreArchivo);
        return Path.Combine(RaizPara(privado), subcarpeta, nombreSeguro);
    }

    private string RaizPara(bool privado) => privado ? settings.RutaPrivados : settings.RutaPublicos;

    private static bool TieneFirmaValida(byte[] encabezado, string extension) => extension switch
    {
        ".jpg" => encabezado[0] == 0xFF && encabezado[1] == 0xD8 && encabezado[2] == 0xFF,
        ".png" => encabezado[0] == 0x89 && encabezado[1] == 0x50 && encabezado[2] == 0x4E && encabezado[3] == 0x47
                  && encabezado[4] == 0x0D && encabezado[5] == 0x0A && encabezado[6] == 0x1A && encabezado[7] == 0x0A,
        ".webp" => encabezado[0] == (byte)'R' && encabezado[1] == (byte)'I' && encabezado[2] == (byte)'F' && encabezado[3] == (byte)'F'
                   && encabezado[8] == (byte)'W' && encabezado[9] == (byte)'E' && encabezado[10] == (byte)'B' && encabezado[11] == (byte)'P',
        _ => false
    };
}
