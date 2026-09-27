import pytest
from shapely.geometry import Polygon
import ezdxf

from geometry_utils import get_points_from_entity, ezdxf_entity_to_polygon, associate_lotes_to_quadras


def test_ezdxf_entity_to_polygon_lwpolyline():
    doc = ezdxf.new()
    msp = doc.modelspace()
    entity = msp.add_lwpolyline([(0, 0), (10, 0), (10, 10), (0, 10)])
    
    poly, _ = ezdxf_entity_to_polygon(entity)
    assert isinstance(poly, Polygon)
    assert poly.area == 100
    assert poly.is_valid

def test_ezdxf_entity_to_polygon_polyline():
    doc = ezdxf.new()
    msp = doc.modelspace()
    entity = msp.add_polyline2d([(0, 0), (10, 0), (10, 10), (0, 10)])
    
    poly, _ = ezdxf_entity_to_polygon(entity)
    assert isinstance(poly, Polygon)
    assert poly.area == 100
    assert poly.is_valid

def test_ezdxf_entity_to_polygon_triangle():
    doc = ezdxf.new()
    msp = doc.modelspace()
    # 3 points -> triangle
    entity = msp.add_lwpolyline([(0, 0), (10, 0), (0, 10)])
    
    poly, _ = ezdxf_entity_to_polygon(entity)
    assert isinstance(poly, Polygon)
    assert poly.area == 50
    assert poly.is_valid

def test_ezdxf_entity_to_polygon_not_enough_points():
    doc = ezdxf.new()
    msp = doc.modelspace()
    entity = msp.add_lwpolyline([(0, 0), (10, 0)])
    
    poly, _ = ezdxf_entity_to_polygon(entity)
    assert poly is None

def test_ezdxf_entity_to_polygon_buffer_fix():
    doc = ezdxf.new()
    msp = doc.modelspace()
    # Bowtie shape -> invalid polygon
    entity = msp.add_lwpolyline([(0, 0), (10, 10), (10, 0), (0, 10)])
    
    poly, _ = ezdxf_entity_to_polygon(entity)
    # buffer(0) on a bowtie results in a MultiPolygon, then we take the largest part
    assert poly is not None
    assert poly.is_valid

def test_associate_lotes_to_quadras_contained():
    doc = ezdxf.new()
    msp = doc.modelspace()
    
    q1 = msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)])
    l1 = msp.add_lwpolyline([(10, 10), (20, 10), (20, 20), (10, 20)]) # Contained in q1
    l2 = msp.add_lwpolyline([(200, 200), (210, 200), (210, 210), (200, 210)]) # Orphan
    
    association = associate_lotes_to_quadras([l1, l2], [q1])
    
    assert association['quadras'][q1] == [l1]
    assert association['lotes_orfaos'] == [l2]

def test_associate_lotes_to_quadras_overlapping():
    doc = ezdxf.new()
    msp = doc.modelspace()
    
    q1 = msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)]) # Big
    q2 = msp.add_lwpolyline([(10, 10), (50, 10), (50, 50), (10, 50)]) # Small
    
    l1 = msp.add_lwpolyline([(20, 20), (30, 20), (30, 30), (20, 30)]) # Contained in both
    
    association = associate_lotes_to_quadras([l1], [q1, q2])
    
    # Should pick q2 because it has a smaller area
    assert association['quadras'][q2] == [l1]
    assert association['quadras'][q1] == []


def test_repaired_quadras_preserve_all_components_and_associations():
    msp = ezdxf.new().modelspace()
    q = msp.add_lwpolyline([(0,0),(4,0),(4,4),(0,4),(0,0),(6,0),(7,0),(7,1),(6,1),(6,0),(0,0)])
    lotes = [msp.add_lwpolyline(points) for points in [
        [(1,1),(2,1),(2,2),(1,2)],
        [(6.1,.1),(6.9,.1),(6.9,.9),(6.1,.9)],
    ]]
    result = associate_lotes_to_quadras(lotes, [q])
    assert result['quadra_polygons'][q].area == 17
    assert result['quadra_polygons'][q].geom_type == 'MultiPolygon'
    assert result['quadras'][q] == lotes
    assert result['lotes_orfaos'] == []
    assert result['quadras_reparadas'] == {q}


def test_single_polygon_repair_requires_review_and_empty_is_ignored(caplog):
    msp = ezdxf.new().modelspace()
    q = msp.add_lwpolyline([(0,0),(10,10),(10,0),(0,10)])
    empty = msp.add_lwpolyline([(20,0),(21,0),(22,0)])
    orphan = msp.add_lwpolyline([(20,0),(21,0),(21,1),(20,1)])
    result = associate_lotes_to_quadras([orphan], [q, empty])
    assert result['quadra_polygons'][q].geom_type == 'Polygon'
    assert result['quadras_reparadas'] == {q}
    assert empty not in result['quadra_polygons']
    assert result['lotes_orfaos'] == [orphan]
    assert 'ignored' in caplog.text
