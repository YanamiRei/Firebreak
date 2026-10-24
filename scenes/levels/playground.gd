extends Node2D

@export var menu_music : AudioStream

@onready var test_kill_button: Button = $ColorRect/TestKillButton

func _ready() -> void:
	test_kill_button.pressed.connect (game_over)
	SceneManager._update_current_scene_path()
	
	if menu_music:
		AudioManager.play_music(menu_music)

func game_over() -> void:
	AudioManager.play_ui("error")
	EventManager.player_died.emit()
	SceneManager.fade_scene("res://scenes/menus/game_over.tscn",Vector2.DOWN)
