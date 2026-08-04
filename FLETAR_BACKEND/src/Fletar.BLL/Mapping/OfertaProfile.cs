using AutoMapper;
using Fletar.DAL.Models;
using Fletar.DTO.Ofertas;

namespace Fletar.BLL.Mapping;

public class OfertaProfile : Profile
{
    public OfertaProfile()
    {
        CreateMap<Oferta, OfertaResponse>()
            .ForMember(dest => dest.Estado, opt => opt.MapFrom(src => src.Estado.ToString()));
    }
}
