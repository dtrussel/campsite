class_name SpringChain
extends Resource

## SpringChain
##
## One spring chain's bones and tuning (a hero's hair lock, backpack or
## hanging gear): the model builder adds the bones and weights the part
## to them (art/characters/chibi.py, add_chain), no clip keys them, and
## SpringChainModifier swings them from the body's motion. Listed on
## HeroDefinition.spring_chains.

## The chain's joints from the root to the tip: each bone but the last
## swings, pointing at the next one's head; the last only marks the tip
## (the builder's `<name>.end`). The first bone's parent is the anchor.
@export var bones: PackedStringArray = PackedStringArray()
## How hard the chain pulls back to where the animation puts it (per
## second): higher is stiffer.
@export var stiffness: float = 30.0
## How quickly a swing dies away (per second): higher settles sooner.
@export var damping: float = 6.0
## Pull downward on the tips (m/s^2 at the character's scale).
@export var gravity: float = 0.0
## The reach limit: how far (degrees) a bone may swing from its
## animated direction.
@export var max_degrees: float = 30.0


## What is wrong with the tuning, or [] (the validator).
func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if bones.size() < 2:
		found.append("needs at least a bone and its tip")
	if stiffness <= 0.0 or damping <= 0.0:
		found.append("needs a positive stiffness and damping")
	if gravity < 0.0:
		found.append("has a negative gravity")
	if max_degrees <= 0.0 or max_degrees > 90.0:
		found.append("needs a reach limit between 0 and 90 degrees")
	return found
