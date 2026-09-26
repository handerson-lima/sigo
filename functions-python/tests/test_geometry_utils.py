import pytest
from unittest.mock import MagicMock
from shapely.geometry import Polygon
from geometry_utils import ezdxf_entity_to_polygon, associate_lotes_to_quadras, get_points_from_polyline

def create_mock_polyline(points, dxftype='LWPOLYLINE', is_closed=True):
    entity = MagicMock()
    entity.dxftype.return_value = dxftype
    entity.is_closed = is_closed
    
    if dxftype == 'LWPOLYLINE':
        # LWPOLYLINE points mock
        entity.__iter__.return_value = points
    else:
        # POLYLINE points mock
        class Vertex:
            def __init__(self, pt):
                self.dxf = MagicMock()
                self.dxf.location = pt
        entity.vertices = [Vertex(pt) for pt in points]
        
    return entity

def test_get_points():
    pts = [(0,0,0), (1,0,0), (1,1,0), (0,1,0)]
    ent = create_mock_polyline(pts, 'LWPOLYLINE')
    extracted = get_points_from_polyline(ent)
    assert extracted == [(0,0), (1,0), (1,1), (0,1)]

def test_get_points_polyline():
    class Pt:
        def __init__(self, x, y):
            self.x = x
            self.y = y
    pts = [Pt(0,0), Pt(1,0), Pt(1,1)]
    ent = create_mock_polyline(pts, 'POLYLINE')
    extracted = get_points_from_polyline(ent)
    assert extracted == [(0,0), (1,0), (1,1)]

def test_ezdxf_entity_to_polygon_closed():
    pts = [(0,0), (10,0), (10,10), (0,10)]
    ent = create_mock_polyline(pts, 'LWPOLYLINE', True)
    poly = ezdxf_entity_to_polygon(ent)
    assert poly is not None
    assert poly.is_valid
    assert poly.area == 100

def test_ezdxf_entity_to_polygon_open_auto_close():
    pts = [(0,0), (10,0), (10,10), (0,10)]
    ent = create_mock_polyline(pts, 'LWPOLYLINE', False)
    poly = ezdxf_entity_to_polygon(ent)
    assert poly is not None
    assert poly.is_valid
    assert poly.area == 100

def test_ezdxf_entity_to_polygon_triangle():
    pts = [(0,0), (10,0), (0,10)]
    ent = create_mock_polyline(pts, 'LWPOLYLINE', True)
    poly = ezdxf_entity_to_polygon(ent)
    assert poly is not None
    assert poly.is_valid
    assert poly.area == 50

def test_associate_lotes_to_quadras():
    # Quadra: 0,0 a 10,10
    q1 = create_mock_polyline([(0,0), (10,0), (10,10), (0,10)], 'LWPOLYLINE', True)
    # Quadra 2: 20,0 a 30,10
    q2 = create_mock_polyline([(20,0), (30,0), (30,10), (20,10)], 'LWPOLYLINE', True)
    
    # Lote 1: dentro da q1 (centroide em 5,5)
    l1 = create_mock_polyline([(2,2), (8,2), (8,8), (2,8)], 'LWPOLYLINE', True)
    # Lote 2: dentro da q2 (centroide em 25,5)
    l2 = create_mock_polyline([(22,2), (28,2), (28,8), (22,8)], 'LWPOLYLINE', True)
    # Lote Orfao: em 15,5
    l3 = create_mock_polyline([(14,4), (16,4), (16,6), (14,6)], 'LWPOLYLINE', True)
    
    quadras = [q1, q2]
    lotes = [l1, l2, l3]
    
    result = associate_lotes_to_quadras(lotes, quadras)
    
    assert len(result["quadras"]) == 2
    assert len(result["lotes_orfaos"]) == 1
    
    # Check L1 is in Q1
    assert result["quadras"][0]["quadra_entity"] == q1
    assert result["quadras"][0]["lotes"] == [l1]
    
    # Check L2 is in Q2
    assert result["quadras"][1]["quadra_entity"] == q2
    assert result["quadras"][1]["lotes"] == [l2]
    
    # Check L3 is orphan
    assert result["lotes_orfaos"] == [l3]
