extends Node3D

## Torch
##
## Crafted light source the player plants with Q. While lit, Shadow
## Imps inside `radius` move at `slow_factor` speed and take
## `burn_damage` every `burn_interval_seconds`. Burns out at the next
## dawn, so torches are a per-night consumable.

@export var radius: float = 3.5
@export var slow_factor: float = 0.45
@export var burn_damage: int = 1
@export var burn_interval_seconds: float = 1.0
## Torches burn out at dawn; a Glow Lantern's aura (same script) does not.
@export var burns_out_at_dawn: bool = true

var _burn_timer: float = 0.0
var _is_burning_out: bool = false


func _ready() -> void:
	# Inside a build-mode ghost (the Glow Lantern preview) stay inert.
	if owner != null and owner.has_meta(&"build_ghost"):
		set_physics_process(false)
		return
	add_to_group("torches")
	if burns_out_at_dawn:
		TimeManager.dawn_started.connect(_on_dawn_started)


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
	_is_burning_out = true
	remove_from_group("torches")
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.2, 0.2, 0.2), 1.0)
	tween.tween_callback(queue_free)
