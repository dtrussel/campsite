class_name Torch
extends Node3D

## Torch
##
## Crafted light source the player plants with Q. While lit, Shadow
## Imps inside `radius` move at `slow_factor` speed and take
## `burn_damage` every `burn_interval_seconds`. Burns out at the next
## dawn, so torches are a per-night consumable.
##
## The Ember Heart perk (perk cards, ticket 03): a torch its holder
## plants lasts one more dawn and its radius, ring and light grow by the
## perk's `value`. See kindle(). Such a torch outlives the dawn autosave,
## so the save keeps it (save_entry / rebuild, listed by TorchSaves).

@export var radius: float = 3.5
@export var slow_factor: float = 0.45
@export var burn_damage: int = 1
@export var burn_interval_seconds: float = 1.0
## Torches burn out at dawn; a Glow Lantern's aura (same script) does not.
@export var burns_out_at_dawn: bool = true
## Dawns it sees before it goes out (Ember Heart adds one).
@export var dawns_to_burn: int = 1

const EMBER_HEART: StringName = &"ember_heart"
## Every lit torch (and Glow Lantern aura); a torch leaves it as it goes out.
const GROUP: StringName = &"torches"
const SCENE_PATH: String = "res://scenes/buildings/Torch.tscn"

var _burn_timer: float = 0.0
var _is_burning_out: bool = false


func _ready() -> void:
	# Inside a build-mode ghost (the Glow Lantern preview) stay inert.
	if owner != null and owner.has_meta(&"build_ghost"):
		set_physics_process(false)
		return
	add_to_group(GROUP)
	if burns_out_at_dawn:
		TimeManager.dawn_started.connect(_on_dawn_started)


## Lit by `placer`: applies the placer's torch perks (Ember Heart).
func kindle(placer: Node) -> void:
	if not PerkManager.has_flag(placer, EMBER_HEART):
		return
	var perk: PerkDefinition = PerkManager.get_definition(EMBER_HEART)
	dawns_to_burn += 1
	set_radius(radius * (perk.value if perk != null else 1.0))


## The torch's line in the save file: its place, dawns left and radius.
func save_entry() -> Dictionary:
	var p: Vector3 = global_position
	return {"pos": [p.x, p.y, p.z], "dawns": dawns_to_burn, "radius": radius}


## Plants the torch `entry` (from save_entry) again under `parent`, or
## null when it had no dawns left.
static func rebuild(entry: Dictionary, parent: Node) -> Torch:
	if int(entry.get("dawns", 0)) <= 0 or not entry.get("pos") is Array:
		return null
	var torch: Torch = (load(SCENE_PATH) as PackedScene).instantiate() as Torch
	parent.add_child(torch)
	var pos: Array = entry["pos"]
	torch.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	torch.dawns_to_burn = int(entry["dawns"])
	torch.set_radius(float(entry.get("radius", torch.radius)))
	return torch


## Sets the reach, and scales the ring and the fire's light to match.
func set_radius(new_radius: float) -> void:
	if new_radius <= 0.0 or is_equal_approx(new_radius, radius):
		return
	var factor: float = new_radius / radius
	radius = new_radius
	var ring: Node3D = get_node_or_null("Radius") as Node3D
	if ring != null:
		ring.scale = Vector3(ring.scale.x * factor, ring.scale.y, ring.scale.z * factor)
	var fire: Node = get_node_or_null("Fire")
	if fire != null and fire.has_method("set_light_range"):
		fire.call("set_light_range", float(fire.get("light_range")) * factor)


func affects(point: Vector3) -> bool:
	if _is_burning_out:
		return false
	var offset: Vector3 = point - global_position
	offset.y = 0.0
	return offset.length() <= radius


func _physics_process(delta: float) -> void:
	if _is_burning_out:
		return
	_burn_timer += delta
	if _burn_timer < burn_interval_seconds:
		return
	_burn_timer = 0.0
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob: Node3D = node as Node3D
		if mob != null and affects(mob.global_position) and mob.has_method("take_damage"):
			mob.take_damage(burn_damage, null)


func _on_dawn_started(_day_number: int) -> void:
	dawns_to_burn -= 1
	if dawns_to_burn <= 0:
		snuff()


## Goes out: at dawn, or blown out by the Moon-Eater (feature 038).
func snuff() -> void:
	if _is_burning_out:
		return
	_is_burning_out = true
	remove_from_group(GROUP)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.2, 0.2, 0.2), 1.0)
	tween.tween_callback(queue_free)
