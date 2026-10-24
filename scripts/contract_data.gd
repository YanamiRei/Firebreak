class_name ContractData
extends Resource

enum RewardKind { WALLS, PORTABLE_STAIRS, SCORE }
enum DemandKind {
	MIN_AREA,
	MIN_ITEMS,
	MAX_WALLS_USED,
}

@export var title := "Contract"
@export_multiline var flavour := ""

@export_group("You receive (immediately)")
@export var reward_kind: RewardKind = RewardKind.WALLS
@export var reward_amount := 3

@export_group("You owe")
@export var demand_kind: DemandKind = DemandKind.MIN_AREA
@export var demand_amount := 20
@export var floors_to_fulfil := 2

enum FineKind {
	NONE,
	HARSHER_PENALTY,
	HARDER_DEMAND,
	SHORTER_DEADLINE,
	SIGNING_FEE,
	BONUS_REWARD,
}

@export_group("If you break it")
@export var penalty_walls := 3
@export var penalty_score := 0

@export_group("Fine print (hidden until you sign)")
@export var fine_kind: FineKind = FineKind.NONE
@export var fine_amount := 2
@export var fine_text := ""


func reward_text() -> String:
	match reward_kind:
		RewardKind.WALLS:
			return "+%d walls" % reward_amount
		RewardKind.PORTABLE_STAIRS:
			return "+%d portable stairs" % reward_amount
		RewardKind.SCORE:
			return "+%d score" % reward_amount
	return ""


func demand_text(amount := -1) -> String:
	if amount < 0:
		amount = demand_amount
	match demand_kind:
		DemandKind.MIN_AREA:
			return "seal %d+ tiles on one floor" % amount
		DemandKind.MIN_ITEMS:
			return "collect %d items" % amount
		DemandKind.MAX_WALLS_USED:
			return "use at most %d walls per floor" % amount
	return ""


func deadline_text() -> String:
	return "%d floor%s" % [floors_to_fulfil, "" if floors_to_fulfil == 1 else "s"]


func demand_sentence() -> String:
	var t := demand_text()
	return t.substr(0, 1).to_upper() + t.substr(1)


func has_fine_print() -> bool:
	return fine_kind != FineKind.NONE


func fine_print_is_bad() -> bool:
	return fine_kind != FineKind.NONE and fine_kind != FineKind.BONUS_REWARD


func fine_print_text(amount: int) -> String:
	var effect := ""
	match fine_kind:
		FineKind.HARSHER_PENALTY:
			effect = "Breaking this contract costs %d more walls." % amount
		FineKind.HARDER_DEMAND:
			if demand_kind == DemandKind.MAX_WALLS_USED:
				effect = "The wall limit is %d lower than advertised." % amount
			else:
				effect = "The target is %d higher than advertised." % amount
		FineKind.SHORTER_DEADLINE:
			effect = "The deadline is %d floor%s shorter than advertised." % [amount, "" if amount == 1 else "s"]
		FineKind.SIGNING_FEE:
			effect = "An administrative fee took %d walls the moment you signed." % amount
		FineKind.BONUS_REWARD:
			effect = "A signing perk: %s extra." % _reward_text_for(amount)
	if fine_text != "":
		return "%s\n%s" % [fine_text, effect]
	return effect


func _reward_text_for(amount: int) -> String:
	match reward_kind:
		RewardKind.WALLS:
			return "+%d walls" % amount
		RewardKind.PORTABLE_STAIRS:
			return "+%d portable stairs" % amount
		RewardKind.SCORE:
			return "+%d score" % amount
	return ""


func penalty_text() -> String:
	var parts: PackedStringArray = []
	if penalty_walls > 0:
		parts.append("-%d walls" % penalty_walls)
	if penalty_score > 0:
		parts.append("-%d score" % penalty_score)
	if parts.is_empty():
		return "nothing"
	return ", ".join(parts)


func describe() -> String:
	var lines: PackedStringArray = [title.to_upper()]
	if flavour != "":
		lines.append(flavour)
	lines.append("You get: %s" % reward_text())
	lines.append("Within %d floors: %s" % [floors_to_fulfil, demand_text()])
	lines.append("Break it: %s" % penalty_text())
	if has_fine_print():
		lines.append("Fine print: ######## (read it after you sign)")
	return "\n".join(lines)
