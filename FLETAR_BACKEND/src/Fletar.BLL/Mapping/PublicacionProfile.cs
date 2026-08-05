using AutoMapper;
using Fletar.DAL.Models;
using Fletar.DTO.Publicaciones;

namespace Fletar.BLL.Mapping;

public class PublicacionProfile : Profile
{
    public PublicacionProfile()
    {
        // Origen/Destino son Point de NetTopologySuite en la entidad; el DTO no expone
        // un tipo Point, así que se desarman a Latitud/Longitud sueltos (Point.Y = latitud,
        // Point.X = longitud - ver convención del constructor Point(x=longitud, y=latitud)).
        CreateMap<Publicacion, PublicacionResponse>()
            .ForMember(dest => dest.Latitud, opt => opt.MapFrom(src => src.Origen.Y))
            .ForMember(dest => dest.Longitud, opt => opt.MapFrom(src => src.Origen.X))
            .ForMember(dest => dest.DestinoLatitud, opt => opt.MapFrom(src => src.Destino == null ? (double?)null : src.Destino.Y))
            .ForMember(dest => dest.DestinoLongitud, opt => opt.MapFrom(src => src.Destino == null ? (double?)null : src.Destino.X))
            .ForMember(dest => dest.Estado, opt => opt.MapFrom(src => src.Estado.ToString()))
            // Publicacion no tiene navegación a Usuario (los models de DAL no tienen
            // propiedades de navegación); el nombre se resuelve aparte en el service
            // con un lookup por lote sobre la página ya recortada.
            .ForMember(dest => dest.UsuarioNombre, opt => opt.Ignore());

        CreateMap<CategoriaCarga, CategoriaCargaResponse>();
        CreateMap<TipoVehiculo, TipoVehiculoResponse>();
    }
}
