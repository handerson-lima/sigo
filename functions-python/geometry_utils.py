import logging
from shapely.geometry import Polygon, MultiPolygon
from shapely.errors import ShapelyError

logger = logging.getLogger(__name__)

def get_points_from_entity(entity):
    """Extracts 2D points from ezdxf LWPOLYLINE or POLYLINE entities."""
    pts = []
    etype = entity.dxftype()
    
    try:
        if etype == 'LWPOLYLINE':
            for pt in entity.get_points(format='xy'):
                pts.append((pt[0], pt[1]))
        elif etype == 'POLYLINE':
            # ezdxf Vec3 objects have .x and .y attributes
            for v in entity.vertices:
                loc = v.dxf.location
                pts.append((loc.x, loc.y))
    except Exception as e:
        logger.warning(f"Error extracting points from {etype}: {e}")
        return []
        
    return pts

def ezdxf_entity_to_polygon(entity):
    """
    Converts an ezdxf entity to a Shapely Polygon.
    Returns None if conversion fails.
    """
    pts = get_points_from_entity(entity)
    if not pts:
        return None

    # Needs at least 3 points to form a polygon (e.g. triangle)
    if len(pts) < 3:
        logger.debug(f"Entity has less than 3 points, ignoring.")
        return None

    # Close the polygon if not closed
    if pts[0] != pts[-1]:
        pts.append(pts[0])

    try:
        poly = Polygon(pts)
    except Exception as e:
        logger.warning(f"Error creating Polygon: {e}")
        return None

    if not poly.is_valid:
        logger.debug(f"Invalid geometry detected, attempting buffer(0) fix.")
        try:
            poly = poly.buffer(0)
            # buffer(0) could result in MultiPolygon or GeometryCollection
            if isinstance(poly, MultiPolygon):
                if len(poly.geoms) > 0:
                    # Take the largest polygon part
                    poly = max(poly.geoms, key=lambda a: a.area)
                else:
                    poly = None
            if poly is None or poly.is_empty or not isinstance(poly, Polygon):
                logger.warning(f"Geometry remains invalid or empty after buffer(0).")
                return None
        except Exception as e:
            logger.warning(f"buffer(0) fix failed: {e}")
            return None

    return poly

def associate_lotes_to_quadras(lotes, quadras):
    """
    Associates Lote entities to Quadra entities based on spatial containment.
    Returns a dictionary with:
      - 'quadras': dict mapping quadra entity to a list of contained lote entities
      - 'lotes_orfaos': list of lote entities that do not belong to any quadra
      - 'quadra_polygons': dict mapping quadra entity to Shapely Polygon
      - 'lote_polygons': dict mapping lote entity to Shapely Polygon
    """
    # Pre-compute valid polygons for quadras
    quadra_polygons = {}
    for q in quadras:
        poly = ezdxf_entity_to_polygon(q)
        if poly is not None:
            quadra_polygons[q] = poly
        else:
            logger.warning("Quadra converted to None or invalid polygon, will be ignored.")
            
    # We also need lote polygons for further processing
    lote_polygons = {}
    for lote in lotes:
        poly = ezdxf_entity_to_polygon(lote)
        if poly is not None:
            lote_polygons[lote] = poly

    association = {
        'quadras': {q: [] for q in quadras},
        'lotes_orfaos': [],
        'quadra_polygons': quadra_polygons,
        'lote_polygons': lote_polygons
    }
    
    # Associate lotes
    for lote, lote_poly in lote_polygons.items():
            
        try:
            rep_point = lote_poly.representative_point()
        except ShapelyError:
            # Fallback if representative point fails
            rep_point = lote_poly.centroid
            
        matched_quadras = []
        for q_entity, q_poly in quadra_polygons.items():
            if q_poly.covers(rep_point):
                matched_quadras.append((q_entity, q_poly))
                
        if not matched_quadras:
            association['lotes_orfaos'].append(lote)
        else:
            # In case of nested/overlapping quadras, pick the one with the smallest area
            # This handles the case where one quadra is fully contained in another.
            best_match = min(matched_quadras, key=lambda pair: pair[1].area)
            association['quadras'][best_match[0]].append(lote)
            
            if len(matched_quadras) > 1:
                logger.info("Lote belongs to multiple quadras. Ambiguity resolved by choosing the smallest quadra.")

    # Lotes that failed to convert to polygon are also orphans
    for lote in lotes:
        if lote not in lote_polygons:
            logger.warning("Lote converted to None, adding to orphans.")
            association['lotes_orfaos'].append(lote)

    return association
