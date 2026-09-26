import logging
from shapely.geometry import Polygon, Point, LineString
import ezdxf

logger = logging.getLogger(__name__)

def get_points_from_polyline(entity):
    """Extrai pontos de uma entidade (LWPOLYLINE ou POLYLINE) ignorando o eixo Z."""
    pts = []
    try:
        if entity.dxftype() == 'LWPOLYLINE':
            pts = [(pt[0], pt[1]) for pt in entity]
        elif entity.dxftype() == 'POLYLINE':
            pts = [(pt.dxf.location.x, pt.dxf.location.y) for pt in entity.vertices]
    except Exception as e:
        logger.error(f"Error extracting points from {entity.dxftype()}: {e}")
        raise
    return pts

def ezdxf_entity_to_polygon(entity):
    """
    Converte uma entidade ezdxf (LWPOLYLINE, POLYLINE) em um shapely Polygon.
    Tenta fechar polylines abertas sequenciais.
    Retorna None se não for possível converter.
    """
    try:
        if entity.dxftype() in ('LWPOLYLINE', 'POLYLINE'):
            pts = get_points_from_polyline(entity)
            if not pts or len(pts) < 3:
                return None
                
            # Se não for fechada pelo ezdxf mas tiver ao menos 3 pontos, forçamos o fechamento.
            if not entity.is_closed and pts[0] != pts[-1]:
                pts.append(pts[0])
                
            if len(pts) >= 3:
                poly = Polygon(pts)
                if not poly.is_valid:
                    poly = poly.buffer(0) # Tenta corrigir self-intersections simples
                    logger.debug(f"Applied buffer(0) to fix invalid polygon from {entity.dxftype()}")
                return poly
    except Exception as e:
        logger.warning(f"Error converting {entity.dxftype()} to Polygon: {e}")
        
    return None

def associate_lotes_to_quadras(lotes, quadras):
    """
    Realiza o Point-in-Polygon.
    Retorna:
    {
        "quadras": [
            {
                "quadra_entity": q_entity,
                "lotes": [l_entity1, l_entity2...],
                "polygon": shapely_poly
            }, ...
        ],
        "lotes_orfaos": [l_entity_x, ...]
    }
    """
    quadras_data = []
    lotes_orfaos = []
    
    # 1. Parsear quadras
    for q_entity in quadras:
        poly = ezdxf_entity_to_polygon(q_entity)
        if poly and poly.is_valid:
            quadras_data.append({
                "quadra_entity": q_entity,
                "lotes": [],
                "polygon": poly
            })
        else:
            logger.warning(f"Quadra descartada (geometria inválida/nao-poligono): {q_entity}")

    # 2. Processar Lotes e rotear
    for l_entity in lotes:
        l_poly = ezdxf_entity_to_polygon(l_entity)
        
        l_centroid = None
        if l_poly and l_poly.is_valid:
            # Usar representative_point para garantir que caia dentro do lote mesmo que seja concavo
            l_centroid = l_poly.representative_point()
            
        associated = False
        if l_centroid:
            for q_data in quadras_data:
                q_poly = q_data["polygon"]
                # point-in-polygon (covers includes boundary)
                if q_poly.covers(l_centroid):
                    q_data["lotes"].append(l_entity)
                    associated = True
                    break
                    
        if not associated:
            lotes_orfaos.append(l_entity)

    return {
        "quadras": quadras_data,
        "lotes_orfaos": lotes_orfaos
    }
