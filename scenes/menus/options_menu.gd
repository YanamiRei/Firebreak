extends Control

const FPS_CHOICES: Array[int] = [0, 30, 60, 120, 144, 240]

# OptionsMenu
# Audio and video options with linear-to-dB volume conversion and persistence.
# Fullscreen, Vsync, and Max FPS are supported.  Resolution is not currently.

@onready var master_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Audio/MasterSlider
@onready var music_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Audio/MusicSlider
@onready var sfx_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Audio/SFXSlider
@onready var ui_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Audio/UISlider

@onready var fullscreen_check: CheckButton = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/FullscreenCheck
@onready var vsync_check: CheckButton = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VSyncCheck
@onready var fps_options: OptionButton = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/HBoxContainer/FPSOptions

@onready var back_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer2/BackButton
@onready var default_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer2/DefaultButton

var max_fps : int = 0

func _ready() -> void:
	_setup_fps_dropdown()
	_load_current_values()

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	ui_slider.value_changed.connect(_on_ui_changed)

	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	fps_options.item_selected.connect(_on_fps_selected)
	
	back_button.pressed.connect(_on_back_pressed)
	
	default_button.pressed.connect(reset_to_defaults)
	
func reset_to_defaults () -> void:
	SaveManager.reset_to_defaults()
	_setup_fps_dropdown()
	_load_current_values()

func _load_current_values() -> void:
	master_slider.value = AudioManager.master_volume
	music_slider.value = AudioManager.music_volume
	sfx_slider.value = AudioManager.sfx_volume
	ui_slider.value = AudioManager.ui_volume

	fullscreen_check.button_pressed = SaveManager.fullscreen
	vsync_check.button_pressed = SaveManager.vsync

func _on_master_changed(val: float) -> void:
	AudioManager.master_volume = val
	AudioManager.set_master_volume(val)
	SaveManager.master_volume = val

func _on_music_changed(val: float) -> void:
	AudioManager.music_volume = val
	AudioManager.set_music_volume(val)
	SaveManager.music_volume = val

func _on_sfx_changed(val: float) -> void:
	AudioManager.sfx_volume = val
	AudioManager.set_sfx_volume(val)
	SaveManager.sfx_volume = val

func _on_ui_changed(val: float) -> void:
	AudioManager.ui_volume = val
	AudioManager.set_ui_volume(val)
	SaveManager.ui_volume = val
	AudioManager.play_ui("click")

func _on_fullscreen_toggled(is_on: bool) -> void:
	SaveManager.set_fullscreen(is_on)
	AudioManager.play_ui("click")

func _on_vsync_toggled(is_on: bool) -> void:
	SaveManager.vsync = is_on
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if is_on else DisplayServer.VSYNC_DISABLED
	)
	AudioManager.play_ui("click")

func _setup_fps_dropdown() -> void:
	fps_options.clear()
	for fps in FPS_CHOICES:
		if fps == 0:
			fps_options.add_item("Uncapped")
		else:
			fps_options.add_item("%d FPS" % fps)
	var fps_index : int = FPS_CHOICES.find(SaveManager.max_fps)
	if fps_index != -1:
		fps_options.selected = fps_index
	else:
		fps_options.selected = 0
			
func _on_fps_selected(index: int) -> void:
	if index >= 0 and index < FPS_CHOICES.size():
		var chosen_fps : int = FPS_CHOICES[index]
		set_max_fps(chosen_fps)
		AudioManager.play_ui("click")
		
func set_max_fps(fps: int) -> void:
	max_fps = fps
	Engine.max_fps = max_fps
	EventManager.max_fps_changed.emit(max_fps)

func _on_back_pressed() -> void:
	SaveManager.save_settings()
	SceneManager.fade_scene("res://scenes/menus/main_menu.tscn")
