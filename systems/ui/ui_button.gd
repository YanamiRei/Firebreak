class_name UIButton extends Button

# UIButton Class
# Adds in Hover and Click Audio Automatically
# Adds in Grow an Shrink to all buttons (V4.7+)

func _ready() -> void:
	# Adds UI sounds to all Menu buttons (Will be deprecated in V4.8)
	_bind_hover_sounds()

	# Adds Grow/Shrink to all Menu Buttons (Requires V4.7)
	var version_info = Engine.get_version_info()
	if version_info.major == 4:
		if version_info.minor >= 7:
			offset_transform_enabled=true
			_bind_hover_effects()
		else:
			print("Offset Transform requires version 4.7 or newer")

func _bind_hover_effects() -> void:
	mouse_entered.connect(_grow)
	mouse_exited.connect(_shrink)

func _grow () -> void:
	offset_transform_scale=Vector2(1.05,1.05)
	pass
	
func _shrink () -> void:
	offset_transform_scale=Vector2(1,1)
	pass

func _bind_hover_sounds() -> void:
	mouse_entered.connect(AudioManager.play_ui.bind('hover'))
	focus_entered.connect(AudioManager.play_ui.bind('hover'))
	pressed.connect(AudioManager.play_ui.bind('click'))
