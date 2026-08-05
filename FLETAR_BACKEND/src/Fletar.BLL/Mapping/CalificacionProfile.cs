using AutoMapper;
using Fletar.DAL.Models;
using Fletar.DTO.Calificaciones;

namespace Fletar.BLL.Mapping;

public class CalificacionProfile : Profile
{
    public CalificacionProfile()
    {
        CreateMap<Calificacion, CalificacionResponse>();
    }
}
