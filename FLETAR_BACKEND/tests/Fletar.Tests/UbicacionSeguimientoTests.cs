using Fletar.API.Hubs;
using Fletar.DAL.Models;

namespace Fletar.Tests;

/// La autorización para ver el GPS de un fletero no puede sobrevivir al viaje
/// (Fase 6, endurecida después de la auditoría): estas combinaciones son la
/// regla completa, sin base de datos de por medio.
public class UbicacionSeguimientoTests
{
    [Theory]
    [InlineData(EstadoPublicacion.EnCurso, EstadoOferta.Aceptada)]
    [InlineData(EstadoPublicacion.OfertaAceptada, EstadoOferta.Aceptada)]
    [InlineData(EstadoPublicacion.Publicada, EstadoOferta.Pendiente)]
    public void Permite_mientras_el_viaje_sigue_en_juego(EstadoPublicacion publicacion, EstadoOferta oferta)
        => Assert.True(UbicacionHub.SeguimientoPermitido(publicacion, oferta));

    [Theory]
    [InlineData(EstadoPublicacion.Completada, EstadoOferta.Aceptada)]
    [InlineData(EstadoPublicacion.Cancelada, EstadoOferta.Aceptada)]
    [InlineData(EstadoPublicacion.Completada, EstadoOferta.Pendiente)]
    [InlineData(EstadoPublicacion.Cancelada, EstadoOferta.Pendiente)]
    [InlineData(EstadoPublicacion.Publicada, EstadoOferta.Rechazada)]
    [InlineData(EstadoPublicacion.Publicada, EstadoOferta.Retirada)]
    public void Niega_cuando_el_viaje_termino_o_la_oferta_ya_no_corre(EstadoPublicacion publicacion, EstadoOferta oferta)
        => Assert.False(UbicacionHub.SeguimientoPermitido(publicacion, oferta));
}
