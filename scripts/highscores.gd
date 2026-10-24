class_name Highscores
extends RefCounted
## A run is a Dictionary: { score, floors, items, kept, broken, signed, cause, date, time }.

const MAX_ENTRIES := 10

static var path := "user://highscores.cfg"
static var last_run_time := 0

static var _cfg: ConfigFile


static func _config() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(path)
	return _cfg


static func _save() -> void:
	if _cfg != null:
		_cfg.save(path)


static func reload() -> void:
	_cfg = null


static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _config().get_value("runs", "list", []):
		if e is Dictionary:
			out.append(e)
	return out


static func stats() -> Dictionary:
	var c := _config()
	return {
		"runs": int(c.get_value("stats", "runs", 0)),
		"best_score": int(c.get_value("stats", "best_score", 0)),
		"best_floors": int(c.get_value("stats", "best_floors", 0)),
		"total_floors": int(c.get_value("stats", "total_floors", 0)),
		"total_score": int(c.get_value("stats", "total_score", 0)),
		"total_items": int(c.get_value("stats", "total_items", 0)),
		"kept": int(c.get_value("stats", "kept", 0)),
		"broken": int(c.get_value("stats", "broken", 0)),
		"signed": int(c.get_value("stats", "signed", 0)),
	}


static func best_score() -> int:
	return int(_config().get_value("stats", "best_score", 0))


static func best_floors() -> int:
	return int(_config().get_value("stats", "best_floors", 0))


static func _better(a: Dictionary, b: Dictionary) -> bool:
	if a["score"] != b["score"]:
		return a["score"] > b["score"]
	if a["floors"] != b["floors"]:
		return a["floors"] > b["floors"]
	return a["time"] < b["time"]   # older run wins a tie


static func record(run: Dictionary) -> Dictionary:
	var c := _config()
	var entry := {
		"score": int(run.get("score", 0)), "floors": int(run.get("floors", 0)),
		"items": int(run.get("items", 0)), "kept": int(run.get("kept", 0)),
		"broken": int(run.get("broken", 0)), "signed": int(run.get("signed", 0)),
		"cause": str(run.get("cause", "")),
		"date": str(run.get("date", Time.get_date_string_from_system())),
		"time": int(run.get("time", Time.get_unix_time_from_system())),
	}
	var s := stats()
	var result := {
		"rank": 0,
		"new_best_score": entry["score"] > s["best_score"],
		"new_best_floors": entry["floors"] > s["best_floors"],
		"previous_best": s["best_score"],
	}
	var list := entries()
	list.append(entry)
	list.sort_custom(_better)
	if list.size() > MAX_ENTRIES:
		list.resize(MAX_ENTRIES)
	var idx := list.find(entry)
	result["rank"] = idx + 1 if idx >= 0 else 0
	c.set_value("runs", "list", list)
	c.set_value("stats", "runs", s["runs"] + 1)
	c.set_value("stats", "best_score", maxi(s["best_score"], entry["score"]))
	c.set_value("stats", "best_floors", maxi(s["best_floors"], entry["floors"]))
	c.set_value("stats", "total_floors", s["total_floors"] + entry["floors"])
	c.set_value("stats", "total_score", s["total_score"] + entry["score"])
	c.set_value("stats", "total_items", s["total_items"] + entry["items"])
	c.set_value("stats", "kept", s["kept"] + entry["kept"])
	c.set_value("stats", "broken", s["broken"] + entry["broken"])
	c.set_value("stats", "signed", s["signed"] + entry["signed"])
	_save()
	last_run_time = entry["time"]
	return result


static func clear() -> void:
	_cfg = ConfigFile.new()
	_save()
	last_run_time = 0
