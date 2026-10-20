namespace Fletar.BLL.Settings;

/// Ruta absoluta en disco donde se guardan las imágenes subidas por usuarios
/// (fotos de carga de una Publicacion, foto de vehículo de un Usuario - Fase
/// 8). Simplificación de desarrollo, documentada a propósito: este entorno no
/// tiene un blob storage en la nube configurado (ni S3, ni Azure Blob, ni
/// nada por el estilo), así que por ahora se guarda en el disco local del
/// propio servidor de la API y se sirve vía UseStaticFiles en Program.cs,
/// scopeado explícitamente sólo a esta carpeta.
///
/// Esto NO es una excepción a "FletAR no sirve un frontend propio desde la
/// API" (ver CLAUDE.md, Estructura del repositorio) - es un mecanismo
/// deliberadamente separado y acotado sólo a contenido subido por usuarios,
/// nunca para servir el build de Flutter web ni un index.html; no hay
/// fallback de SPA ni se sirve nada fuera de esta carpeta puntual.
///
/// En producción real convendría migrar a un blob storage en la nube, pero
/// no hay uso real todavía que lo justifique - mismo criterio que el resto
/// del roadmap explícitamente diferido (pagos/Mercado Pago, verificación de
/// identidad, cache con Redis: "se agregan cuando haya uso real que lo
/// justifique").
public class AlmacenamientoSettings(string rutaRaizUploads)
{
    public string RutaRaizUploads { get; } = rutaRaizUploads;

    /// Sub-raíz servida públicamente vía UseStaticFiles en Program.cs (fotos de
    /// carga/vehículo, Fase 8) - todo lo que cuelga de acá es alcanzable sin
    /// autenticar, por diseño.
    public string RutaPublicos { get; } = Path.Combine(rutaRaizUploads, "publico");

    /// Sub-raíz que NUNCA se registra en UseStaticFiles ni en ningún otro
    /// middleware de archivos estáticos (documentos de identidad, Fase 9) - la
    /// única forma de leer algo de acá es un endpoint autenticado que valide
    /// ownership/rol y devuelva el archivo a mano (PhysicalFile/File). Ver
    /// Program.cs: el PhysicalFileProvider de estáticos apunta sólo a
    /// RutaPublicos, jamás a esta carpeta.
    public string RutaPrivados { get; } = Path.Combine(rutaRaizUploads, "privado");
}
