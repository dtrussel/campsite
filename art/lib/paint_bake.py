"""The painted look: bakes LoL-style hand-painted shading into a texture.

For a mesh, builds a Cycles bake material that combines
  * the base colour (face-corner attribute 'Col' or an existing texture),
  * a warm top light and cool, violet-tinted underside,
  * ambient occlusion (dark crevices),
  * a bright highlight on convex edges (Bevel-normal difference),
  * low-frequency brush-stroke noise and hue jitter,
then bakes it (EMIT) into one texture on a fresh UV map and swaps the
material for a plain textured one ready for glTF export.
"""

import bpy

from . import common


DEFAULTS = {
    "size": 1024,
    "light": (1.12, 1.04, 0.9),      # multiplier on up-facing surfaces
    "shadow": (0.36, 0.34, 0.55),    # multiplier on down-facing surfaces (cool violet)
    "ao_distance": 0.35,
    "ao_strength": 0.7,
    "edge_strength": 0.5,
    "edge_radius": 0.03,
    "noise_scale": 5.0,
    "noise_strength": 0.08,
    "stroke_strength": 0.06,
    "samples": 24,
    "margin": 8,
    "overlay": None,     # (image_path, uv_name): painted face alpha-blended over the base colour
    "key_light": None,   # (x, y, z) direction toward a baked key light
    "key_strength": 0.0,
    "cavity": 0.0,       # darken crevices (Geometry Pointiness)
    "curvature_tint": None,  # (concave_rgb, convex_rgb, strength): warm dark valleys, cool light crests
    "foot_darken": 0.0,  # LoL-style: darker toward the feet (0 = off)
    "foot_height": 1.0,  # object-space height where the darkening fades out
}


def _node(tree, kind, location, **props):
    node = tree.nodes.new(kind)
    node.location = location
    for key, value in props.items():
        setattr(node, key, value)
    return node


def _base_color_socket(tree, obj, source):
    """Returns an output socket giving the unlit base colour."""
    if source == "attribute":
        attr = _node(tree, "ShaderNodeVertexColor", (-900, 300))
        attr.layer_name = "Col"
        return attr.outputs["Color"]
    # Texture from the object's existing material, on its original UVs.
    image = None
    for slot in obj.material_slots:
        if slot.material and slot.material.use_nodes:
            for n in slot.material.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    image = n.image
                    break
        if image:
            break
    uv = _node(tree, "ShaderNodeUVMap", (-1100, 300))
    uv.uv_map = source
    tex = _node(tree, "ShaderNodeTexImage", (-900, 300))
    tex.image = image
    tex.interpolation = "Closest"
    tree.links.new(uv.outputs["UV"], tex.inputs["Vector"])
    return tex.outputs["Color"]


def overlay_socket(tree, base, geo, image_path, uv_name, facing=-0.1):
    """Alpha-blends a painted image (e.g. a face) over `base`, sampled on
    the `uv_name` map and faded out on surfaces facing away from the
    front (-Y)."""
    image = bpy.data.images.load(image_path, check_existing=True)
    image.alpha_mode = "STRAIGHT"
    uv = _node(tree, "ShaderNodeUVMap", (-1300, 600))
    uv.uv_map = uv_name
    tex = _node(tree, "ShaderNodeTexImage", (-1100, 600))
    tex.image = image
    tex.extension = "CLIP"
    tex.interpolation = "Cubic"
    tree.links.new(uv.outputs["UV"], tex.inputs["Vector"])
    sep = _node(tree, "ShaderNodeSeparateXYZ", (-1100, 800))
    tree.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    facing_mask = _node(tree, "ShaderNodeMapRange", (-900, 800))
    facing_mask.inputs["From Min"].default_value = facing
    facing_mask.inputs["From Max"].default_value = facing - 0.3
    tree.links.new(sep.outputs["Y"], facing_mask.inputs["Value"])
    fac = _node(tree, "ShaderNodeMath", (-900, 650), operation="MULTIPLY")
    tree.links.new(tex.outputs["Alpha"], fac.inputs[0])
    tree.links.new(facing_mask.outputs["Result"], fac.inputs[1])
    mix = _node(tree, "ShaderNodeMix", (-700, 500), data_type="RGBA")
    tree.links.new(fac.outputs["Value"], mix.inputs["Factor"])
    tree.links.new(base, mix.inputs["A"])
    tree.links.new(tex.outputs["Color"], mix.inputs["B"])
    return mix.outputs["Result"]


def _build_bake_material(obj, source, p):
    mat = bpy.data.materials.new(obj.name + "_bake")
    mat.use_nodes = True
    tree = mat.node_tree
    tree.nodes.clear()
    out = _node(tree, "ShaderNodeOutputMaterial", (900, 0))
    emit = _node(tree, "ShaderNodeEmission", (700, 0))
    tree.links.new(emit.outputs["Emission"], out.inputs["Surface"])

    base = _base_color_socket(tree, obj, source)
    geo = _node(tree, "ShaderNodeNewGeometry", (-1100, -200))
    if p["overlay"]:
        base = overlay_socket(tree, base, geo, *p["overlay"])

    # Top light: mix shadow->light tint by the normal's Z.
    sep = _node(tree, "ShaderNodeSeparateXYZ", (-900, -200))
    tree.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    ramp_in = _node(tree, "ShaderNodeMapRange", (-700, -200))
    ramp_in.inputs["From Min"].default_value = -0.6
    ramp_in.inputs["From Max"].default_value = 0.9
    tree.links.new(sep.outputs["Z"], ramp_in.inputs["Value"])
    tint = _node(tree, "ShaderNodeMix", (-500, -200), data_type="RGBA")
    tint.inputs["A"].default_value = (*p["shadow"], 1)
    tint.inputs["B"].default_value = (*p["light"], 1)
    tree.links.new(ramp_in.outputs["Result"], tint.inputs["Factor"])

    lit = _node(tree, "ShaderNodeMix", (-300, 200), data_type="RGBA", blend_type="MULTIPLY")
    lit.inputs["Factor"].default_value = 1.0
    tree.links.new(base, lit.inputs["A"])
    tree.links.new(tint.outputs["Result"], lit.inputs["B"])
    if p["key_light"] and p["key_strength"] > 0:
        # Baked key light (LoL textures carry strong painted lighting).
        key_dot = _node(tree, "ShaderNodeVectorMath", (-700, 450), operation="DOT_PRODUCT")
        tree.links.new(geo.outputs["Normal"], key_dot.inputs[0])
        kl = p["key_light"]
        length = sum(c * c for c in kl) ** 0.5
        key_dot.inputs[1].default_value = tuple(c / length for c in kl)
        key_map = _node(tree, "ShaderNodeMapRange", (-500, 450))
        key_map.inputs["From Min"].default_value = -0.3
        key_map.inputs["From Max"].default_value = 1.0
        key_map.inputs["To Min"].default_value = 1.0 - p["key_strength"]
        key_map.inputs["To Max"].default_value = 1.0 + p["key_strength"] * 0.35
        tree.links.new(key_dot.outputs["Value"], key_map.inputs["Value"])
        keyed = _node(tree, "ShaderNodeMix", (-200, 400), data_type="RGBA", blend_type="MULTIPLY")
        keyed.inputs["Factor"].default_value = 1.0
        tree.links.new(lit.outputs["Result"], keyed.inputs["A"])
        tree.links.new(key_map.outputs["Result"], keyed.inputs["B"])
        lit = keyed
    if p["cavity"] > 0:
        cav = _node(tree, "ShaderNodeMapRange", (-500, 650))
        cav.inputs["From Min"].default_value = 0.44
        cav.inputs["From Max"].default_value = 0.52
        cav.inputs["To Min"].default_value = 1.0 - p["cavity"]
        cav.inputs["To Max"].default_value = 1.0
        tree.links.new(geo.outputs["Pointiness"], cav.inputs["Value"])
        caved = _node(tree, "ShaderNodeMix", (-150, 600), data_type="RGBA", blend_type="MULTIPLY")
        caved.inputs["Factor"].default_value = 1.0
        tree.links.new(lit.outputs["Result"], caved.inputs["A"])
        tree.links.new(cav.outputs["Result"], caved.inputs["B"])
        lit = caved

    if p["curvature_tint"]:
        # Painted form: fold valleys and creases warm and dark, crests and
        # plane edges cooler and lighter (hand-painted, not plastic).
        concave, convex, strength = p["curvature_tint"]
        curv = _node(tree, "ShaderNodeMapRange", (-500, 850))
        curv.inputs["From Min"].default_value = 0.46
        curv.inputs["From Max"].default_value = 0.54
        tree.links.new(geo.outputs["Pointiness"], curv.inputs["Value"])
        ctint = _node(tree, "ShaderNodeMix", (-350, 850), data_type="RGBA")
        ctint.inputs["A"].default_value = (*concave, 1)
        ctint.inputs["B"].default_value = (*convex, 1)
        tree.links.new(curv.outputs["Result"], ctint.inputs["Factor"])
        tinted = _node(tree, "ShaderNodeMix", (-150, 800), data_type="RGBA", blend_type="MULTIPLY")
        tinted.inputs["Factor"].default_value = strength
        tree.links.new(lit.outputs["Result"], tinted.inputs["A"])
        tree.links.new(ctint.outputs["Result"], tinted.inputs["B"])
        lit = tinted

    # Ambient occlusion darkens crevices.
    ao = _node(tree, "ShaderNodeAmbientOcclusion", (-500, -450))
    ao.samples = 16
    ao.inputs["Distance"].default_value = p["ao_distance"]
    ao_mix = _node(tree, "ShaderNodeMapRange", (-300, -450))
    ao_mix.inputs["From Min"].default_value = 0.0
    ao_mix.inputs["From Max"].default_value = 1.0
    ao_mix.inputs["To Min"].default_value = 1.0 - p["ao_strength"]
    ao_mix.inputs["To Max"].default_value = 1.0
    tree.links.new(ao.outputs["AO"], ao_mix.inputs["Value"])
    ao_mul = _node(tree, "ShaderNodeMix", (-100, 200), data_type="RGBA", blend_type="MULTIPLY")
    ao_mul.inputs["Factor"].default_value = 1.0
    tree.links.new(lit.outputs["Result"], ao_mul.inputs["A"])
    tree.links.new(ao_mix.outputs["Result"], ao_mul.inputs["B"])

    # Convex edge highlight: where the bevelled normal departs from the
    # true normal, brighten (painted "edge catch light").
    bevel = _node(tree, "ShaderNodeBevel", (-700, -700))
    bevel.samples = 8
    bevel.inputs["Radius"].default_value = p["edge_radius"]
    dot = _node(tree, "ShaderNodeVectorMath", (-500, -700), operation="DOT_PRODUCT")
    tree.links.new(bevel.outputs["Normal"], dot.inputs[0])
    tree.links.new(geo.outputs["Normal"], dot.inputs[1])
    edge = _node(tree, "ShaderNodeMapRange", (-300, -700))
    edge.inputs["From Min"].default_value = 0.995
    edge.inputs["From Max"].default_value = 0.93
    edge.inputs["To Min"].default_value = 0.0
    edge.inputs["To Max"].default_value = p["edge_strength"]
    tree.links.new(dot.outputs["Value"], edge.inputs["Value"])
    # Only up/side-facing edges catch light.
    edge_up = _node(tree, "ShaderNodeMath", (-100, -700), operation="MULTIPLY")
    tree.links.new(edge.outputs["Result"], edge_up.inputs[0])
    tree.links.new(ramp_in.outputs["Result"], edge_up.inputs[1])
    screen = _node(tree, "ShaderNodeMix", (100, 200), data_type="RGBA", blend_type="SCREEN")
    tree.links.new(edge_up.outputs["Value"], screen.inputs["Factor"])
    tree.links.new(ao_mul.outputs["Result"], screen.inputs["A"])
    screen.inputs["B"].default_value = (1.0, 0.95, 0.82, 1)

    # Brush noise: soft value jitter plus stretched strokes.
    coord = _node(tree, "ShaderNodeTexCoord", (-1100, -1000))
    noise = _node(tree, "ShaderNodeTexNoise", (-900, -1000))
    noise.inputs["Scale"].default_value = p["noise_scale"]
    noise.inputs["Detail"].default_value = 3.0
    tree.links.new(coord.outputs["Object"], noise.inputs["Vector"])
    stroke_map = _node(tree, "ShaderNodeMapping", (-900, -1250))
    stroke_map.inputs["Scale"].default_value = (1.0, 1.0, 6.0)
    tree.links.new(coord.outputs["Object"], stroke_map.inputs["Vector"])
    strokes = _node(tree, "ShaderNodeTexNoise", (-700, -1250))
    strokes.inputs["Scale"].default_value = p["noise_scale"] * 1.6
    tree.links.new(stroke_map.outputs["Vector"], strokes.inputs["Vector"])
    jitter = _node(tree, "ShaderNodeMath", (-500, -1000), operation="MULTIPLY_ADD")
    tree.links.new(noise.outputs["Fac"], jitter.inputs[0])
    jitter.inputs[1].default_value = p["noise_strength"] * 2.0
    jitter.inputs[2].default_value = 1.0 - p["noise_strength"]
    jitter2 = _node(tree, "ShaderNodeMath", (-300, -1000), operation="MULTIPLY_ADD")
    tree.links.new(strokes.outputs["Fac"], jitter2.inputs[0])
    jitter2.inputs[1].default_value = p["stroke_strength"] * 2.0
    tree.links.new(jitter.outputs["Value"], jitter2.inputs[2])
    jitter2.inputs[2].default_value = 0.0
    tree.links.new(jitter.outputs["Value"], jitter2.inputs[2])
    final = _node(tree, "ShaderNodeMix", (400, 200), data_type="RGBA", blend_type="MULTIPLY")
    final.inputs["Factor"].default_value = 1.0
    tree.links.new(screen.outputs["Result"], final.inputs["A"])
    # Offset so strokes darken and lighten around 1.0.
    center = _node(tree, "ShaderNodeMath", (-100, -1000), operation="SUBTRACT")
    tree.links.new(jitter2.outputs["Value"], center.inputs[0])
    center.inputs[1].default_value = p["stroke_strength"]
    tree.links.new(center.outputs["Value"], final.inputs["B"])
    result = final.outputs["Result"]
    if p["foot_darken"] > 0.0:
        pos = _node(tree, "ShaderNodeSeparateXYZ", (-100, -1300))
        tree.links.new(coord.outputs["Object"], pos.inputs["Vector"])
        fade = _node(tree, "ShaderNodeMapRange", (100, -1300))
        fade.inputs["From Min"].default_value = 0.0
        fade.inputs["From Max"].default_value = p["foot_height"]
        fade.inputs["To Min"].default_value = 1.0 - p["foot_darken"]
        fade.inputs["To Max"].default_value = 1.0
        # Object Z: the characters are exported Z-up in Blender space.
        tree.links.new(pos.outputs["Z"], fade.inputs["Value"])
        feet = _node(tree, "ShaderNodeMix", (600, 200), data_type="RGBA", blend_type="MULTIPLY")
        feet.inputs["Factor"].default_value = 1.0
        tree.links.new(result, feet.inputs["A"])
        tree.links.new(fade.outputs["Result"], feet.inputs["B"])
        result = feet.outputs["Result"]
    tree.links.new(result, emit.inputs["Color"])
    return mat


def paint(obj, source="attribute", name=None, emissive=None, **params):
    """Bakes the painted look into a new texture on `obj`.

    source: "attribute" (face colours in 'Col') or the name of an existing
    UV map whose material texture provides the base colours.
    emissive: optional (r,g,b,strength) to make the exported material glow.
    """
    p = dict(DEFAULTS)
    p.update(params)
    name = name or obj.name
    scene = bpy.context.scene
    scene.cycles.samples = p["samples"]

    mesh = obj.data
    paint_uv = mesh.uv_layers.new(name="PaintUV")
    mesh.uv_layers.active = paint_uv
    common.select_only([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.01, area_weight=0.6)
    bpy.ops.uv.pack_islands(margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")

    bake_mat = _build_bake_material(obj, source, p)
    old_materials = [s.material for s in obj.material_slots]
    mesh.materials.clear()
    mesh.materials.append(bake_mat)

    image = bpy.data.images.new(name + "_paint", p["size"], p["size"], alpha=False)
    target = bake_mat.node_tree.nodes.new("ShaderNodeTexImage")
    target.image = image
    bake_mat.node_tree.nodes.active = target
    uv_node = bake_mat.node_tree.nodes.new("ShaderNodeUVMap")
    uv_node.uv_map = "PaintUV"
    bake_mat.node_tree.links.new(uv_node.outputs["UV"], target.inputs["Vector"])

    scene.render.bake.margin = p["margin"]
    scene.render.bake.use_selected_to_active = False
    common.select_only([obj])
    bpy.ops.object.bake(type="EMIT")

    # Final material: painted texture, matte.
    final = bpy.data.materials.new(name + "_painted")
    final.use_nodes = True
    tree = final.node_tree
    bsdf = tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    tex = tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if emissive:
        bsdf.inputs["Emission Color"].default_value = (*emissive[:3], 1)
        bsdf.inputs["Emission Strength"].default_value = emissive[3]
    image.pack()
    mesh.materials.clear()
    mesh.materials.append(final)

    # Keep only the painted UVs so glTF exports one TEXCOORD.
    for layer in list(mesh.uv_layers):
        if layer.name != "PaintUV":
            mesh.uv_layers.remove(layer)
    mesh.uv_layers["PaintUV"].active_render = True
    if "Col" in mesh.color_attributes:
        mesh.color_attributes.remove(mesh.color_attributes["Col"])
    bpy.data.materials.remove(bake_mat)
    for m in old_materials:
        if m is not None and m.users == 0:
            bpy.data.materials.remove(m)
    return final


def flat_material(obj, color, emission=0.0, name="flat"):
    """Plain (unbaked) material, e.g. for glowing eyes."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color[:3], 1)
    bsdf.inputs["Roughness"].default_value = 0.6
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*color[:3], 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return mat
