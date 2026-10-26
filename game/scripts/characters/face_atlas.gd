class_name FaceAtlas
extends Resource

## FaceAtlas
##
## A painted head's face in every state it can show: one cell per state
## (brows, eyes, nose and mouth) in `texture`, painted and baked by the
## model's builder (art/characters/face_atlas.py, which writes this
## resource next to the model). CharacterVisual puts the shown state's
## cell over the `window` of the head mesh's face surface
## (painted_face.gdshader): a blink, and the expressions for a hit, a
## cheer and being down.

## The states every kid's atlas has (Mum's has the first two: she only
## blinks).
const STATES: Array[StringName] = [&"open", &"closed", &"happy", &"hurt", &"dazed"]
## The neutral face and the blink.
const NEUTRAL: StringName = &"open"
const BLINK: StringName = &"closed"

@export var texture: Texture2D
## The model's head mesh and the material of its face surface (the
## head's front faces inside the window).
@export var mesh: String = ""
@export var material: String = ""
## The states, in the order of `cell_origins`.
@export var states: PackedStringArray = PackedStringArray()
## The window in the face surface's UV2 (the front-projected face plane).
@export var window: Rect2 = Rect2()
## Each cell's top-left corner and their common size, in atlas UV.
@export var cell_size: Vector2 = Vector2.ZERO
@export var cell_origins: PackedVector2Array = PackedVector2Array()


func has_state(state: StringName) -> bool:
	return states.has(String(state))


## Where `state`'s cell starts in the atlas (the neutral one if the
## atlas lacks it).
func cell_origin(state: StringName) -> Vector2:
	var at: int = states.find(String(state))
	if at == -1:
		at = maxi(states.find(String(NEUTRAL)), 0)
	return cell_origins[at] if at < cell_origins.size() else Vector2.ZERO


## What is wrong with the atlas's data, if anything (the validator).
func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if texture == null:
		found.append("has no texture")
	if mesh == "" or material == "":
		found.append("names no head mesh or face material")
	if not has_state(NEUTRAL) or not has_state(BLINK):
		found.append("lacks the open and closed (blink) states")
	if cell_origins.size() != states.size():
		found.append("has %d cells for %d states" % [cell_origins.size(), states.size()])
	if window.size.x <= 0.0 or window.size.y <= 0.0 or cell_size.x <= 0.0 or cell_size.y <= 0.0:
		found.append("has an empty window or cell")
	for origin in cell_origins:
		if origin.x < 0.0 or origin.y < 0.0 or origin.x + cell_size.x > 1.0001 or origin.y + cell_size.y > 1.0001:
			found.append("has a cell outside its texture")
			break
	return found
