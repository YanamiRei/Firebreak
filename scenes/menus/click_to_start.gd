extends Control

# Click to Start
# This will make sure that your web builds have focus and 
# will play audio properly when the game starts.

@onready var prompt: Label = $CenterContainer/VBoxContainer/Prompt

var _unlocked: bool = false

func _ready() -> void:
	_animate_prompt()

func _gui_input(event: InputEvent) -> void:
	if _unlocked:
		return
	if event is InputEventMouseButton and event.pressed:
		_unlock_and_proceed()

func _unhandled_input(event: InputEvent) -> void:
	if _unlocked:
		return
	if (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		_unlock_and_proceed()

func _unlock_and_proceed() -> void:
	_unlocked = true
	AudioManager.play_ui()
	SceneManager.fade_scene("res://scenes/menus/main_menu.tscn")

func _animate_prompt() -> void:
	var tween : Tween = create_tween().set_loops()
	tween.tween_property(prompt, "modulate:a", 0.0, 1.0)
	tween.tween_property(prompt, "modulate:a", 1.0, 1.0)
