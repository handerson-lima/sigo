import sys
import os
sys.path.append(os.path.join(os.getcwd(), 'functions-python'))
import ezdxf
from heuristics import extract_text

doc = ezdxf.new()
msp = doc.modelspace()
txt = msp.add_text('Q 1', dxfattribs={'insert': (3,3)})
print("insert:", txt.dxf.insert)
print("align_point:", txt.dxf.align_point if hasattr(txt.dxf, 'align_point') else "No align point")
print("extract_text:", extract_text(txt))
