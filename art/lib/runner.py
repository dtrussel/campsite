"""Import helper so asset scripts can `from lib import ...` when run as
`python art/<group>/<asset>.py` with Blender's bpy module."""
import os
import sys

ART_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ART_DIR not in sys.path:
    sys.path.insert(0, ART_DIR)
