extends CanvasLayer

@export var menu_music : AudioStream

@onready var retry_button: Button = $GameOver/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RetryButton
@onready var menu_button: Button = $GameOver/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MenuButton

func _ready() -> void:
	AudioManager.duck_music(true)
	if !retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.connect(_on_retry_pressed)
	if !menu_button.pressed.is_connected(_on_menu_pressed):
		menu_button.pressed.connect(_on_menu_pressed)

	# Initial focus for accessibility and gamepad support
	retry_button.grab_focus()
	
	if menu_music:
		AudioManager.play_music(menu_music)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		_on_retry_pressed()

func _on_retry_pressed() -> void:
	AudioManager.duck_music(false)
	SceneManager.reload_last_gameplay_scene()

func _on_menu_pressed() -> void:
	AudioManager.duck_music(false)
	SceneManager.fade_scene("res://scenes/menus/main_menu.tscn")
