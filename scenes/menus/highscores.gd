extends Control

@export var table: RichTextLabel
@export var stats_label: Label
@export var back_button: Button
@export var clear_button: Button
@export var highlight_colour := Color(1.0, 0.85, 0.35)

var _clear_armed := false


func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		back_button.grab_focus()
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	_refresh()


func _refresh() -> void:
	if table:
		table.bbcode_enabled = true
		table.text = _table_text()
	if stats_label:
		stats_label.text = _stats_text()


func _table_text() -> String:
	var rows := Highscores.entries()
	if rows.is_empty():
		return "[center][color=#8a93a0]No runs yet. Press New Run and get to work.[/color][/center]"
	var t := "[table=7]"
	for h in ["#", "Score", "Floors", "Items", "Contracts", "How it ended", "Date"]:
		t += "[cell][color=#8a93a0][b]%s   [/b][/color][/cell]" % h
	for i in rows.size():
		var r: Dictionary = rows[i]
		var cells := [str(i + 1), str(r["score"]), str(r["floors"]), str(r["items"]),
			"%d kept / %d broken" % [r["kept"], r["broken"]], str(r["cause"]), str(r["date"])]
		var latest: bool = int(r["time"]) == Highscores.last_run_time and Highscores.last_run_time != 0
		for c in cells:
			var txt := "[b]%s[/b]" % c if i == 0 else str(c)
			if latest:
				txt = "[color=#%s]%s[/color]" % [highlight_colour.to_html(false), txt]
			t += "[cell]%s   [/cell]" % txt
	return t + "[/table]"


func _stats_text() -> String:
	var s := Highscores.stats()
	if s["runs"] == 0:
		return ""
	return "Runs: %d    Best score: %d    Deepest floor: %d    Items collected: %d    Contracts kept / broken: %d / %d" % [
		s["runs"], s["best_score"], s["best_floors"], s["total_items"], s["kept"], s["broken"]]


func _on_clear_pressed() -> void:
	if not _clear_armed:
		_clear_armed = true
		clear_button.text = "Really clear? Press again"
		return
	Highscores.clear()
	_clear_armed = false
	clear_button.text = "Clear Records"
	_refresh()


func _on_back_pressed() -> void:
	SceneManager.fade_scene("res://scenes/menus/main_menu.tscn")
