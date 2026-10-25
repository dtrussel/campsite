class_name HeroBody
extends RefCounted

## HeroBody
##
## Dresses a role shell (PlayerBoy.tscn or Sibling.tscn) as a hero:
## the Visual's model, scale and clips, the badge outfit
## tint the hero wears (Cosmetics), and the collision capsule. Called
## from the shell's _enter_tree, before the Visual child builds its
## model in its own _ready.


static func apply(character: Node3D, hero: HeroDefinition) -> void:
	var visual: CharacterVisual = character.get_node_or_null("Visual") as CharacterVisual
	if visual != null and visual.model == null:
		visual.model_scene = hero.model_scene
		visual.model_scale = hero.model_scale
		if not hero.clips.is_empty():
			visual.clips = hero.clips.duplicate()
		visual.contact_times = {&"attack": hero.attack_contact_time} if hero.attack_contact_time > 0.0 else {}
		visual.reference_speed = hero.reference_speed
		visual.step_distance = hero.step_distance
		visual.tool_hidden_parts = hero.tool_hidden_parts
		visual.outfit_mesh = hero.outfit_mesh
		visual.outfit_tint = Cosmetics.outfit_tint(hero.id)
	var collision: CollisionShape3D = character.get_node_or_null("Collision") as CollisionShape3D
	if collision != null and collision.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = (collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		capsule.height = hero.capsule_height
		collision.shape = capsule
		collision.position.y = hero.capsule_height * 0.5
