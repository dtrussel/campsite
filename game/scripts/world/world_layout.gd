class_name WorldLayout
extends RefCounted

## WorldLayout
##
## The map's plan (feature 032), in one place so the dressing, the
## ground shader and the resource placement agree. The camp sits in a
## forest clearing. The four mob lanes run in along the axes as open,
## trodden corridors. The four corners between them are themed groves,
## each with the resource it supplies, its own ground, its own landmark
## and its own stretch of forest wall:
##
##   NW  Pine Grove     pines, needle litter, ferns, an old giant pine
##   NE  Stony Pond     a pond with reeds, rocks and clay banks
##   SW  Woodlot        broadleaf trees, cut stumps, a woodpile
##   SE  Fairy Ring     berry bushes, flowers, a giant old stump in a ring of toadstools
##
## Footpaths lead from the camp yard to each grove; the old road runs
## out south along the south lane. Positions are (x, z); north is -z,
## and the game camera looks north.

enum Zone { CAMP, MEADOW, PINE_GROVE, STONY_POND, WOODLOT, BERRY_HOLLOW }

const CAMP_RADIUS: float = 5.8
## Lane corridors along the axes stay clear of anything solid.
const LANE_HALF_WIDTH: float = 3.0
const PLAY_EXTENT: float = 21.0

## Grove: [zone, centre, radius]. The ground shader paints each one.
const GROVES: Array = [
	[Zone.PINE_GROVE, Vector2(-11.0, -10.5), 7.5],
	[Zone.STONY_POND, Vector2(11.5, -11.0), 7.0],
	[Zone.WOODLOT, Vector2(-11.0, 10.5), 7.5],
	[Zone.BERRY_HOLLOW, Vector2(11.0, 10.5), 7.5],
]

const POND_CENTRE: Vector2 = Vector2(12.0, -12.0)
const POND_RADIUS: float = 3.1

## Paths: [width, points]. The first is the old road out south.
const PATHS: Array = [
	[0.85, [Vector2(0.4, 4.6), Vector2(1.1, 8.0), Vector2(0.7, 11.0), Vector2(-0.5, 14.0),
		Vector2(-0.9, 17.0), Vector2(0.1, 20.5), Vector2(0.6, 25.0)]],
	[0.5, [Vector2(-2.6, -5.0), Vector2(-4.6, -6.4), Vector2(-6.4, -7.4), Vector2(-8.0, -8.4)]],
	[0.5, [Vector2(5.0, -3.0), Vector2(6.8, -4.6), Vector2(8.0, -7.0), Vector2(9.0, -9.0)]],
	[0.5, [Vector2(-4.0, 4.3), Vector2(-5.6, 5.4), Vector2(-7.0, 6.4), Vector2(-8.4, 7.4)]],
	[0.5, [Vector2(4.1, 4.3), Vector2(5.5, 5.9), Vector2(7.3, 7.1), Vector2(8.8, 8.6)]],
]

## Lane directions (unit x, z), matching the MobSpawner markers.
const LANES: Array = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]


## Distance from `p` to the nearest path centre line minus that path's
## half-width: negative on a path.
static func path_distance(p: Vector2) -> float:
	var best: float = INF
	for path in PATHS:
		var points: Array = path[1]
		for i in range(points.size() - 1):
			var d: float = _segment_distance(p, points[i], points[i + 1]) - float(path[0])
			best = minf(best, d)
	return best


static func on_path(p: Vector2, margin: float = 0.0) -> bool:
	return path_distance(p) < margin


## True inside a lane corridor (beyond the camp yard).
static func in_lane(p: Vector2, margin: float = 0.0) -> bool:
	if p.length() < CAMP_RADIUS:
		return false
	return absf(p.x) < LANE_HALF_WIDTH + margin or absf(p.y) < LANE_HALF_WIDTH + margin


static func in_pond(p: Vector2, margin: float = 0.0) -> bool:
	return p.distance_to(POND_CENTRE) < POND_RADIUS + margin


## The grove `p` belongs to (by corner), or MEADOW / CAMP.
static func zone_at(p: Vector2) -> Zone:
	if p.length() < CAMP_RADIUS:
		return Zone.CAMP
	for grove in GROVES:
		if p.distance_to(grove[1]) < float(grove[2]):
			return grove[0]
	return Zone.MEADOW


## The corner zone of the quadrant `p` lies in, ignoring distance.
static func corner_zone(p: Vector2) -> Zone:
	if p.y < 0.0:
		return Zone.PINE_GROVE if p.x < 0.0 else Zone.STONY_POND
	return Zone.WOODLOT if p.x < 0.0 else Zone.BERRY_HOLLOW


## Pushes the layout to the painted ground shader.
static func apply_to_ground(material: ShaderMaterial) -> void:
	var segments: Array[Vector4] = []
	var widths: PackedFloat32Array = PackedFloat32Array()
	for path in PATHS:
		var points: Array = path[1]
		for i in range(points.size() - 1):
			segments.append(Vector4(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y))
			widths.append(float(path[0]))
	var groves: Array[Vector4] = []
	for grove in GROVES:
		groves.append(Vector4(grove[1].x, grove[1].y, grove[2], float(grove[0])))
	material.set_shader_parameter("path_segments", segments)
	material.set_shader_parameter("path_widths", widths)
	material.set_shader_parameter("path_count", segments.size())
	material.set_shader_parameter("groves", groves)
	material.set_shader_parameter("pond", Vector3(POND_CENTRE.x, POND_CENTRE.y, POND_RADIUS))
	material.set_shader_parameter("clearing_radius", CAMP_RADIUS - 0.4)


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
