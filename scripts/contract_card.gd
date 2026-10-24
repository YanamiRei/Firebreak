class_name ContractCard
extends Button

@export_group("Labels")
@export var title_label: Label
@export var flavour_label: Label
@export var reward_label: Label
@export var demand_label: Label
@export var deadline_label: Label
@export var penalty_label: Label
@export var fine_label: Label
@export var fine_row: Control

@export_group("Colours")
@export var title_colour := Color(1.0, 0.93, 0.7)
@export var reward_colour := Color(0.55, 0.95, 0.6)
@export var penalty_colour := Color(1.0, 0.5, 0.45)
@export var fine_colour := Color(1.0, 0.8, 0.35)
@export var flavour_colour := Color(0.7, 0.74, 0.8)

@export_group("Hover")
@export var hover_scale := 1.03

var _tween: Tween


func _ready() -> void:
	_ignore_mouse(self)
	_tint(title_label, title_colour)
	_tint(reward_label, reward_colour)
	_tint(penalty_label, penalty_colour)
	_tint(fine_label, fine_colour)
	_tint(flavour_label, flavour_colour)
	for l in [flavour_label, demand_label, fine_label]:
		if l:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	focus_entered.connect(_hover.bind(true))
	focus_exited.connect(_hover.bind(false))
	resized.connect(func(): pivot_offset = size / 2.0)
	pivot_offset = size / 2.0


func show_contract(d: ContractData) -> void:
	text = ""
	_put(title_label, d.title.to_upper())
	_put(flavour_label, d.flavour)
	if flavour_label:
		flavour_label.visible = d.flavour != ""
	_put(reward_label, d.reward_text())
	_put(demand_label, d.demand_sentence())
	_put(deadline_label, d.deadline_text())
	_put(penalty_label, d.penalty_text())
	var fine := d.has_fine_print()
	_put(fine_label, "########  (revealed when you sign)")
	if fine_label:
		fine_label.visible = fine
	if fine_row:
		fine_row.visible = fine
	scale = Vector2.ONE


func _put(l: Label, t: String) -> void:
	if l:
		l.text = t


func _tint(l: Label, c: Color) -> void:
	if l:
		l.add_theme_color_override("font_color", c)


func _ignore_mouse(n: Node) -> void:
	for ch in n.get_children():
		if ch is Control:
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(ch)


func _hover(on: bool) -> void:
	if disabled:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * (hover_scale if on else 1.0), 0.1)
