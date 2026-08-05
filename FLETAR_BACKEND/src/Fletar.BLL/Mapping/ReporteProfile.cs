using AutoMapper;
using Fletar.DAL.Models;
using Fletar.DTO.Reportes;

namespace Fletar.BLL.Mapping;

public class ReporteProfile : Profile
{
    public ReporteProfile()
    {
        CreateMap<Reporte, ReporteResponse>()
            .ForMember(dest => dest.Estado, opt => opt.MapFrom(src => src.Estado.ToString()))
            // Igual que Publicacion/Oferta: sin navegación en el model, el nombre y el
            // título se resuelven aparte en el service con un lookup por lote.
            .ForMember(dest => dest.UsuarioReportanteNombre, opt => opt.Ignore())
            .ForMember(dest => dest.PublicacionTitulo, opt => opt.Ignore());
    }
}
