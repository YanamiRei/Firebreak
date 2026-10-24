class_name Board
extends Node2D

enum State { PLANNING, RESOLVING, OFFER, OVER }

@export_group("Scene references")
@export var hud: Hud
@export var floor_layer: TileMapLayer
@export var obstacle_layer: TileMapLayer
@export var wall_layer: TileMapLayer
@export var fx_root: Node2D
@export var entity_root: Node2D
@export var player: Node2D
@export var cursor: Node2D
@export var camera: Camera2D

@export_group("Scenes and data")
@export var item_scene: PackedScene
@export var water_scene: PackedScene
@export var fire_scene: PackedScene
@export var params: LevelParams
@export var exit_data: ItemData
@export var item_pool: Array[ItemData]
@export var contract_pool: Array[ContractData]

@export_group("Tiles (atlas coordinates inside your TileSet)")
@export var tile_source_id := 0
@export var floor_atlas := Vector2i(0, 0)
@export var floor_alt_atlas := Vector2i(1, 0)
@export var obstacle_atlas := Vector2i(2, 0)
@export var wall_autotile_origin := Vector2i(6, 0)
@export var wall_atlas := Vector2i(3, 0)

@export_group("Screen cover")
@export var cover_screen := true
@export var outside_atlas := Vector2i(4, 0)
@export var outside_alt_atlas := Vector2i(5, 0)
@export_range(0.0, 1.0) var floor_alt_chance := 0.12
@export_range(0.0, 1.0) var outside_alt_chance := 0.08
@export var max_screen_margin := 40
@export var ambient_fire := true

@export_range(1, 12) var fire_ring_gap := 2
## Shape of the ring: 2 is a perfect ellipse, higher values make it squarer and hug the board more closely.
@export_range(2.0, 6.0) var ring_shape := 2.5
@export_range(0.0, 0.4) var ring_edge_wobble := 0.15
@export_range(0.01, 0.5) var ring_fade := 0.15
@export_range(0.0, 0.6) var ring_holes := 0.25

@export_group("Fire creep")
@export var fire_creep := true
@export_range(5.0, 300.0, 0.5, "or_greater") var creep_duration := 45.0
@export_range(0.0, 0.9) var creep_jitter := 0.6
@export_range(0.0, 0.2) var breach_step := 0.01



@export_group("Tiles (more)")

## What a burnt wall turns into. (-1, -1) just removes it.
@export var burnt_wall_atlas := Vector2i(-1, -1)
## for later
@export var use_terrain_for_obstacles := false
@export var obstacle_terrain_set := 0
@export var obstacle_terrain := 0

@export_group("Animation")
@export var water_step := 0.04
@export var fire_step := 0.03
@export var random_seed := 0

var state := State.PLANNING
var rng := RandomNumberGenerator.new()
var grid_size := Vector2i(22, 22)
var obstacles := {}
var walls := {}
var entities := {}
var player_cell := Vector2i.ZERO
var current_layout: LevelGenerator.Layout
var walls_budget := 0
var walls_left := 0
var _water_tiles: Array[FillTile] = []
var _ambient_tiles: Array[FillTile] = []
var _fire_cells := {}  
var _creep_times := {}
var _creep_order: Array[Vector2i] = []
var _creep_index := 0
var _creep_clock := 0.0
var _ring_a := 20.0
var _ring_b := 14.0
var _ring_noise := FastNoiseLite.new()
var _hole_noise := FastNoiseLite.new()


@export var music : AudioStream
@export var game_over_music : AudioStream


func _exit_tree() -> void:
	AudioManager.stop_ambience()
	AudioManager.set_tension(0.0)


func _ready() -> void:
	SceneManager._update_current_scene_path()

	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	hud.submit_pressed.connect(_on_submit)
	hud.reset_pressed.connect(_on_reset)
	hud.retry_pressed.connect(_on_retry)
	RunState.changed.connect(_refresh_hud)
	cursor.hide()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_start_run()


func _process(delta: float) -> void:
	if state != State.PLANNING or _creep_order.is_empty():
		return
	_creep_clock += delta
	AudioManager.set_tension(clampf(_creep_clock / creep_duration, 0.0, 1.0))
	while _creep_index < _creep_order.size():
		var c := _creep_order[_creep_index]
		if float(_creep_times[c]) > _creep_clock:
			return
		_creep_index += 1
		var t: FillTile = fire_scene.instantiate()
		fx_root.add_child(t)
		t.global_position = _cell_pos(c)
		t.play(0.0)
		_ambient_tiles.append(t)
		_fire_cells[c] = true
		if _touches_grid(c):
			_on_breach()
			return


# run / floor setup

func _start_run() -> void:
	RunState.new_run(params)
	hud.hide_game_over()
	AudioManager.set_tension(0.0)
	if music:
		AudioManager.play_music(music)
	AudioManager.start_ambience()
	_start_floor()


func _start_floor() -> void:
	state = State.PLANNING
	walls_budget = RunState.begin_floor()
	walls_left = walls_budget
	_clear_floor()
	var layout := LevelGenerator.generate(params, walls_budget, RunState.floor_number, rng, item_pool)
	current_layout = layout
	grid_size = layout.size
	obstacles = layout.obstacles
	player_cell = layout.player
	_paint_terrain()
	_setup_ambient_shape()
	_spawn_ambient_fire()
	_schedule_creep()
	for c in layout.exits:
		_spawn_item(exit_data, null, c, false)
	for entry in layout.items:
		_spawn_item(entry["data"], entry["mask"], entry["cell"], entry["tell"])
	player.global_position = _cell_pos(player_cell)
	player.scale = Vector2.ONE
	player.modulate = Color.WHITE
	player.show()
	_center_camera()
	hud.set_planning(true)
	_refresh_hud()
	_refresh_preview()


func _clear_floor() -> void:
	for ch in entity_root.get_children():
		ch.queue_free()
	for ch in fx_root.get_children():
		ch.queue_free()
	entities.clear()
	walls.clear()
	_water_tiles.clear()
	_ambient_tiles.clear()
	_fire_cells.clear()
	_creep_times.clear()
	_creep_order.clear()
	_creep_index = 0
	_creep_clock = 0.0
	AudioManager.set_tension(0.0)
	floor_layer.clear()
	obstacle_layer.clear()
	wall_layer.clear()


func _paint_terrain() -> void:
	_paint_floor()
	var cells: Array[Vector2i] = []
	for c in obstacles.keys():
		cells.append(c)
	if use_terrain_for_obstacles:
		obstacle_layer.set_cells_terrain_connect(cells, obstacle_terrain_set, obstacle_terrain)
	else:
		for c in cells:
			obstacle_layer.set_cell(c, tile_source_id, _wall_tile(c))


## (N = 1, E = 2, S = 4, W = 8)
func _wall_tile(c: Vector2i) -> Vector2i:
	var mask := 0
	if obstacles.has(c + Vector2i.UP):
		mask |= 1
	if obstacles.has(c + Vector2i.RIGHT):
		mask |= 2
	if obstacles.has(c + Vector2i.DOWN):
		mask |= 4
	if obstacles.has(c + Vector2i.LEFT):
		mask |= 8
	return _tile_or(wall_autotile_origin + Vector2i(mask & 3, mask >> 2), obstacle_atlas)


func _tile_or(atlas: Vector2i, fallback: Vector2i) -> Vector2i:
	if obstacle_layer.tile_set == null:
		return fallback
	var src := obstacle_layer.tile_set.get_source(tile_source_id) as TileSetAtlasSource
	if src != null and src.has_tile(atlas):
		return atlas
	return fallback


func _paint_floor() -> void:
	floor_layer.clear()
	var m := _screen_margin()
	for y in range(-m.y, grid_size.y + m.y):
		for x in range(-m.x, grid_size.x + m.x):
			var c := Vector2i(x, y)
			floor_layer.set_cell(c, tile_source_id, _floor_tile(c))


func _floor_tile(c: Vector2i) -> Vector2i:
	var roll := float(posmod((c.x * 73856093) ^ (c.y * 19349663), 1000)) / 1000.0
	if GridUtil.in_bounds(grid_size, c):
		return floor_alt_atlas if roll < floor_alt_chance else floor_atlas
	return outside_alt_atlas if roll < outside_alt_chance else outside_atlas


func _screen_margin() -> Vector2i:
	if not cover_screen or floor_layer.tile_set == null:
		return Vector2i.ZERO
	var tile := Vector2(floor_layer.tile_set.tile_size) * floor_layer.global_scale.abs()
	var zoom := camera.zoom if camera else Vector2.ONE
	var visible_tiles := get_viewport_rect().size / (tile * zoom)
	var mx := int(ceil((visible_tiles.x - grid_size.x) / 2.0)) + 1
	var my := int(ceil((visible_tiles.y - grid_size.y) / 2.0)) + 1
	return Vector2i(clampi(mx, 0, max_screen_margin), clampi(my, 0, max_screen_margin))


func _on_viewport_resized() -> void:
	if current_layout == null:
		return
	_paint_floor()
	if state == State.PLANNING:
		_spawn_ambient_fire()   # redo the fire around the edge
		_schedule_creep()


# ambient fire

## distance from the grid rectangle
func _grid_distance(c: Vector2i) -> int:
	var dx := maxi(maxi(-c.x, c.x - (grid_size.x - 1)), 0)
	var dy := maxi(maxi(-c.y, c.y - (grid_size.y - 1)), 0)
	return maxi(dx, dy)


func _setup_ambient_shape() -> void:
	var hx := grid_size.x * 0.5
	var hy := grid_size.y * 0.5
	_ring_b = hy + fire_ring_gap
	var room := maxf(0.92 - pow(hy / _ring_b, ring_shape), 0.05)
	_ring_a = maxf(hx + fire_ring_gap, hx / pow(room, 1.0 / ring_shape))
	var seed_value := int(hash([rng.seed, RunState.floor_number]))
	_ring_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ring_noise.frequency = 0.09
	_ring_noise.seed = seed_value
	_hole_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hole_noise.frequency = 0.22
	_hole_noise.seed = seed_value + 1


func _is_ambient(c: Vector2i) -> bool:
	if not ambient_fire:
		return false

	if _grid_distance(c) < maxi(fire_ring_gap - 1, 2 if fire_creep else 1):
		return false
	var dx := (float(c.x) - (grid_size.x - 1) * 0.5) / _ring_a
	var dy := (float(c.y) - (grid_size.y - 1) * 0.5) / _ring_b
	var r := pow(pow(absf(dx), ring_shape) + pow(absf(dy), ring_shape), 1.0 / ring_shape)
	var edge := 1.02 + ring_edge_wobble * _ring_noise.get_noise_2d(c.x, c.y)
	if r < edge:
		return false

	var thickness := (r - edge) / maxf(ring_fade, 0.001)
	var roll := float(posmod((c.x * 19349663) ^ (c.y * 83492791) ^ 5, 1000)) / 1000.0
	if thickness < 1.0 and roll > thickness:
		return false
	# gaps in the fire
	if _hole_noise.get_noise_2d(c.x, c.y) > 0.6 - 2.0 * ring_holes:
		return false
	return true



func _spawn_ambient_fire() -> void:
	for t in _ambient_tiles:
		if is_instance_valid(t):
			_fire_cells.erase(floor_layer.local_to_map(floor_layer.to_local(t.global_position)))
			t.queue_free()
	_ambient_tiles.clear()
	if not ambient_fire:
		return
	var m := _screen_margin()
	for y in range(-m.y, grid_size.y + m.y):
		for x in range(-m.x, grid_size.x + m.x):
			var c := Vector2i(x, y)
			if not _is_ambient(c):
				continue
			var t: FillTile = fire_scene.instantiate()
			fx_root.add_child(t)
			t.global_position = _cell_pos(c)
			t.play(randf() * 0.4)
			_ambient_tiles.append(t)
			_fire_cells[c] = true


func _touches_grid(c: Vector2i) -> bool:
	for d in GridUtil.DIRS:
		if GridUtil.in_bounds(grid_size, c + d):
			return true
	return false


func _schedule_creep() -> void:
	_creep_times.clear()
	_creep_order.clear()
	_creep_index = 0
	if not fire_creep or _fire_cells.is_empty():
		return
	var m := _screen_margin()
	var ext := grid_size + m * 2
	var blocked_ext := {}
	for y in grid_size.y:
		for x in grid_size.x:
			blocked_ext[Vector2i(x, y) + m] = true
	var seeds: Array[Vector2i] = []
	for c in _fire_cells.keys():
		seeds.append(c + m)
	var res := GridUtil.bfs(ext, blocked_ext, seeds)
	var dist: Dictionary = res["dist"]
	var raw := {}
	var nearest := INF
	for ce in dist.keys():
		var c: Vector2i = ce - m
		if _fire_cells.has(c):
			continue
		var roll := float(posmod((c.x * 83492791) ^ (c.y * 19349663) ^ 17, 1000)) / 1000.0
		var due := float(dist[ce]) - roll * creep_jitter
		raw[c] = due
		if _touches_grid(c):
			nearest = minf(nearest, due)
	if raw.is_empty() or nearest == INF:
		return
	var factor := creep_duration / nearest
	for c in raw.keys():
		_creep_times[c] = float(raw[c]) * factor
	_creep_order.assign(raw.keys())
	_creep_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _creep_times[a] < _creep_times[b])


func _spawn_item(data: ItemData, mask: ItemData, cell: Vector2i, show_tell: bool) -> void:
	var item: Item = item_scene.instantiate()
	entity_root.add_child(item)
	item.global_position = _cell_pos(cell)
	item.setup(data, mask, cell, show_tell)
	item.unmasked.connect(_on_item_unmasked)
	entities[cell] = item


func _on_item_unmasked(item: Item, bad: bool) -> void:
	hud.push_unmask(item.data, item.disguise, bad)
	_shake(7.0 if bad else 3.5, 0.3 if bad else 0.2)
	if bad:
		AudioManager.play_ui("error")


func _shake(amount: float, time := 0.25) -> void:
	if camera == null:
		return
	var steps := 6
	var tw := create_tween()
	for i in steps:
		var fade := 1.0 - float(i) / steps
		tw.tween_property(camera, "offset", Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount * fade, time / steps)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.03)


func _cell_pos(c: Vector2i) -> Vector2:
	return floor_layer.to_global(floor_layer.map_to_local(c))


func _center_camera() -> void:
	if camera:
		camera.global_position = (_cell_pos(Vector2i.ZERO) + _cell_pos(grid_size - Vector2i.ONE)) / 2.0


# placing walls

func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLANNING:
		return
	if event is InputEventMouseMotion:
		_update_cursor()
	elif event is InputEventMouseButton and event.pressed:
		var cell := _mouse_cell()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if walls.has(cell):
				_remove_wall(cell)
			elif _can_place(cell):
				_place_wall(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_remove_wall(cell)


func _mouse_cell() -> Vector2i:
	return floor_layer.local_to_map(floor_layer.get_local_mouse_position())


func _can_place(cell: Vector2i) -> bool:
	return (
		walls_left > 0
		and GridUtil.in_bounds(grid_size, cell)
		and not obstacles.has(cell)
		and not walls.has(cell)
		and cell != player_cell
		and not entities.has(cell)
	)


func _place_wall(cell: Vector2i) -> void:
	walls[cell] = true
	wall_layer.set_cell(cell, tile_source_id, wall_atlas)
	walls_left -= 1
	_refresh_preview()


func _remove_wall(cell: Vector2i) -> void:
	if not walls.has(cell):
		return
	walls.erase(cell)
	wall_layer.erase_cell(cell)
	walls_left += 1
	_refresh_preview()


func _update_cursor() -> void:
	var cell := _mouse_cell()
	if not GridUtil.in_bounds(grid_size, cell):
		cursor.hide()
		return
	cursor.show()
	cursor.global_position = _cell_pos(cell)
	var ok := walls.has(cell) or _can_place(cell)
	cursor.modulate = Color(1, 1, 1, 0.85) if ok else Color(1, 0.3, 0.3, 0.6)


func _blocked() -> Dictionary:
	var b := obstacles.duplicate()
	for c in walls:
		b[c] = true
	return b


func _refresh_preview() -> void:
	var res := GridUtil.flood(grid_size, _blocked(), player_cell)
	var order: Array = res["order"]
	hud.set_stats(walls_left, walls_budget, order.size(), not res["escaped"])


func _refresh_hud() -> void:
	hud.set_run_info(RunState.floor_number, RunState.score, RunState.portable_stairs, RunState.contract_lines())


func _on_reset() -> void:
	if state != State.PLANNING:
		return
	for c in walls.keys():
		wall_layer.erase_cell(c)
	walls.clear()
	walls_left = walls_budget
	_refresh_preview()


func _on_retry() -> void:
	_start_run()


# resolving (water, items, fire)

func _on_breach() -> void:
	state = State.RESOLVING
	cursor.hide()
	hud.set_planning(false)
	hud.push_notice("The fire is at the door! Submitting what you've placed...")
	await get_tree().create_timer(0.8).timeout
	await _on_submit(true)


func _on_submit(forced := false) -> void:
	if state != State.PLANNING and not forced:
		return
	state = State.RESOLVING
	cursor.hide()
	hud.set_planning(false)

	var flood := GridUtil.flood(grid_size, _blocked(), player_cell)
	var region: Dictionary = flood["dist"]
	var order: Array = flood["order"]
	var escaped: bool = flood["escaped"]
	var walls_used := walls_budget - walls_left
	var items_got := 0

	# water floods
	await _play_water(order, region)
	if escaped:
		await get_tree().create_timer(0.3).timeout
		for t in _water_tiles:
			if is_instance_valid(t):
				t.drain()
		_water_tiles.clear()
	else:
		RunState.wall_stock = walls_left if params.max_carry_over <= 0 else mini(walls_left, params.max_carry_over)
		items_got = await _collect_items(order)

	# fire sweeps
	await _play_fire(region, escaped, fire_step)

	if escaped:
		await _player_burns()
		_game_over("You weren't sealed in. The fire got you.", "Burned")
		return
	var exit_cell := _find_exit(order)
	var spend_portable := false
	if exit_cell == GridUtil.NO_CELL:
		if RunState.portable_stairs > 0:
			RunState.portable_stairs -= 1
			RunState.changed.emit()
			spend_portable = true
			hud.push_notice("No stairs in your area. Used a portable staircase.", _portable_icon())
			await get_tree().create_timer(0.8).timeout
		else:
			_game_over("Sealed in safely, but there's no way down.", "No way down")
			return
	await _descend(player_cell if spend_portable else exit_cell)

	var result = RunState.finish_floor(order.size(), walls_used, items_got)
	for title in result["kept"]:
		hud.push_notice("Contract kept: %s" % title)
	var broken: Array = result["broken"]
	if not broken.is_empty():
		hud.show_contract_broken(broken)
		await hud.broken_dismissed

	if RunState.contract_due():
		await _offer_contract()
	_start_floor()


func _play_water(order: Array, region: Dictionary) -> void:
	_water_tiles.clear()
	var last := 0.0
	for c in order:
		var t: FillTile = water_scene.instantiate()
		fx_root.add_child(t)
		t.global_position = _cell_pos(c)
		var delay := float(region[c]) * water_step
		t.play(delay)
		_water_tiles.append(t)
		last = maxf(last, delay)
	await get_tree().create_timer(last + 0.35).timeout


## Collection and revealing of masks and items
func _collect_items(order: Array) -> int:
	var count := 0
	for c in order:
		if not entities.has(c):
			continue
		var item: Item = entities[c]
		if item.data.kind == ItemData.Kind.EXIT:
			continue
		if item.is_masked():
			await item.reveal()
		var amount = RunState.apply_item(item.data)
		hud.push_pickup(item.data, amount)
		entities.erase(c)
		await item.collect_to(player.global_position)
		count += 1
	return count


func _play_fire(region: Dictionary, escaped: bool, step: float) -> void:
	var fire_blocked := obstacles.duplicate()
	if not escaped:
		# water protects its own walls
		var doused := {}
		for c in region.keys():
			fire_blocked[c] = true
			for d in GridUtil.DIRS:
				var nb: Vector2i = c + d
				if walls.has(nb):
					doused[nb] = true
		for c in doused.keys():
			fire_blocked[c] = true
			
	var m := _screen_margin()
	var ext := grid_size + m * 2
	var blocked_ext := {}
	for c in fire_blocked.keys():
		blocked_ext[c + m] = true

	var seeds: Array[Vector2i] = []
	for c in _fire_cells.keys():
		seeds.append(c + m)
	if seeds.is_empty():
		for x in ext.x:
			seeds.append(Vector2i(x, 0))
			seeds.append(Vector2i(x, ext.y - 1))
		for y in ext.y:
			seeds.append(Vector2i(0, y))
			seeds.append(Vector2i(ext.x - 1, y))

	var res := GridUtil.bfs(ext, blocked_ext, seeds)

	var dist: Dictionary = res["dist"]
	var order: Array = res["order"]
	var rings := {}
	var max_ring := 0

	for ce in order:
		var d: int = dist[ce]
		if not rings.has(d):
			rings[d] = []
		rings[d].append(ce - m)
		max_ring = maxi(max_ring, d)
	for d in range(0, max_ring + 1):
		var spawned := false
		for c in rings[d]:
			if _fire_cells.has(c):
				continue
			_fire_cells[c] = true
			spawned = true
			var t: FillTile = fire_scene.instantiate()
			fx_root.add_child(t)
			t.global_position = _cell_pos(c)
			t.play(0.0)
			if walls.has(c):
				_burn_wall(c)
			if entities.has(c):
				var item: Item = entities[c]
				if is_instance_valid(item):
					item.burn()
		if spawned:
			await get_tree().create_timer(step).timeout
	await get_tree().create_timer(0.4).timeout



func _burn_wall(c: Vector2i) -> void:
	if not walls.has(c):
		return
	walls.erase(c)
	AudioManager.play_burn()
	if burnt_wall_atlas == Vector2i(-1, -1):
		wall_layer.erase_cell(c)
	else:
		wall_layer.set_cell(c, tile_source_id, burnt_wall_atlas)


func _find_exit(order: Array) -> Vector2i:
	for c in order:
		if entities.has(c):
			var item: Item = entities[c]
			if item.data.kind == ItemData.Kind.EXIT:
				return c
	return GridUtil.NO_CELL


func _player_burns() -> void:
	AudioManager.play_burn()
	var tw := create_tween()
	tw.tween_property(player, "modulate", Color(0.15, 0.08, 0.05), 0.4)
	await tw.finished
	await get_tree().create_timer(0.4).timeout


func _descend(target: Vector2i) -> void:
	if entities.has(target):
		var stairs: Item = entities[target]
		stairs.pulse()
	var tw := create_tween()
	if target != player_cell:
		tw.tween_property(player, "global_position", _cell_pos(target), 0.35)
	tw.tween_property(player, "scale", Vector2.ZERO, 0.3)
	await tw.finished


func _offer_contract() -> void:
	state = State.OFFER
	var options := _pick_contracts(3)
	RunState.mark_offered()
	if options.is_empty():
		return
	hud.show_contract_offer(options)
	var chosen: ContractData = await hud.contract_resolved
	if chosen != null:
		var info := RunState.sign_contract(chosen)
		hud.push_notice("Signed: %s (%s)" % [chosen.title, chosen.reward_text()])
		if info["fine"]:
			await get_tree().create_timer(0.35).timeout
			_shake(6.0 if info["bad"] else 3.0, 0.3)
			if info["bad"]:
				AudioManager.play_ui("error")
			hud.show_fine_print(chosen, info["text"], info["bad"])
			await hud.fine_print_dismissed


func _portable_icon() -> Texture2D:
	for d in item_pool:
		if d != null and d.kind == ItemData.Kind.PORTABLE_STAIRS:
			return d.icon
	return null


func _pick_contracts(count: int) -> Array[ContractData]:
	var pool: Array[ContractData] = []
	for c in contract_pool:
		if c != null and not RunState.is_active(c):
			pool.append(c)
	GridUtil.shuffle(pool, rng)
	var picked: Array[ContractData] = []
	for c in pool:
		if picked.size() >= count:
			break
		picked.append(c)
	return picked


func _game_over(reason: String, cause := "Fired") -> void:
	state = State.OVER
	AudioManager.stop_ambience()
	AudioManager.set_tension(0.0)
	if game_over_music:
		AudioManager.play_music(game_over_music)
	EventManager.player_died.emit()
	AudioManager.play_ui("error")
	var result := RunState.end_run(cause)
	var banner := ""
	if not result.is_empty():
		if result["new_best_score"]:
			banner = "NEW HIGH SCORE!"
		elif result["rank"] > 0:
			banner = "Rank #%d on the leaderboard" % result["rank"]
		else:
			banner = "Best score: %d" % Highscores.best_score()
		if result["new_best_floors"] and not result["new_best_score"]:
			banner += "\nDeepest run so far: floor %d" % (RunState.floor_number - 1)
	hud.show_run_over(reason, RunState.floor_number - 1, RunState.score, RunState.items_collected,
		RunState.contracts_kept, RunState.contracts_broken, banner)
