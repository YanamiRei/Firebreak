class_name ItemData
extends Resource

enum Kind {
	EXIT,
	WALL_BONUS,
	PORTABLE_STAIRS,
	SCORE,
	CURSED,
}

@export var display_name := "Item"
@export_multiline var description := ""
@export var icon: Texture2D
@export var kind: Kind = Kind.WALL_BONUS
@export var amount := 1
@export var spawn_weight := 1.0
@export var can_be_masked := true


## Text for the pickup feed
func feed_text(count: int, total: int) -> String:
	var t := display_name
	if count > 1:
		t += " x%d" % count
	var effect := effect_text(total)
	if effect != "":
		t += " = " + effect
	return t


func effect_text(total: int) -> String:
	match kind:
		Kind.WALL_BONUS:
			return "+%d walls" % total
		Kind.SCORE:
			return "+%d score" % total
		Kind.CURSED:
			if total <= 0:
				return "nothing left to lose"
			return "-%d walls" % total
	return ""
