using AutoMapper;
using Fletar.DAL.Models;
using Fletar.DTO.Mensajes;

namespace Fletar.BLL.Mapping;

public class MensajeProfile : Profile
{
    public MensajeProfile()
    {
        CreateMap<Mensaje, MensajeResponse>()
            // Igual que en OfertaProfile: sin navegación a Usuario, el nombre del
            // remitente se resuelve en el service con un lookup por lote.
            .ForMember(dest => dest.RemitenteNombre, opt => opt.Ignore());
    }
}
