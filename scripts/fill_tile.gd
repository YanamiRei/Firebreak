class_name FillTile
extends Node2D

func play(delay: float) -> void:
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "scale", Vector2.ONE * 1.2, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.08)

func drain(duration := 0.4) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_callback(queue_free)
