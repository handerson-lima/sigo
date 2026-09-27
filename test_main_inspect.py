import ezdxf
from shapely.geometry import MultiPolygon, Polygon, shape
from main import extract_dxf_geometries
from geometry_utils import associate_lotes_to_quadras
from heuristics import build_geojson
doc = ezdxf.new()
msp = doc.modelspace()
msp.add_lwpolyline([(0,0),(4,0),(4,4),(0,4),(0,0),(6,0),(7,0),(7,1),(6,1),(6,0),(0,0)], dxfattribs={'layer': 'QUADRAS'})
for x, y, size, name in [(1,1,1,'1'), (6.1,.1,.8,'2')]:
    msp.add_lwpolyline([(x,y),(x+size,y),(x+size,y+size),(x,y+size)], dxfattribs={'layer': 'LOTES'})
    msp.add_text(name, dxfattribs={'insert': (x+.1,y+.1)})
msp.add_text('Q 1', dxfattribs={'insert': (3,3)})
doc.saveas('inspect.dxf')
lotes, quadras, textos = extract_dxf_geometries('inspect.dxf')
association = associate_lotes_to_quadras(lotes, quadras)
geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
print([f['properties'] for f in geojson['features']])
