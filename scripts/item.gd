class_name Item
extends Node2D


@export var icon_sprite: Sprite2D
@export var tell_node: CanvasItem

signal unmasked(item: Item, bad: bool)

@export var reveal_hold := 0.45
@export var good_colour := Color(1.0, 0.85, 0.25)
@export var bad_colour := Color(1.0, 0.25, 0.25)

var data: ItemData
var disguise: ItemData
var cell := Vector2i.ZERO
var gone := false


func setup(real: ItemData, mask: ItemData, at: Vector2i, show_tell: bool) -> void:
	data = real
	disguise = mask
	cell = at
	_show_icon(mask if mask != null else real)
	if tell_node:
		tell_node.visible = mask != null and show_tell


func is_masked() -> bool:
	return disguise != null


func _show_icon(d: ItemData) -> void:
	if icon_sprite and d.icon:
		icon_sprite.texture = d.icon


func _swap_to_real() -> void:
	_show_icon(data)
	if tell_node:
		tell_node.visible = false

class RevealRing extends Node2D:
	var radius := 4.0:
		set(v):
			radius = v
			queue_redraw()
	var alpha := 1.0:
		set(v):
			alpha = v
			queue_redraw()
	var colour := Color.WHITE

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(colour, alpha), 3.0)
		draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 40, Color(colour, alpha * 0.6), 1.5)


func reveal() -> void:
	if disguise == null:
		return
	var bad := data.kind == ItemData.Kind.CURSED
	var colour := bad_colour if bad else good_colour
	var old_mask := disguise

	if tell_node:
		tell_node.visible = true
	var wob := create_tween()
	for i in 4:
		wob.tween_property(self, "rotation", 0.18 if i % 2 == 0 else -0.18, 0.05)
	wob.tween_property(self, "rotation", 0.0, 0.04)
	await wob.finished

	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(3.0, 3.0, 3.0), 0.06)
	tw.parallel().tween_property(self, "scale", Vector2(1.5, 0.6), 0.06)
	tw.tween_callback(_swap_to_real)
	tw.tween_property(self, "modulate", Color.WHITE, 0.2)
	tw.parallel().tween_property(self, "scale", Vector2(0.8, 1.45), 0.1)
	tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.08)
	unmasked.emit(self, bad)
	_spawn_mask_debris(old_mask)
	_spawn_ring(colour)
	_spawn_banner(colour, bad)
	await tw.finished

	z_index = 10
	var hold := create_tween()
	hold.tween_property(self, "scale", Vector2(1.35, 1.35) if bad else Vector2(1.2, 1.2), 0.1)
	hold.tween_interval(reveal_hold)
	await hold.finished
	disguise = null


func _spawn_mask_debris(mask: ItemData) -> void:
	if mask == null or mask.icon == null or get_parent() == null:
		return
	var s := Sprite2D.new()
	s.texture = mask.icon
	s.z_index = 12
	get_parent().add_child(s)
	s.global_position = global_position
	var dx := randf_range(-26.0, 26.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(s, "position", s.position + Vector2(dx, -34.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "rotation", signf(dx) * 3.0, 0.55)
	t.tween_property(s, "modulate:a", 0.0, 0.55).set_delay(0.15)
	t.chain().tween_callback(s.queue_free)


func _spawn_ring(colour: Color) -> void:
	if get_parent() == null:
		return
	var ring := RevealRing.new()
	ring.colour = colour
	ring.z_index = 11
	get_parent().add_child(ring)
	ring.global_position = global_position
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "radius", 34.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "alpha", 0.0, 0.45)
	t.chain().tween_callback(ring.queue_free)


func _spawn_banner(colour: Color, bad: bool) -> void:
	if get_parent() == null:
		return
	var l := Label.new()
	l.text = "CURSED!" if bad else "UNMASKED!"
	l.z_index = 13
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.1))
	l.add_theme_constant_override("outline_size", 6)
	l.size = Vector2(110, 22)
	get_parent().add_child(l)
	l.global_position = global_position + Vector2(-55, -40)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.4, 0.4)
	var t := create_tween()
	t.tween_property(l, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector2.ONE, 0.08)
	t.tween_property(l, "position:y", l.position.y - 14.0, 0.7)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	t.tween_callback(l.queue_free)


func collect_to(target: Vector2) -> void:
	gone = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", target, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(0.3, 0.3), 0.3)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	queue_free()


func pulse() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.1)
	tw.tween_property(self, "scale", Vector2.ONE, 0.1)


func burn() -> void:
	if gone or not is_inside_tree():
		return
	gone = true
	AudioManager.play_burn()
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(0.15, 0.08, 0.05), 0.2)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
