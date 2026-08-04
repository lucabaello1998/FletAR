using AutoMapper;
using Fletar.DAL.Models;
using Fletar.DTO.Auth;

namespace Fletar.BLL.Mapping;

public class UsuarioProfile : Profile
{
    public UsuarioProfile()
    {
        CreateMap<Usuario, UsuarioResponse>()
            .ForMember(dest => dest.Rol, opt => opt.MapFrom(src => src.Rol.ToString().ToLowerInvariant()));
    }
}
