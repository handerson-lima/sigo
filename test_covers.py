import sys
import os
sys.path.append(os.path.join(os.getcwd(), 'functions-python'))
import ezdxf
from shapely.geometry import MultiPolygon, Polygon, shape, Point
from geometry_utils import ezdxf_entity_to_polygon, associate_lotes_to_quadras
from heuristics import build_geojson, extract_text

doc = ezdxf.new()
msp = doc.modelspace()
q = msp.add_lwpolyline([(0,0),(4,0),(4,4),(0,4),(0,0),(6,0),(7,0),(7,1),(6,1),(6,0),(0,0)], dxfattribs={'layer': 'QUADRAS'})

lotes = []
textos = []
for x, y, size, name in [(1,1,1,'1'), (6.1,.1,.8,'2')]:
    lotes.append(msp.add_lwpolyline([(x,y),(x+size,y),(x+size,y+size),(x,y+size)], dxfattribs={'layer': 'LOTES'}))
    textos.append(msp.add_text(name, dxfattribs={'insert': (x+.1,y+.1)}))
textos.append(msp.add_text('Q 1', dxfattribs={'insert': (3,3)}))

association = associate_lotes_to_quadras(lotes, [q])
print("Quadras items:", association['quadras'])
print("Orphans:", association['lotes_orfaos'])

for t in textos:
    print(extract_text(t))
