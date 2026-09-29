class_name LoadingScreen
extends CanvasLayer

## LoadingScreen
##
## The team's key art (feature 029) shown while the camp loads after
## Play / Continue / Again, instead of a frozen frame. It sits on the
## root (so it survives the scene change), loads the gameplay scene on a
## background thread, swaps it in, and fades away once the camp has had
## a moment to build. A tip for kids runs along the bottom.
##
##   LoadingScreen.load_scene("res://scenes/main/Main.tscn")

## Shown at least this long, so the art never just flashes by.
const MIN_SECONDS: float = 1.2
const FADE_IN: float = 0.2
const FADE_OUT: float = 0.35

## The team's paintings (features 029-030), each with tips that fit it:
## [art, [[tip, icon], ...]]. Short, simple words for young players.
const SCREENS: Array = [
	["res://assets/ui/key_art.webp", [
		["Give Nela a job: she can gather, guard and repair.", "res://assets/icons/portrait_nela.png"],
		["Hurt? Press R to eat berries and heal.", "res://assets/icons/berries.png"],
		["Keep the campfire burning all night long!", "res://assets/icons/campfire.png"],
	]],
	["res://assets/ui/loading_imp.webp", [
		["Torches slow the Shadow Imps down.", "res://assets/icons/torch.png"],
		["Glow Lanterns zap imps that come too close.", "res://assets/icons/lantern.png"],
		["Imps love the campfire: build fences around it!", "res://assets/icons/fence.png"],
	]],
	["res://assets/ui/loading_beast.webp", [
		["Watch the Bramble Beast's fists: step away before the SLAM!", ""],
		["Bramble Beasts smash fences first. Reinforced Walls last longer.", "res://assets/icons/stone.png"],
	]],
	["res://assets/ui/loading_gremlin.webp", [
		["Build a Storage Crate so Mushroom Gremlins can't grab everything.", "res://assets/icons/crate.png"],
		["Catch a gremlin to get your things back!", "res://assets/icons/mushrooms.png"],
	]],
]

## The picture shown last time, so the next load shows another one.
static var _last_screen: int = -1

var _path: String = ""
var _root: Control = null
var _art: TextureRect = null
var _bar: ProgressBar = null
var _elapsed: float = 0.0
var _screen: int = -1
var _swapped: bool = false
var _finishing: bool = false


## Shows the loading screen and switches to `path` when it has loaded.
static func load_scene(path: String) -> LoadingScreen:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var screen: LoadingScreen = LoadingScreen.new()
	screen._path = path
	tree.root.add_child(screen)
	return screen


## A still copy for screenshots and the validator: no loading.
## `index` picks the painting (-1 = random).
static func preview(progress: float = 0.6, index: int = -1) -> LoadingScreen:
	var screen: LoadingScreen = LoadingScreen.new()
	screen._screen = index
	screen._build()
	screen._bar.value = progress
	screen.set_process(false)
	return screen


func _ready() -> void:
	if _root == null:
		_build()
	if _path == "":
		return
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, FADE_IN)
	if ResourceLoader.load_threaded_request(_path) != OK:
		push_warning("LoadingScreen: threaded load failed, loading %s directly" % _path)
		get_tree().change_scene_to_file(_path)
		_swapped = true


func _process(delta: float) -> void:
	if _path == "":
		return
	_elapsed += delta
	# The slowest possible zoom, for a little life.
	_art.scale = Vector2.ONE * (1.0 + minf(_elapsed, 6.0) * 0.007)
	if not _swapped:
		var progress: Array = []
		var status: int = ResourceLoader.load_threaded_get_status(_path, progress)
		if not progress.is_empty():
			_bar.value = maxf(_bar.value, float(progress[0]) * 0.9)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene: PackedScene = ResourceLoader.load_threaded_get(_path) as PackedScene
			get_tree().change_scene_to_packed(scene)
			_swapped = true
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("LoadingScreen: could not load %s" % _path)
			get_tree().change_scene_to_file(_path)
			_swapped = true
		return
	_bar.value = minf(1.0, _bar.value + delta * 0.8)
	if not _finishing and _elapsed >= MIN_SECONDS and _bar.value >= 1.0:
		_finish()


func _finish() -> void:
	_finishing = true
	# Two frames for the camp to build its dressing under the cover.
	await get_tree().process_frame
	await get_tree().process_frame
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE_OUT)
	tween.tween_callback(queue_free)


func _build() -> void:
	_root = Control.new()
	UiKit.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing clicks through
	_root.theme = UiKit.theme()
	add_child(_root)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.03, 0.03, 0.06)
	UiKit.full_rect(backdrop)
	_root.add_child(backdrop)

	if _screen < 0 or _screen >= SCREENS.size():
		_screen = _pick_screen()
	var entry: Array = SCREENS[_screen]
	_art = TextureRect.new()
	_art.texture = load(String(entry[0])) as Texture2D
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	UiKit.full_rect(_art)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.resized.connect(func() -> void: _art.pivot_offset = _art.size * 0.5)
	_root.add_child(_art)

	# A dark band along the bottom so the text reads over the painting.
	var shade: TextureRect = TextureRect.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0, 0.02, 0.05, 0.0))
	gradient.set_color(1, Color(0, 0.02, 0.05, 0.88))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -190
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var column: VBoxContainer = UiKit.vbox(10)
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.custom_minimum_size = Vector2(760, 0)
	column.position = Vector2(-380, -128)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)

	var heading: Label = UiKit.title("Loading the camp...", 30, UiKit.COLOR_GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(760, 10)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = UiKit.COLOR_GOLD
	fill.set_corner_radius_all(4)
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.06, 0.08, 0.85)
	back.border_color = UiKit.COLOR_GOLD_DARK
	back.set_border_width_all(1)
	back.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	column.add_child(_bar)

	var tips: Array = entry[1]
	var tip: Array = tips[randi() % tips.size()]
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	if String(tip[1]) != "" and ResourceLoader.exists(String(tip[1])):
		var icon: TextureRect = TextureRect.new()
		icon.texture = load(String(tip[1])) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(40, 40)
		row.add_child(icon)
	var text: Label = UiKit.label(String(tip[0]), 22, UiKit.COLOR_GOLD_LIGHT)
	text.add_theme_constant_override("outline_size", 6)
	text.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 1))
	row.add_child(text)


## A random painting, never the same as last time.
static func _pick_screen() -> int:
	var index: int = randi() % SCREENS.size()
	if SCREENS.size() > 1 and index == _last_screen:
		index = (index + 1 + randi() % (SCREENS.size() - 1)) % SCREENS.size()
	_last_screen = index
	return index

