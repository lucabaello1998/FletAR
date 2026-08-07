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
}
