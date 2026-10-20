namespace Fletar.BLL.Services.Archivos;

/// Subcarpetas dentro de AlmacenamientoSettings.RutaRaizUploads - una por cada
/// caso de uso de la Fase 8, para no mezclar en un mismo directorio fotos de
/// carga (públicas, de cualquier Publicacion) con fotos de vehículo
/// (públicas también, pero una por Usuario).
public static class CarpetasDeArchivos
{
    public const string Publicaciones = "publicaciones";
    public const string Vehiculos = "vehiculos";

    /// Documentos de identidad (Fase 9) - a diferencia de las dos de arriba,
    /// ésta cuelga de AlmacenamientoSettings.RutaPrivados (siempre con
    /// privado=true en GuardarImagenAsync/Eliminar/ObtenerRutaFisica), nunca
    /// de RutaPublicos.
    public const string DocumentosIdentidad = "documentos-identidad";
}
