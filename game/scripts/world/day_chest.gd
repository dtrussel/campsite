class_name DayChest
extends Node3D

## DayChest
##
## A small moonlit chest at the map edge, where a
## mob lane meets the trees. GameManager places at most one a run, on
## the run's `day_chest_day` (RunConfig rolls it: half the runs get
## one). Leo or Nela open it just by walking up to it, like a pickup,
## and it gives the page of Mum's journal it holds (Journal.find), with
## a toast naming the page. It is a day thing: left unopened, it fades
## when the night comes. It has no collision, so it never blocks a
## path.
##
## The model is the Storage Crate's chest until the team's art arrives.

## The chest was opened and its page found; the HUD names the page.
signal opened(page: JournalPage)

const MODEL: PackedScene = preload("res://assets/custom/storage_crate.glb")
## Where a chest can stand: just beside each lane, near the edge of the
## play area (x, z). Lanes are kept clear of anything solid, so every
## spot can be walked to.
const SPOTS: Array[Vector2] = [
	Vector2(1.8, -17.5), Vector2(17.5, 1.8), Vector2(-2.2, 17.0), Vector2(-17.5, -1.8),
]
const OPEN_RADIUS: float = 1.5
const GLOW: Color = Color(0.75, 0.85, 1.0)

## The JournalPage id inside.
var page_id: StringName = &""

var _opened: bool = false
## Opened, or faded at nightfall: it waits no longer.
var _gone: bool = false
var _time: float = 0.0
var _visual: Node3D = null


## Places a chest holding `page` at one of SPOTS in the camp's world
## (beside the campfire's parent). Returns null
## (and places nothing) when there is no page left to find or no camp.
static func place(tree: SceneTree, page: JournalPage) -> DayChest:
	var fire: Node = tree.get_first_node_in_group("base_core")
	if page == null or fire == null or fire.get_parent() == null:
		return null
	var chest: DayChest = DayChest.new()
	chest.page_id = page.id
	var spot: Vector2 = SPOTS[randi() % SPOTS.size()]
	fire.get_parent().add_child(chest)
	chest.global_position = Vector3(spot.x, 0.0, spot.y)
	chest.look_at(Vector3.ZERO, Vector3.UP, true)  # its front to the camp
	PlaytestLog.write("day_chest_placed page=%s day=%d" % [page.id, TimeManager.day_number])
	return chest


func _ready() -> void:
	add_to_group("day_chest")
	_visual = Node3D.new()
	add_child(_visual)
	var model: Node3D = MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * 0.7
	_visual.add_child(model)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = GLOW
	light.light_energy = 1.4
	light.omni_range = 3.0
	light.position = Vector3(0, 1.0, 0)
	_visual.add_child(light)
	TimeManager.night_started.connect(_on_night_started)


func _physics_process(delta: float) -> void:
	if _gone:
		return
	_time += delta
	_visual.scale = Vector3.ONE * (1.0 + sin(_time * 3.0) * 0.04)  # a soft pulse, to be seen
	var openers: Array = get_tree().get_nodes_in_group("companions")
	openers.append(get_tree().get_first_node_in_group("player"))
	for node in openers:
		var hero: Node3D = node as Node3D
		if hero == null or (hero is Hero and (hero as Hero).is_down()):
			continue
		var offset: Vector3 = hero.global_position - global_position
		offset.y = 0.0
		if offset.length() <= OPEN_RADIUS:
			open()
			return


func is_opened() -> bool:
	return _opened


## Opens the chest: its page is found, `opened` announces it, and the
## chest fades away.
func open() -> void:
	if _gone:
		return
	_opened = true
	_gone = true
	var page: JournalPage = Journal.get_page(page_id)
	Journal.find(page_id)
	PlaytestLog.write("day_chest_opened page=%s" % page_id)
	AudioManager.play_sfx(&"level_up")
	if page != null:
		opened.emit(page)
	_vanish()


func _vanish() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.05, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _on_night_started(_day: int) -> void:
	if not _gone:
		_gone = true  # a day chest waits only a day
		PlaytestLog.write("day_chest_missed page=%s" % page_id)
		_vanish()
