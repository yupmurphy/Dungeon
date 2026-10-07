class_name WantedPoster
extends Resource
## One poster on a town's Wanted board: who is hunted and the bounty. New poster = new .tres in
## resources/town/wanted/. Later the player's own poster is added when they are wanted.

enum Kind { MURDERER, UNDEAD, MONSTER, PLAYER }

## Text key in localization/texts.csv (the name shown when the board is read).
@export var name_key: StringName = &"WANTED_UNKNOWN"
@export var kind: Kind = Kind.MURDERER
## Bounty in gold.
@export var reward: int = 100
