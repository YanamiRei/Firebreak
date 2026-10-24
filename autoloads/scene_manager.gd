extends CanvasLayer

# Scene Manager Autoload
# Controls scene transtions and fast resetting of levels
# Allows Directional Black Wipes or simple Screen Fade Transitions

signal transition_finished()

@onready var fade: Control = $Fade
@onready var texture_rect: TextureRect = $Fade/TextureRect
@onready var spinner: TextureRect = $Fade/Spinner

const SPINNER_FRAMES : int = 10
const SPINNER_FRAME_SIZE : int = 14
const SPINNER_FPS : float = 12.0
var _spinner_time : float = 0.0

var _is_transitioning: bool = false
var _current_scene_path: String = ""

# Set a default start quick reload scene
var _last_gameplay_scene_path: String = "res://scenes/main.tscn" 
var _resolution : Vector2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_current_scene_path.call_deferred()
	get_tree().node_added.connect(_on_node_added)
	await get_tree().physics_frame
	fade.visible=false
	_update_resolution()
	EventManager.resolution_updated.connect(_update_resolution)
	pass
	

func _on_node_added(n: Node) -> void:
	# Top-level UI nodes get smooth filtering so text stays crisp; children inherit it.
	if n is Control and not (n.get_parent() is Control):
		n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

# Dynamically scales the directional fade ColorRect based on current resolution
func _update_resolution()->void:
	_resolution = DisplayServer.window_get_size()
	texture_rect.custom_minimum_size=Vector2(_resolution.x*3,_resolution.y*3)
	pass

func _process(delta: float) -> void:
	if not fade.visible:
		return
	_spinner_time += delta
	var frame : int = int(_spinner_time * SPINNER_FPS) % SPINNER_FRAMES
	(spinner.texture as AtlasTexture).region = Rect2(frame * SPINNER_FRAME_SIZE, 0, SPINNER_FRAME_SIZE, SPINNER_FRAME_SIZE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not _is_transitioning:
		# Quick restart with R key for rapid testing during game jams
		if not _is_gameplay_scene(_current_scene_path):
			reload_last_gameplay_scene()
		else:
			reload_current_scene()

## Call fade_scene with new scene resource name and Vector2.Direction for directional wipes or Vector2.ZERO for standard fade in/out.
func fade_scene(new_scene:String = "res://scenes/main.tscn",direction:Vector2=Vector2.ZERO) -> void:
	match direction:
		Vector2.ZERO:_fade_out(new_scene)
		Vector2.UP:_fade_dir(new_scene,_resolution.y*2,-_resolution.y*2,"offset_transform_position:y")
		Vector2.DOWN:_fade_dir(new_scene,-_resolution.y*2,_resolution.y*2,"offset_transform_position:y")
		Vector2.LEFT:_fade_dir(new_scene,_resolution.x*2,-_resolution.x*2,"offset_transform_position:x")
		Vector2.RIGHT:_fade_dir(new_scene,-_resolution.x*2,_resolution.x*2,"offset_transform_position:x")
	
func _fade_out(new_scene:String = "res://scenes/main.tscn") -> void:
	_is_transitioning=true
	
	# Fade to Black
	fade.offset_transform_position = Vector2(0,0)
	fade.modulate = Color(1.0, 1.0, 1.0, 0.0)
	fade.visible=true
	var tween = create_tween()
	tween.tween_property(fade,"modulate:a",1,0.2)
	await tween.finished
	tween.kill()
	
	# Swap while behind ColorRect overlay
	get_tree().change_scene_to_file(new_scene)
	await get_tree().scene_changed
	
	#Fade from Black
	tween = create_tween()
	tween.tween_property(fade,"modulate:a",0,0.2)
	await tween.finished
	
	fade.visible=false
	fade.offset_transform_position = Vector2.ZERO
	fade.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_is_transitioning=false
	transition_finished.emit()
	
func _fade_dir(new_scene:String,start:float, end:float, axis:String) -> void:
	_is_transitioning=true
	
	# Offset ColorRect for proper wipe display based on direction and Fade to Black
	if axis == "offset_transform_position:y":
		fade.offset_transform_position = Vector2(0,start)
	elif axis == "offset_transform_position:x":
		fade.offset_transform_position = Vector2(start,0)
	fade.visible=true
	var tween = create_tween()
	tween.tween_property(fade,axis,0,0.2)
	await tween.finished
	tween.kill()
	
	# Swap while behind ColorRect overlay
	get_tree().change_scene_to_file(new_scene)
	await get_tree().scene_changed
	
	# Continue Fade to Fade back form Black
	tween = create_tween()
	tween.tween_property(fade,axis,end,0.2)
	await tween.finished
	
	fade.visible=false
	fade.offset_transform_position = Vector2.ZERO
	_is_transitioning=false
	transition_finished.emit()
	
func _is_gameplay_scene(path: String) -> bool:
	if path.is_empty():
		return false
	var lower : String = path.to_lower()
	return not (
		lower.contains("game_over")
		or lower.contains("main_menu")
		or lower.contains("click_to_start")
		or lower.contains("pause_menu")
		or lower.contains("options_menu")
		or lower.contains("credits")
		or lower.contains("how_to_play")
		or lower.contains("highscores")
	)

func _update_current_scene_path() -> void:
	var current_scene : Node = get_tree().current_scene
	if current_scene != null and not current_scene.scene_file_path.is_empty():
		_current_scene_path = current_scene.scene_file_path
		# Prevent Menus from being pushed to the quick reload scene.
		if _is_gameplay_scene(_current_scene_path):
			_last_gameplay_scene_path = _current_scene_path

func reload_current_scene() -> void:
	if _is_transitioning:
		return
	if _current_scene_path.is_empty():
		_update_current_scene_path()
	if not _current_scene_path.is_empty():
		EventManager.level_restarted.emit()
		_fade_out(_current_scene_path)
	else:
		get_tree().reload_current_scene()

func reload_last_gameplay_scene() -> void:
	var target : String = _last_gameplay_scene_path
	if target.is_empty() or not _is_gameplay_scene(target):
		target = "res://scenes/main.tscn"
	EventManager.level_restarted.emit()
	fade_scene(target)
