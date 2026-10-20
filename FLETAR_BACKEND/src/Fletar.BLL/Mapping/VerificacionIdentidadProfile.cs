using AutoMapper;
using Fletar.DAL.Models;
using Fletar.DTO.VerificacionesIdentidad;

namespace Fletar.BLL.Mapping;

public class VerificacionIdentidadProfile : Profile
{
    public VerificacionIdentidadProfile()
    {
        CreateMap<VerificacionIdentidad, VerificacionIdentidadResponse>()
            .ForMember(dest => dest.Estado, opt => opt.MapFrom(src => src.Estado.ToString()));

        CreateMap<VerificacionIdentidad, VerificacionIdentidadAdminResponse>()
            .ForMember(dest => dest.Estado, opt => opt.MapFrom(src => src.Estado.ToString()))
            // Igual que Publicacion/Oferta/Reporte: sin navegación en el model,
            // UsuarioNombre/UsuarioEmail se resuelven aparte en el service con
            // un lookup por lote.
            .ForMember(dest => dest.UsuarioNombre, opt => opt.Ignore())
            .ForMember(dest => dest.UsuarioEmail, opt => opt.Ignore());
    }
}
