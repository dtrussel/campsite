class_name HeroDefinition
extends Resource

## HeroDefinition
##
## One playable hero. A hero can fill either role: the
## player character (player_controller.gd) or the AI companion
## (companion_controller.gd). Both role shells read their body, stats
## and combat style from here, so a hero plays the same way in either
## role. Stored as a .tres under res://resources/heroes/ and listed by
## HeroRoster.

## The longest wind-up an attack may have: its contact frame comes at
## most this long (game seconds, at play speed) after the attack starts.
const WIND_UP_CAP_SECONDS: float = 0.1

@export var id: StringName = &""
@export var display_name: String = ""
## One line for the hero select card.
@export var tagline: String = ""
@export var portrait: Texture2D
@export var ui_color: Color = Color(1, 0.93, 0.7, 1)

@export_group("Body")
@export var model_scene: PackedScene
@export var model_scale: float = 0.7
## CharacterVisual clips (logical state -> clip name).
@export var clips: Dictionary = {}
## Seconds into the `attack` clip (at speed 1) of its contact frame,
## where the swing lands or the pebble leaves the sling (Hero.attack).
## 0 = no contact frame: the hit comes the moment the attack starts.
## At play speed it is at most WIND_UP_CAP_SECONDS (the validator).
@export var attack_contact_time: float = 0.0
## Idle fidgets (states in `clips`): one plays now and then while the
## hero stands idle (CharacterVisual, FidgetScheduler).
@export var fidgets: Array[StringName] = []
## The model's spring chains (hair, pack, hanging gear) and their
## tuning: CharacterVisual swings them (SpringChainModifier) in either
## role and on hero select.
@export var spring_chains: Array[SpringChain] = []
## The head's face atlas (the model builder writes it beside the model):
## CharacterVisual blinks the face and shows the hit, cheer and down
## expressions with it, in either role and on hero select.
@export var face_atlas: FaceAtlas
## The ground speeds (m/s) the run (`move`) and the walk clips are
## authored for, each its stride over its length (CharacterVisual scales
## their playback by the real speed). For a hand-made cycle they are the
## clip script's (the validator checks); 0 plays the walk at 1x.
@export var reference_speed: float = 7.0
@export var walk_reference_speed: float = 0.0
@export var step_distance: float = 1.1
@export var capsule_height: float = 1.2
@export var hurt_sfx: StringName = &"player_hurt"
## Model parts put away while a hand tool (the build hammer) is out.
@export var tool_hidden_parts: PackedStringArray = PackedStringArray()
## The model's body-and-clothes mesh, which the badge outfit tints
## colour (Cosmetics).
@export var outfit_mesh: String = ""

@export_group("Combat")
@export var stats: CharacterStatsDefinition
@export var move_speed: float = 4.0
@export var companion_move_speed: float = 3.9
@export var attack_range: float = 2.0
@export var companion_attack_range: float = 2.0
@export var attack_cooldown: float = 0.65
@export var companion_attack_cooldown: float = 0.75
## Ranged heroes fire a pebble (PebbleShot); the hit lands on impact.
@export var ranged: bool = false
## A melee target still counts as in reach at the contact frame up to
## this many times the attack's reach (it may have stepped back a bit).
@export var contact_reach_slack: float = 1.4

@export_group("Action speeds")
## How fast gameplay plays each action clip (x): the attack by role
## (the wind-up cap is checked at the slower one), the hit reaction, the
## level-up cheer, and gathering (the player's chop or pick at a node,
## the companion's gather). The clip checks read them (action_play_speeds).
@export var attack_play_speed: float = 1.5
@export var companion_attack_play_speed: float = 1.45
@export var hit_play_speed: float = 1.4
@export var cheer_play_speed: float = 1.2
@export var gather_play_speed: float = 1.5
@export var companion_gather_play_speed: float = 1.3

@export_group("Signature")
## The hero's signature tool path (tool tiers), tier 1 first: each tier
## is made at the Crafting Table once the one before it is owned.
@export var signature_tiers: Array[ToolTier] = []

@export_group("Select screen")
## 1-3 pips per row on the hero card.
@export_range(1, 3) var rating_health: int = 2
@export_range(1, 3) var rating_power: int = 2
@export_range(1, 3) var rating_reach: int = 2


## The attack clip's play speed in a role.
func attack_speed(companion: bool) -> float:
	return companion_attack_play_speed if companion else attack_play_speed


## Logical state -> the speed gameplay plays it at, in a role: this
## hero's action speeds, the build beat's, and 1x for going down and
## getting up (play_final and unlock).
func action_play_speeds(companion: bool = false) -> Dictionary:
	return {
		&"attack": attack_speed(companion), &"hit": hit_play_speed, &"death": 1.0, &"getup": 1.0,
		&"cheer": cheer_play_speed, &"gather": companion_gather_play_speed, &"chop": gather_play_speed,
		&"pick": gather_play_speed, &"tinker": BuildBeat.FETCH_SPEED, &"hammer": BuildBeat.HAMMER_SPEED,
	}


## How many tiers the hero's signature tool has.
func tier_count() -> int:
	return signature_tiers.size()


## Tier `n` of the signature tool (1 is the first craft), or null.
func tier(n: int) -> ToolTier:
	return signature_tiers[n - 1] if n >= 1 and n <= signature_tiers.size() else null


## The tier that `recipe_id` makes (1-based), or 0 if it is not one of
## this hero's tiers.
func tier_of_recipe(recipe_id: StringName) -> int:
	for i in signature_tiers.size():
		if signature_tiers[i] != null and signature_tiers[i].recipe == recipe_id:
			return i + 1
	return 0
