class_name PickupToast
extends PanelContainer

@export var icon_rect: TextureRect
@export var label: Label
@export var lifetime := 2.8
@export var fade_time := 0.4

var count := 0
var total := 0
var _data: ItemData
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_item(d: ItemData) -> void:
	_data = d
	if icon_rect:
		icon_rect.texture = d.icon
		icon_rect.visible = d.icon != null
	_refresh()


func tracks(d: ItemData) -> bool:
	return _data != null and _data == d


func add_amount(amount: int) -> void:
	count += 1
	total += amount
	_refresh()
	_bump()


func show_notice(text: String, icon: Texture2D = null) -> void:
	_data = null
	if label:
		label.text = text
	if icon_rect:
		icon_rect.texture = icon
		icon_rect.visible = icon != null
	_bump()


func _refresh() -> void:
	if label and _data:
		label.text = _data.feed_text(count, total)


func _bump() -> void:
	if _tween:
		_tween.kill()
	modulate.a = 1.0
	pivot_offset = Vector2(0.0, size.y * 0.5)
	scale = Vector2(1.12, 1.12)
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	_tween.tween_interval(lifetime)
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	_tween.tween_callback(queue_free)
