extends Control

# Credits
# Auto-scrolling credits screen reading directly from credits.txt.
# Supports speedup on move_down held and exit on Escape.

# Credits text is embedded so it always ships in the web build.
const CREDITS_TEXT: String = """FIREBREAK
===========================

PROGRAMMING
Yanami Rei (八奈見​レイ)
https://yanamirei.itch.io

ART
Yanami Rei (八奈見​レイ)
https://yanamirei.itch.io
STARTER KIT
Godot Game Jam Starter Kit by NyeDigitalGames / James Nye

ENGINE
Godot Engine v4.7
https://godotengine.org

SOUND
Menu music: Somewhere in the Elevator by Peachtea (You're Perfect Studio)
Gameplay music: Hurry by Umplix
Game over music: Game Over by Kistol
Burn effect: Catching fire by themightyglider
Fire ambience: Fireplace Sound Loop by PagDev
Siren: Sirens and Alarm Noise by aquinn
All sounds are CC0 and come from OpenGameArt.org
https://opengameart.org

Thank you for playing and creating!
Press ESC to Return
"""

@export var scroll_speed: float = 45.0
@export var fast_multiplier: float = 4.0
@export var title_colour := Color("f6e7bd")
@export var heading_colour := Color("f0b84a")
@export var dim_colour := Color("8e9db0")

@onready var credits: RichTextLabel = $Layout/ScrollArea/ScrollContainer/VBoxContainer/Credits
@onready var scroll_container: ScrollContainer = $Layout/ScrollArea/ScrollContainer
@onready var top_spacer: Control = $Layout/ScrollArea/ScrollContainer/VBoxContainer/TopSpacer
@onready var bottom_spacer: Control = $Layout/ScrollArea/ScrollContainer/VBoxContainer/BottomSpacer
@onready var back_button: Button = $Layout/BottomBar/BackButton

var _current_scroll: float = 0.0
var _scrolling := false
var _leaving := false

func _ready() -> void:
	_load_credits_file()
	back_button.pressed.connect(_on_back_pressed)
	back_button.grab_focus()
	await get_tree().process_frame
	var gap := scroll_container.size.y
	top_spacer.custom_minimum_size.y = gap
	bottom_spacer.custom_minimum_size.y = gap
	_scrolling = true

func _load_credits_file() -> void:
	credits.text = "[center]%s[/center]" % _format(CREDITS_TEXT)

func _format(raw: String) -> String:
	var out := PackedStringArray()
	var first := true
	for line in raw.strip_edges().split("\n"):
		var t := line.strip_edges()
		if t.begins_with("==="):
			continue
		if t == "":
			out.append("")
		elif first:
			out.append("[font_size=56][color=#%s][b]%s[/b][/color][/font_size]" % [title_colour.to_html(false), t])
			first = false
		elif t == t.to_upper() and t != t.to_lower():
			out.append("[font_size=26][color=#%s][b]%s[/b][/color][/font_size]" % [heading_colour.to_html(false), t])
		elif t.begins_with("http"):
			out.append("[color=#%s]%s[/color]" % [dim_colour.to_html(false), t])
		else:
			out.append(t)
	return "\n".join(out)

func _process(delta: float) -> void:
	if not _scrolling or _leaving:
		return
	var speed : float = scroll_speed
	if Input.is_action_pressed("move_down"):
		speed *= fast_multiplier

	_current_scroll += speed * delta
	scroll_container.scroll_vertical = int(_current_scroll)

	var v_bar : ScrollBar = scroll_container.get_v_scroll_bar()
	if v_bar != null and _current_scroll >= v_bar.max_value and v_bar.max_value > 0:
		_leaving = true
		await get_tree().create_timer(1.5).timeout
		_on_back_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_back_pressed()

func _on_back_pressed() -> void:
	SceneManager.fade_scene("res://scenes/menus/main_menu.tscn")
