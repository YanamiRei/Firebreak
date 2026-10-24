extends Control

# Main Menu

@export var menu_music : AudioStream

@onready var play_button: Button = $CenterContainer/PanelContainer/MarginContainer/Menu/PlayButton
@onready var how_to_play_button: Button = $CenterContainer/PanelContainer/MarginContainer/Menu/HowToPlayButton
@onready var options_button: Button = $CenterContainer/PanelContainer/MarginContainer/Menu/OptionsButton
@onready var credits_button: Button = $CenterContainer/PanelContainer/MarginContainer/Menu/CreditsButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/MarginContainer/Menu/QuitButton

@onready var highscores_button: Button = $CenterContainer/PanelContainer/MarginContainer/Menu/HighscoresButton

func _ready() -> void:
	# Hide Quit button if running in a web browser
	if OS.has_feature("web"):
		quit_button.visible = false

	# Connect buttons
	play_button.pressed.connect(_on_play_pressed)
	how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	if highscores_button:
		highscores_button.pressed.connect(_on_highscores_pressed)
	
	# Initial focus for accessibility and gamepad support
	play_button.grab_focus()

	if menu_music:
		AudioManager.play_music(menu_music)
		
func _on_play_pressed() -> void:
	SceneManager.fade_scene("res://scenes/main.tscn")

func _on_how_to_play_pressed() -> void:
	SceneManager.fade_scene("res://scenes/menus/how_to_play.tscn")

func _on_highscores_pressed() -> void:
	SceneManager.fade_scene("res://scenes/menus/highscore.tscn")

func _on_options_pressed() -> void:
	SceneManager.fade_scene("res://scenes/menus/options_menu.tscn")

func _on_credits_pressed() -> void:
	SceneManager.fade_scene("res://scenes/menus/credits.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
