extends Node

## PerkManager
##
## Autoload that owns the perk cards each character has taken (perk
## cards, .scratch/perk-cards). When the player's hero levels up it
## deals up to three cards and opens the PerkPicker in the HUD; the
## gameplay hooks then ask it about the taken perks:
##
##   PerkManager.multiplier(actor, &"gather_time")   # stat_mult, 1.0 if none
##   PerkManager.has_flag(actor, &"stand_firm")       # flag
##   PerkManager.on_hit_perks(actor, &"pebble")       # on_hit
##
## The cards are PerkDefinition .tres files under res://resources/perks/.

signal perk_taken(character: Node, perk: PerkDefinition)
signal picker_opened(character: Node, picker: PerkPicker)
signal picker_closed(character: Node)

const PERKS_DIR: String = "res://resources/perks/"
const OFFER_SIZE: int = 3

## Real seconds the picker waits before it takes the first card itself.
## 0 (or less) skips the picker: the first card is taken at once. Tests
## and the balance sim use that so they never stall on the picker.
var auto_pick_seconds: float = 10.0
## Deals the cards. Seed it for a repeatable deal.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _definitions: Array[PerkDefinition] = []
var _taken: Dictionary = {}  # Node -> Array[StringName], in the order taken
var _picker: PerkPicker = null
var _picker_character: Node = null
## Level-ups that came while the picker was open, per character.
var _pending: Dictionary = {}  # Node -> int


func _ready() -> void:
	rng.randomize()
	for res in DefinitionLoader.load_all(PERKS_DIR):
		var perk: PerkDefinition = res as PerkDefinition
		if perk != null:
			_definitions.append(perk)
	_definitions.sort_custom(func(a: PerkDefinition, b: PerkDefinition) -> bool: return String(a.id) < String(b.id))
	ProgressionManager.level_up.connect(_on_level_up)


# --- Definitions ---------------------------------------------------------------

func definitions() -> Array[PerkDefinition]:
	return _definitions


func get_definition(id: StringName) -> PerkDefinition:
	for perk in _definitions:
		if perk.id == id:
			return perk
	return null


# --- Taking perks ----------------------------------------------------------------

## Up to `n` distinct cards `character` can take now, in random order:
## its hero's pool plus the shared and sibling cards, minus the ones
## already taken that do not stack. Empty when the pool is used up.
func offer(character: Node, n: int = OFFER_SIZE) -> Array[PerkDefinition]:
	var hero_id: StringName = _hero_id(character)
	var pool: Array[PerkDefinition] = []
	for perk in _definitions:
		if perk.is_for_hero(hero_id) and (perk.stacks or not has(character, perk.id)):
			pool.append(perk)
	# Fisher-Yates with our own rng, so a seeded deal repeats.
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: PerkDefinition = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	return pool.slice(0, maxi(n, 0))


## Gives `character` the perk `id`. False if the id is unknown, or it is
## already held and does not stack.
func take(character: Node, id: StringName) -> bool:
	var perk: PerkDefinition = get_definition(id)
	if character == null or perk == null:
		return false
	if has(character, id) and not perk.stacks:
		return false
	_list(character).append(id)
	PlaytestLog.write("perk_taken who=%s id=%s" % [_hero_id(character), id])
	perk_taken.emit(character, perk)
	return true


func has(character: Node, id: StringName) -> bool:
	return _taken.has(character) and (_taken[character] as Array).has(id)


## How many copies of `id` the character holds (stacking perks).
func count(character: Node, id: StringName) -> int:
	return (_taken[character] as Array).count(id) if _taken.has(character) else 0


## The taken perk ids, in the order taken (one entry per copy). A copy:
## the save writes it.
func perks_of(character: Node) -> Array[StringName]:
	var out: Array[StringName] = []
	if _taken.has(character):
		out.assign(_taken[character])
	return out


## Sets the character's perks from a save, quietly: no picker, no
## perk_taken. Unknown ids (a perk since removed) are skipped.
func restore(character: Node, ids: Array) -> void:
	if character == null:
		return
	var list: Array[StringName] = _list(character)
	list.clear()
	for raw in ids:
		var perk: PerkDefinition = get_definition(StringName(str(raw)))
		if perk != null and (perk.stacks or not list.has(perk.id)):
			list.append(perk.id)


## Forgets every character's perks and closes the picker (new run).
func reset() -> void:
	close_picker()
	_taken.clear()
	_pending.clear()


# --- Effect queries ----------------------------------------------------------------

## The product of every taken `stat_mult` perk on `stat` (each copy
## counts). 1.0 when there are none.
func multiplier(character: Node, stat: StringName) -> float:
	var result: float = 1.0
	for perk in _held(character):
		if perk.effect_kind == &"stat_mult" and perk.stat == stat:
			result *= perk.value
	return result


## True if a taken `flag` perk sets `flag`.
func has_flag(character: Node, flag: StringName) -> bool:
	for perk in _held(character):
		if perk.effect_kind == &"flag" and perk.flag_name() == flag:
			return true
	return false


## The taken `on_hit` perks that fire on a hit from `source` (&"melee" or
## &"pebble"), one entry per copy.
func on_hit_perks(character: Node, source: StringName) -> Array[PerkDefinition]:
	var out: Array[PerkDefinition] = []
	for perk in _held(character):
		if perk.effect_kind == &"on_hit" and (perk.hit_source == &"any" or perk.hit_source == source):
			out.append(perk)
	return out


# --- The picker ---------------------------------------------------------------------

## Deals cards to `character` and lets the player choose. With
## auto_pick_seconds <= 0, or no HUD to show it in, the first card is
## taken at once. Nothing happens when the pool is empty. If a picker is
## already open, this one waits for it.
func open_picker(character: Node) -> void:
	if is_picking():
		_pending[character] = int(_pending.get(character, 0)) + 1
		return
	var cards: Array[PerkDefinition] = offer(character)
	if cards.is_empty():
		return
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if auto_pick_seconds <= 0.0 or hud == null or not hud.has_method("show_perk_picker"):
		take(character, cards[0].id)
		return
	_picker = hud.call("show_perk_picker", cards, auto_pick_seconds) as PerkPicker
	_picker_character = character
	_picker.closed.connect(_on_picker_closed.bind(character), CONNECT_ONE_SHOT)
	PlaytestLog.write("perk_picker cards=%s" % ",".join(cards.map(func(p: PerkDefinition) -> String: return String(p.id))))
	picker_opened.emit(character, _picker)


func is_picking() -> bool:
	return _picker != null and is_instance_valid(_picker) and not _picker.is_closing()


## The open picker, or null.
func picker() -> PerkPicker:
	return _picker if is_picking() else null


## Closes the picker without taking a card (the run ended).
func close_picker() -> void:
	if is_picking():
		_picker.dismiss()
	_picker = null
	_picker_character = null


func _on_picker_closed(perk: PerkDefinition, character: Node) -> void:
	_picker = null
	_picker_character = null
	if perk != null and is_instance_valid(character):
		take(character, perk.id)
	if is_instance_valid(character):
		picker_closed.emit(character)
	# Another level-up came while it was open: deal again.
	if is_instance_valid(character) and int(_pending.get(character, 0)) > 0 and GameManager.is_playing():
		_pending[character] = int(_pending[character]) - 1
		open_picker(character)
	else:
		_pending.erase(character)


func _on_level_up(character: Node, _new_level: int) -> void:
	if ProgressionManager.is_restoring or character == null:
		return
	if character.is_in_group("player"):
		open_picker(character)
	# The companion takes a random card by itself (ticket 06).


# --- Helpers -------------------------------------------------------------------------

func _hero_id(character: Node) -> StringName:
	var hero: HeroDefinition = character.get("hero") as HeroDefinition if character != null else null
	return hero.id if hero != null else &""


func _list(character: Node) -> Array[StringName]:
	if not _taken.has(character):
		var list: Array[StringName] = []
		_taken[character] = list
		if not character.tree_exiting.is_connected(_on_character_exiting):
			character.tree_exiting.connect(_on_character_exiting.bind(character))
	return _taken[character]


func _held(character: Node) -> Array[PerkDefinition]:
	var out: Array[PerkDefinition] = []
	if not _taken.has(character):
		return out
	for id in _taken[character]:
		var perk: PerkDefinition = get_definition(id)
		if perk != null:
			out.append(perk)
	return out


func _on_character_exiting(character: Node) -> void:
	_taken.erase(character)
	_pending.erase(character)
