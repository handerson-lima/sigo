import pytest
from shapely.geometry import Polygon
import ezdxf

from geometry_utils import get_points_from_entity, ezdxf_entity_to_polygon, associate_lotes_to_quadras


def test_ezdxf_entity_to_polygon_lwpolyline():
    doc = ezdxf.new()
    msp = doc.modelspace()
    entity = msp.add_lwpolyline([(0, 0), (10, 0), (10, 10), (0, 10)])
    
    poly = ezdxf_entity_to_polygon(entity)
    assert isinstance(poly, Polygon)
    assert poly.area == 100
    assert poly.is_valid

def test_ezdxf_entity_to_polygon_polyline():
    doc = ezdxf.new()
    msp = doc.modelspace()
    entity = msp.add_polyline2d([(0, 0), (10, 0), (10, 10), (0, 10)])
    
    poly = ezdxf_entity_to_polygon(entity)
    assert isinstance(poly, Polygon)
    assert poly.area == 100
    assert poly.is_valid

def test_ezdxf_entity_to_polygon_triangle():
    doc = ezdxf.new()
    msp = doc.modelspace()
    # 3 points -> triangle
    entity = msp.add_lwpolyline([(0, 0), (10, 0), (0, 10)])
    
    poly = ezdxf_entity_to_polygon(entity)
    assert isinstance(poly, Polygon)
    assert poly.area == 50
    assert poly.is_valid

def test_ezdxf_entity_to_polygon_not_enough_points():
    doc = ezdxf.new()
    msp = doc.modelspace()
    entity = msp.add_lwpolyline([(0, 0), (10, 0)])
    
    poly = ezdxf_entity_to_polygon(entity)
    assert poly is None

def test_ezdxf_entity_to_polygon_buffer_fix():
    doc = ezdxf.new()
    msp = doc.modelspace()
    # Bowtie shape -> invalid polygon
    entity = msp.add_lwpolyline([(0, 0), (10, 10), (10, 0), (0, 10)])
    
    poly = ezdxf_entity_to_polygon(entity)
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
