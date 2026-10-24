extends Control

# Pause Menu
# Ducks Music Audio when menu is shown.
# Designed to be added to the HUD Canvas Layer of your Game
# See Playground.TSCN for example

@onready var resume_button: Button = $CenterContainer/PanelContainer/MarginContainer/Menu/ResumeButton
@onready var restart_button: Button = $CenterContainer/PanelContainer/MarginContainer/Menu/RestartButton
@onready var main_menu_button: Button = $CenterContainer/PanelContainer/MarginContainer/Menu/MainMenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	# Initial focus for accessibility and gamepad support
	resume_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()

func _toggle_pause() -> void:
	var will_pause : bool = !get_tree().paused
	get_tree().paused = will_pause
	visible = will_pause
	AudioManager.duck_music(will_pause)
	if will_pause:
		resume_button.grab_focus()

func _on_resume_pressed() -> void:
	_toggle_pause()
	AudioManager.duck_music(false)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	visible = false
	AudioManager.duck_music(false)
	SceneManager.reload_current_scene()
	
func _on_main_menu_pressed() -> void:
	RunState.abandon_run()
	get_tree().paused = false
	visible = false
	AudioManager.duck_music(false)
	SceneManager.fade_scene("res://scenes/menus/main_menu.tscn")
