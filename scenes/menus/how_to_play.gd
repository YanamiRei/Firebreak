extends Control

# Simple How to Play Screen that explains controls
# Can also be used to explain lore/theme ideas for the game.

@onready var back_button: Button = $Margin/PanelContainer/MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.grab_focus()
	
func _on_back_pressed() -> void:
	SceneManager.fade_scene("res://scenes/menus/main_menu.tscn")
