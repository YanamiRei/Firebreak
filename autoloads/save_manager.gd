extends Node

# SaveManager Autoload
# Saves game options to the settings.cfg file in the user data folder.
# Autoloads any saved configs and auto applies them.

const SAVE_PATH: String = "user://settings.cfg"

var config : ConfigFile = ConfigFile.new()
var master_volume : float = 0.8
var music_volume : float = 0.7
var sfx_volume : float = 0.8
var ui_volume : float = 0.8
var fullscreen : bool = false
var vsync : bool = true
var max_fps : int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_settings()
	EventManager.max_fps_changed.connect(save_max_fps)

func reset_to_defaults() -> void:
	master_volume = 0.8
	music_volume = 0.7
	sfx_volume = 0.8
	ui_volume = 0.8
	fullscreen = false
	vsync = true
	max_fps = 0
	save_settings()
	apply_settings()

func load_settings() -> void:
	var err : Error = config.load(SAVE_PATH)
	if err != OK:
		# First run or missing file
		save_settings()
		return

	master_volume = config.get_value("audio", "master_volume", 0.8)
	music_volume = config.get_value("audio", "music_volume", 0.8)
	sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
	ui_volume = config.get_value("audio", "ui_volume", 0.8)

	fullscreen = config.get_value("video", "fullscreen", false)
	vsync = config.get_value("video", "vsync", true)
	max_fps = config.get_value("video", "max_fps", 0)

func save_settings() -> void:
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ui_volume", ui_volume)

	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "max_fps", max_fps)

	config.save(SAVE_PATH)

func apply_settings() -> void:
	AudioManager.master_volume = master_volume
	AudioManager.set_master_volume(master_volume)
	AudioManager.music_volume = music_volume
	AudioManager.set_music_volume(music_volume)
	AudioManager.sfx_volume = sfx_volume
	AudioManager.set_sfx_volume(sfx_volume)
	AudioManager.ui_volume = ui_volume
	AudioManager.set_ui_volume(ui_volume)
	
	set_fullscreen(fullscreen)
	set_max_fps(max_fps)

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func save_max_fps(fps: int) -> void:
	max_fps = fps
	save_settings()

func set_max_fps(fps: int) -> void:
	max_fps = fps
	Engine.max_fps = max_fps
	EventManager.max_fps_changed.emit(max_fps)

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	var mode : int = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	if get_tree() and get_tree().root:
		get_tree().root.mode = Window.MODE_EXCLUSIVE_FULLSCREEN if enabled else Window.MODE_WINDOWED
	EventManager.fullscreen_toggled.emit(fullscreen)
	
