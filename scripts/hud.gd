class_name Hud
extends CanvasLayer

signal submit_pressed
signal reset_pressed
signal retry_pressed
signal contract_resolved(data: ContractData)
signal broken_dismissed
signal fine_print_dismissed

@export_group("Status labels")
@export var floor_label: Label
@export var score_label: Label
@export var walls_label: Label
@export var area_label: Label
@export var stairs_label: Label
@export var contracts_label: RichTextLabel
@export var best_label: Label

@export_group("Buttons")
@export var submit_button: Button
@export var reset_button: Button
@export var pause_button: Button

@export_group("Pickup feed (bottom-left)")
@export var feed_box: VBoxContainer
@export var toast_scene: PackedScene
@export var max_toasts := 5


@export_group("Contract offer")
@export var offer_panel: Control
@export var offer_buttons: Array[Button]
@export var decline_button: Button

@export_group("Contract confirmation")
@export var confirm_panel: Control
@export var confirm_label: Label
@export var sign_button: Button
@export var back_button: Button

@export_group("Contract broken")
@export var broken_panel: Control
@export var broken_label: Label
@export var broken_continue_button: Button

@export_group("Fine print reveal (optional)")
@export var fine_print_panel: Control
@export var fine_print_title: Label
@export var fine_print_label: Label
@export var fine_print_continue_button: Button

@export_group("Game over")
@export var game_over_panel: Control
@export var game_over_label: Label
@export var retry_button: Button
@export var run_floors_label: Label
@export var run_score_label: Label
@export var run_items_label: Label
@export var run_contracts_label: Label
@export var game_over_banner: Label

var _offer: Array[ContractData] = []
var _pending: ContractData

func _ready() -> void:

	submit_button.pressed.connect(func(): submit_pressed.emit())
	reset_button.pressed.connect(func(): reset_pressed.emit())
	retry_button.pressed.connect(func(): retry_pressed.emit())
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
	var menu_button := get_node_or_null("GameOverPanel/Margin/GameOverBox/MenuButton") as Button
	if menu_button:
		menu_button.pressed.connect(func(): SceneManager.fade_scene("res://scenes/menus/main_menu.tscn"))
	decline_button.pressed.connect(_on_decline)
	sign_button.pressed.connect(_on_sign)
	back_button.pressed.connect(_on_back)
	broken_continue_button.pressed.connect(_on_broken_continue)
	if fine_print_continue_button:
		fine_print_continue_button.pressed.connect(_on_fine_print_continue)
	if fine_print_panel:
		fine_print_panel.hide()
	for i in offer_buttons.size():
		offer_buttons[i].pressed.connect(_on_offer_button.bind(i))
	offer_panel.hide()
	confirm_panel.hide()
	broken_panel.hide()
	game_over_panel.hide()
	for ch in feed_box.get_children():
		ch.queue_free()


func set_run_info(floor_number: int, score: int, portable_stairs: int, contract_lines: Array[String]) -> void:
	floor_label.text = "Floor %d" % floor_number
	score_label.text = str(score)
	stairs_label.text = str(portable_stairs)
	if best_label:
		best_label.text = str(maxi(Highscores.best_score(), score))
	if contract_lines.is_empty():
		contracts_label.text = "[color=#8e9db0]None active[/color]"
	else:
		contracts_label.text = "\n\n".join(contract_lines)

func set_stats(walls_left: int, walls_budget: int, area: int, sealed: bool) -> void:
	walls_label.text = "%d/%d" % [walls_budget - walls_left, walls_budget]
	walls_label.modulate = Color(1.0, 0.55, 0.5) if walls_left <= 0 else (Color(1.0, 0.85, 0.45) if walls_left <= 2 else Color.WHITE)
	area_label.text = "Area: %d  (%s)" % [area, "SEALED" if sealed else "OPEN"]
	area_label.modulate = Color(0.6, 1.0, 0.6) if sealed else Color(1.0, 0.6, 0.5)


func set_planning(enabled: bool) -> void:
	submit_button.disabled = not enabled
	reset_button.disabled = not enabled


#  pickup feed

func push_pickup(data: ItemData, amount: int) -> void:
	if feed_box == null or toast_scene == null:
		return
	for t in feed_box.get_children():
		if t is PickupToast and not t.is_queued_for_deletion() and t.tracks(data):
			t.add_amount(amount)
			return
	var toast: PickupToast = toast_scene.instantiate()
	feed_box.add_child(toast)
	toast.show_item(data)
	toast.add_amount(amount)
	_trim_feed()

func push_notice(text: String, icon: Texture2D = null, tint := Color.WHITE) -> void:
	if feed_box == null or toast_scene == null:
		return
	var toast: PickupToast = toast_scene.instantiate()
	feed_box.add_child(toast)
	toast.show_notice(text, icon)
	toast.modulate = Color(tint, 1.0)
	_trim_feed()


func push_unmask(real: ItemData, mask: ItemData, bad: bool) -> void:
	var was := mask.display_name if mask != null else "?"
	var tint := Color(1.0, 0.55, 0.5) if bad else Color(1.0, 0.92, 0.55)
	var head := "CURSED! " if bad else "UNMASKED! "
	push_notice("%s%s (was %s)" % [head, real.display_name, was], real.icon, tint)


func _trim_feed() -> void:
	var live: Array[Node] = []
	for t in feed_box.get_children():
		if not t.is_queued_for_deletion():
			live.append(t)
	while live.size() > max_toasts:
		live.pop_front().queue_free()


func show_contract_offer(options: Array[ContractData]) -> void:
	_offer = options
	_pending = null
	confirm_panel.hide()

	for i in offer_buttons.size():
		var b := offer_buttons[i]
		if i < options.size():
			if b is ContractCard:
				(b as ContractCard).show_contract(options[i])
			else:
				b.text = options[i].describe()
			b.show()
		else:
			b.hide()
	offer_panel.show()


func _on_offer_button(i: int) -> void:
	if i >= _offer.size():
		return
	_pending = _offer[i]
	confirm_label.text = "%s\n\nOnce you sign, there is no taking it back." % _pending.describe()
	offer_panel.hide()
	confirm_panel.show()


func _on_sign() -> void:
	var chosen := _pending
	_pending = null
	confirm_panel.hide()
	contract_resolved.emit(chosen)


func _on_back() -> void:
	_pending = null
	confirm_panel.hide()
	offer_panel.show()



func _on_decline() -> void:
	_pending = null

	offer_panel.hide()
	contract_resolved.emit(null)


# contract broken

func show_contract_broken(entries: Array) -> void:
	var blocks: PackedStringArray = []
	for e in entries:
		var data: ContractData = e["data"]
		blocks.append("%s\n%s\nPenalty: %s" % [data.title.to_upper(), e["reason"], e["penalty"]])
	broken_label.text = "\n\n".join(blocks)
	broken_panel.show()
	broken_panel.pivot_offset = broken_panel.size / 2.0
	broken_panel.scale = Vector2(1.15, 1.15)
	broken_panel.modulate = Color(1.7, 0.5, 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(broken_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(broken_panel, "modulate", Color.WHITE, 0.5)


func _on_broken_continue() -> void:
	broken_panel.hide()
	broken_dismissed.emit()


# fine print

func has_fine_print_panel() -> bool:
	return fine_print_panel != null and fine_print_label != null and fine_print_continue_button != null


func show_fine_print(data: ContractData, text: String, bad: bool) -> void:
	if not has_fine_print_panel():
		push_notice("FINE PRINT (%s): %s" % [data.title, text.replace("\n", " ")], null,
			Color(1.0, 0.55, 0.5) if bad else Color(1.0, 0.92, 0.55))
		fine_print_dismissed.emit.call_deferred()
		return
	if fine_print_title:
		fine_print_title.text = "FINE PRINT REVEALED" if bad else "FINE PRINT: A PLEASANT SURPRISE"
	fine_print_label.text = "%s\n\n%s" % [data.title.to_upper(), text]
	fine_print_panel.show()
	fine_print_panel.pivot_offset = fine_print_panel.size / 2.0
	fine_print_panel.scale = Vector2(0.7, 0.7)
	fine_print_panel.modulate = Color(1.7, 0.55, 0.5) if bad else Color(1.5, 1.4, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(fine_print_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(fine_print_panel, "modulate", Color.WHITE, 0.6)


func _on_fine_print_continue() -> void:
	fine_print_panel.hide()
	fine_print_dismissed.emit()


func _on_pause_pressed() -> void:
	var event := InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	Input.parse_input_event(event)


func show_run_over(reason: String, floors: int, score: int, items: int, kept: int, broken: int, banner: String) -> void:
	game_over_label.text = reason
	run_floors_label.text = str(floors)
	run_score_label.text = str(score)
	run_items_label.text = str(items)
	run_contracts_label.text = "%d kept / %d broken" % [kept, broken]
	game_over_banner.text = banner
	game_over_banner.visible = banner != ""
	game_over_panel.show()


func show_game_over(text: String) -> void:
	game_over_label.text = text
	game_over_panel.show()


func hide_game_over() -> void:
	game_over_panel.hide()


func _on_menu_button_pressed() -> void:
	SceneManager.fade_scene("res://scenes/menus/main_menu.tscn")
