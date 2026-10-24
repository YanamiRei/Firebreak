extends Node

signal changed

var params: LevelParams
var floor_number := 1
var wall_stock := 0
var portable_stairs := 0
var score := 0
var items_collected := 0
var contracts_signed := 0
var contracts_kept := 0
var contracts_broken := 0
var run_active := false
## { "data": ContractData, "floors_left": int, "progress": int, "demand": int, "penalty_walls": int, "penalty_score": int, "fine": bool }
var contracts: Array[Dictionary] = []

var _floors_since_offer := 0
var _next_offer_score := 0


func new_run(p: LevelParams) -> void:
	abandon_run()
	params = p
	floor_number = 1
	wall_stock = p.start_walls
	portable_stairs = 0
	score = 0
	items_collected = 0
	contracts_signed = 0
	contracts_kept = 0
	contracts_broken = 0
	run_active = true
	contracts.clear()
	_floors_since_offer = 0
	_next_offer_score = p.contract_score_step
	changed.emit()


func begin_floor() -> int:
	if floor_number > 1:
		wall_stock += params.walls_per_floor
	changed.emit()
	return wall_stock


func apply_item(d: ItemData) -> int:
	var applied := d.amount
	match d.kind:
		ItemData.Kind.WALL_BONUS:
			wall_stock += d.amount
		ItemData.Kind.PORTABLE_STAIRS:
			portable_stairs += d.amount
		ItemData.Kind.SCORE:
			score += d.amount
		ItemData.Kind.CURSED:
			applied = mini(d.amount, wall_stock)
			wall_stock -= applied
	changed.emit()
	return applied


func finish_floor(area: int, walls_used: int, items_got: int) -> Dictionary:
	score += area
	items_collected += items_got
	var kept_titles: Array[String] = []
	var broken_list: Array[Dictionary] = []
	var remaining: Array[Dictionary] = []
	for c in contracts:
		var data: ContractData = c["data"]
		var kept := false
		var broken := false
		var reason := ""
		var demand: int = c["demand"]
		match data.demand_kind:
			ContractData.DemandKind.MIN_AREA:
				kept = area >= demand
				reason = "The deadline passed and you never sealed %d+ tiles on one floor." % demand
			ContractData.DemandKind.MIN_ITEMS:
				c["progress"] += items_got
				kept = c["progress"] >= demand
				reason = "The deadline passed. You collected %d of %d items." % [c["progress"], demand]
			ContractData.DemandKind.MAX_WALLS_USED:
				broken = walls_used > demand
				reason = "You used %d walls on that floor. The limit was %d." % [walls_used, demand]
		if c["fine"] and (broken or (not kept and c["floors_left"] <= 1)):
			reason += " (The fine print did not help.)"
		if not kept and not broken:
			c["floors_left"] -= 1
			if c["floors_left"] <= 0:
				
				kept = data.demand_kind == ContractData.DemandKind.MAX_WALLS_USED
				broken = not kept
		if kept:
			kept_titles.append(data.title)
		elif broken:
			var lost_walls := mini(int(c["penalty_walls"]), wall_stock)
			var lost_score := mini(int(c["penalty_score"]), score)
			wall_stock -= lost_walls
			score -= lost_score
			var parts: PackedStringArray = []
			if lost_walls > 0:
				parts.append("-%d walls" % lost_walls)
			if lost_score > 0:
				parts.append("-%d score" % lost_score)
			broken_list.append({
				"data": data,
				"reason": reason,
				"penalty": ", ".join(parts) if not parts.is_empty() else "nothing this time",
			})
		else:
			remaining.append(c)
	contracts = remaining
	contracts_kept += kept_titles.size()
	contracts_broken += broken_list.size()
	floor_number += 1
	_floors_since_offer += 1
	changed.emit()
	return {"kept": kept_titles, "broken": broken_list}


func summary(cause: String) -> Dictionary:
	return {
		"score": score, "floors": floor_number - 1, "items": items_collected,
		"kept": contracts_kept, "broken": contracts_broken, "signed": contracts_signed,
		"cause": cause, "date": Time.get_date_string_from_system(),
		"time": int(Time.get_unix_time_from_system()),
	}


func end_run(cause: String) -> Dictionary:
	if not run_active:
		return {}
	run_active = false
	return Highscores.record(summary(cause))


func abandon_run() -> void:
	if run_active and (floor_number > 1 or score > 0):
		end_run("Abandoned")
	run_active = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		abandon_run()


func contract_due() -> bool:
	if contracts.size() >= params.max_active_contracts:
		return false
	return _floors_since_offer >= params.contract_every_floors or score >= _next_offer_score


func mark_offered() -> void:
	_floors_since_offer = 0
	_next_offer_score = score + params.contract_score_step


func is_active(data: ContractData) -> bool:
	for c in contracts:
		if c["data"] == data:
			return true
	return false


func sign_contract(data: ContractData) -> Dictionary:
	_give_reward(data.reward_kind, data.reward_amount)
	var c := {
		"data": data, "floors_left": data.floors_to_fulfil, "progress": 0,
		"demand": data.demand_amount, "penalty_walls": data.penalty_walls,
		"penalty_score": data.penalty_score, "fine": data.has_fine_print(),
	}
	var info := {"fine": false, "bad": false, "text": ""}
	if data.has_fine_print():
		var amount := data.fine_amount
		match data.fine_kind:
			ContractData.FineKind.HARSHER_PENALTY:
				c["penalty_walls"] += amount
			ContractData.FineKind.HARDER_DEMAND:
				if data.demand_kind == ContractData.DemandKind.MAX_WALLS_USED:
					amount = mini(amount, maxi(0, data.demand_amount - 1))
					c["demand"] = data.demand_amount - amount
				else:
					c["demand"] = data.demand_amount + amount
			ContractData.FineKind.SHORTER_DEADLINE:
				amount = mini(amount, maxi(0, data.floors_to_fulfil - 1))
				c["floors_left"] = data.floors_to_fulfil - amount
			ContractData.FineKind.SIGNING_FEE:
				amount = mini(amount, wall_stock)
				wall_stock -= amount
			ContractData.FineKind.BONUS_REWARD:
				_give_reward(data.reward_kind, amount)
		info = {"fine": true, "bad": data.fine_print_is_bad(), "text": data.fine_print_text(amount)}
	contracts.append(c)
	contracts_signed += 1
	changed.emit()
	return info


func _give_reward(kind: ContractData.RewardKind, amount: int) -> void:
	match kind:
		ContractData.RewardKind.WALLS:
			wall_stock += amount
		ContractData.RewardKind.PORTABLE_STAIRS:
			portable_stairs += amount
		ContractData.RewardKind.SCORE:
			score += amount


func contract_lines() -> Array[String]:
	var lines: Array[String] = []
	for c in contracts:
		var data: ContractData = c["data"]
		var demand := data.demand_text(int(c["demand"]))
		demand = demand.substr(0, 1).to_upper() + demand.substr(1)
		if data.demand_kind == ContractData.DemandKind.MIN_ITEMS:
			demand += " (%d/%d)" % [c["progress"], c["demand"]]
		var left := int(c["floors_left"])
		var line := "[b]%s[/b]" % data.title
		if c["fine"]:
			line += " [color=#f0b84a]*[/color]"
		line += "\n[color=#8e9db0]%s\n%d floor%s left[/color]" % [demand, left, "" if left == 1 else "s"]
		lines.append(line)
	return lines
