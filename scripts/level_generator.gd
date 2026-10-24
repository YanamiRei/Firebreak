class_name LevelGenerator
extends RefCounted

const INF_CAP := 1_000_000


class Layout:
	var size := Vector2i.ZERO
	var obstacles := {}
	var player := Vector2i.ZERO
	var exits: Array[Vector2i] = []
	var items: Array[Dictionary] = []	## { cell, data, mask, tell }
	var solution: Array[Vector2i] = []
	var solution_exit := Vector2i.ZERO
	var attempts := 0
	var used_fallback := false


@warning_ignore("integer_division")
static func generate(p: LevelParams, wall_budget: int, floor_number: int, rng: RandomNumberGenerator, item_pool: Array[ItemData]) -> Layout:
	var min_cut := clampi(p.min_cut + (floor_number - 1) / maxi(1, p.min_cut_floor_step), 1, maxi(1, wall_budget - 1))
	var gap_bonus := minf(0.01 * float(floor_number - 1), 0.12)
	var relax_every := maxi(1, p.max_attempts / 4)
	for attempt in range(p.max_attempts):
		var layout := Layout.new()
		layout.size = p.grid_size
		layout.attempts = attempt + 1
		layout.obstacles = _make_lattice(p, p.edge_gap_chance + gap_bonus, p.edge_half_chance, rng)
		var needed := maxi(1, min_cut - attempt / relax_every)
		if _try_place(layout, p, wall_budget, needed, rng, item_pool):
			return layout
	return _fallback(p, rng, item_pool)


# lattice

static func _make_lattice(p: LevelParams, gap_chance: float, half_chance: float, rng: RandomNumberGenerator) -> Dictionary:
	var obs := {}
	var size := p.grid_size
	var s := maxi(2, p.lattice_spacing)
	var xs: Array[int] = []
	var ys: Array[int] = []
	var v := 0
	while v < size.x:
		xs.append(v)
		v += s
	v = 0
	while v < size.y:
		ys.append(v)
		v += s
	for nx in xs:
		for ny in ys:
			obs[Vector2i(nx, ny)] = true
	for yi in ys.size():
		for xi in range(xs.size() - 1):
			_paint_edge(obs, Vector2i(xs[xi], ys[yi]), Vector2i.RIGHT, s - 1, gap_chance, half_chance, rng)
	for xi in xs.size():
		for yi in range(ys.size() - 1):
			_paint_edge(obs, Vector2i(xs[xi], ys[yi]), Vector2i.DOWN, s - 1, gap_chance, half_chance, rng)
	return obs


static func _paint_edge(obs: Dictionary, start: Vector2i, dir: Vector2i, length: int, gap_chance: float, half_chance: float, rng: RandomNumberGenerator) -> void:
	var r := rng.randf()
	if r < gap_chance:
		return
	var skip := -1
	if r < gap_chance + half_chance:
		skip = rng.randi_range(0, length - 1)
	for i in length:
		if i == skip:
			continue
		obs[start + dir * (i + 1)] = true


# placement

static func _try_place(layout: Layout, p: LevelParams, wall_budget: int, min_cut: int, rng: RandomNumberGenerator, item_pool: Array[ItemData]) -> bool:
	var size := layout.size
	var candidates: Array[Vector2i] = []
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			var c := Vector2i(x, y)
			if not layout.obstacles.has(c):
				candidates.append(c)
	if candidates.is_empty():
		return false
	var player := candidates[rng.randi_range(0, candidates.size() - 1)]
	var reach := GridUtil.bfs(size, layout.obstacles, GridUtil.one(player))
	var dist: Dictionary = reach["dist"]
	var order: Array = reach["order"]

	var exit_cands: Array[Vector2i] = []
	for c in order:
		var d: int = dist[c]
		if d >= p.exit_min_distance and d <= p.exit_max_distance and not GridUtil.is_border(size, c):
			exit_cands.append(c)
	if exit_cands.is_empty():
		return false
	GridUtil.shuffle(exit_cands, rng)

	# pick spread-out staircase cells
	var exits: Array[Vector2i] = []
	for c in exit_cands:
		if exits.size() >= p.exit_count:
			break
		var far_enough := true
		for e in exits:
			if absi(e.x - c.x) + absi(e.y - c.y) < 3:
				far_enough = false
		if far_enough:
			exits.append(c)

	# the cells that can never hold a wall
	var fixed := {player: true}
	for e in exits:
		fixed[e] = true

	var best_cost := wall_budget + 1
	var best_cells: Array[Vector2i] = []
	var best_exit := Vector2i.ZERO
	for e in exits:
		var sources: Array[Vector2i] = [player, e]
		var cut := _min_cut(size, layout.obstacles, sources, fixed, wall_budget)
		var cost: int = cut["cost"]
		if cost < min_cut or cost > wall_budget:
			continue
		if cost < best_cost:
			var cells: Array[Vector2i] = []
			for cc in cut["cells"]:
				cells.append(cc)
			layout.player = player
			if not _verify(layout, cells, e):
				continue
			best_cost = cost
			best_cells = cells
			best_exit = e
	if best_cost > wall_budget:
		return false

	layout.player = player
	layout.exits = exits
	layout.solution = best_cells
	layout.solution_exit = best_exit
	_place_items(layout, p, rng, item_pool, reach, fixed)
	return true


static func _verify(layout: Layout, cut: Array[Vector2i], exit_cell: Vector2i) -> bool:
	var blocked := layout.obstacles.duplicate()
	for c in cut:
		blocked[c] = true
	var res := GridUtil.bfs(layout.size, blocked, GridUtil.one(layout.player))
	var dist: Dictionary = res["dist"]
	if not dist.has(exit_cell):
		return false
	var order: Array = res["order"]
	for c in order:
		if GridUtil.is_border(layout.size, c):
			return false
	return true


static func _place_items(layout: Layout, p: LevelParams, rng: RandomNumberGenerator, item_pool: Array[ItemData], reach: Dictionary, fixed: Dictionary) -> void:
	var pool: Array[ItemData] = []
	for d in item_pool:
		if d != null and d.kind != ItemData.Kind.EXIT:
			pool.append(d)
	if pool.is_empty():
		return
	var taken := fixed.duplicate()
	for c in layout.solution:
		taken[c] = true
	var reach_dist: Dictionary = reach["dist"]
	var in_reach: Array[Vector2i] = []
	var anywhere: Array[Vector2i] = []
	for y in range(1, layout.size.y - 1):
		for x in range(1, layout.size.x - 1):
			var c := Vector2i(x, y)
			if layout.obstacles.has(c) or taken.has(c):
				continue
			anywhere.append(c)
			if reach_dist.has(c):
				in_reach.append(c)
	GridUtil.shuffle(in_reach, rng)
	GridUtil.shuffle(anywhere, rng)
	var wanted := mini(p.item_count, anywhere.size())
	var cells: Array[Vector2i] = []
	# a few must be somewhere you can actually get them
	var guaranteed := mini(mini(p.min_reachable_items, wanted), in_reach.size())
	while cells.size() < guaranteed and not in_reach.is_empty():
		var cand: Vector2i = in_reach.pop_back()
		if not taken.has(cand):
			taken[cand] = true
			cells.append(cand)
	while cells.size() < wanted and not anywhere.is_empty():
		var cand2: Vector2i = anywhere.pop_back()
		if not taken.has(cand2):
			taken[cand2] = true
			cells.append(cand2)
	for cell in cells:
		var real := _pick_weighted(pool, rng)
		var mask: ItemData = null
		var wants_mask := real.kind == ItemData.Kind.CURSED or (real.can_be_masked and rng.randf() < p.mask_chance)
		if wants_mask:
			mask = _pick_disguise(pool, real, rng)
		layout.items.append({
			"cell": cell,
			"data": real,
			"mask": mask,
			"tell": mask != null and rng.randf() < p.tell_chance,
		})


static func _pick_weighted(pool: Array[ItemData], rng: RandomNumberGenerator) -> ItemData:
	var total := 0.0
	for d in pool:
		total += maxf(d.spawn_weight, 0.0)
	if total <= 0.0:
		return pool[rng.randi_range(0, pool.size() - 1)]
	var roll := rng.randf() * total
	for d in pool:
		roll -= maxf(d.spawn_weight, 0.0)
		if roll <= 0.0:
			return d
	return pool[pool.size() - 1]


static func _pick_disguise(pool: Array[ItemData], real: ItemData, rng: RandomNumberGenerator) -> ItemData:
	var options: Array[ItemData] = []
	for d in pool:
		if d == real:
			continue
		if real.kind == ItemData.Kind.CURSED and d.kind == ItemData.Kind.CURSED:
			continue
		options.append(d)
	if options.is_empty():
		return null
	return options[rng.randi_range(0, options.size() - 1)]


## Last resort if no random floor passed the checks
static func _fallback(p: LevelParams, rng: RandomNumberGenerator, item_pool: Array[ItemData]) -> Layout:
	var layout := Layout.new()
	layout.size = p.grid_size
	layout.used_fallback = true
	layout.attempts = p.max_attempts
	layout.obstacles = _make_lattice(p, 0.0, 0.0, rng)
	var size := layout.size
	var candidates: Array[Vector2i] = []
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			var c := Vector2i(x, y)
			if not layout.obstacles.has(c):
				candidates.append(c)
	layout.player = candidates[rng.randi_range(0, candidates.size() - 1)]
	var reach := GridUtil.bfs(size, layout.obstacles, GridUtil.one(layout.player))
	var order: Array = reach["order"]
	for c in order:
		if c != layout.player:
			layout.exits.append(c)
			layout.solution_exit = c
			break
	var fixed := {layout.player: true}
	for e in layout.exits:
		fixed[e] = true
	_place_items(layout, p, rng, item_pool, reach, fixed)
	return layout


# min vertex cut

static func _add_edge(to: Array, cap: Array, adj: Array, u: int, v: int, c: int) -> void:
	adj[u].append(to.size())
	to.append(v)
	cap.append(c)
	adj[v].append(to.size())
	to.append(u)
	cap.append(0)


## Returns { "cost": int, "cells": Array }.
static func _min_cut(size: Vector2i, obstacles: Dictionary, sources: Array[Vector2i], fixed: Dictionary, limit: int) -> Dictionary:
	var n_cells := size.x * size.y
	var s_node := n_cells * 2
	var t_node := s_node + 1
	var node_count := n_cells * 2 + 2
	var to: Array = []
	var cap: Array = []
	var adj: Array = []
	for i in node_count:
		adj.append([])

	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			if obstacles.has(c):
				continue
			var in_n := (y * size.x + x) * 2
			var out_n := in_n + 1
			var inner := INF_CAP if fixed.has(c) else 1
			_add_edge(to, cap, adj, in_n, out_n, inner)
			for d in GridUtil.DIRS:
				var nb: Vector2i = c + d
				if GridUtil.in_bounds(size, nb) and not obstacles.has(nb):
					_add_edge(to, cap, adj, out_n, (nb.y * size.x + nb.x) * 2, INF_CAP)
			if GridUtil.is_border(size, c):
				_add_edge(to, cap, adj, out_n, t_node, INF_CAP)
	for s in sources:
		_add_edge(to, cap, adj, s_node, (s.y * size.x + s.x) * 2, INF_CAP)

	var flow := 0
	var seen := PackedByteArray()
	while flow <= limit:
		seen = PackedByteArray()
		seen.resize(node_count)
		var prev := PackedInt32Array()
		prev.resize(node_count)
		prev.fill(-1)
		var queue: Array[int] = [s_node]
		seen[s_node] = 1
		var head := 0
		var found := false
		while head < queue.size() and not found:
			var u: int = queue[head]
			head += 1
			for e in adj[u]:
				if cap[e] > 0:
					var w: int = to[e]
					if seen[w] == 0:
						seen[w] = 1
						prev[w] = e
						queue.append(w)
						if w == t_node:
							found = true
							break
		if not found:
			break
		var bottleneck := INF_CAP * 2
		var node := t_node
		while node != s_node:
			var e2: int = prev[node]
			bottleneck = mini(bottleneck, cap[e2])
			node = to[e2 ^ 1]
		node = t_node
		while node != s_node:
			var e3: int = prev[node]
			cap[e3] -= bottleneck
			cap[e3 ^ 1] += bottleneck
			node = to[e3 ^ 1]
		flow += bottleneck

	if flow > limit:
		return {"cost": limit + 1, "cells": []}

	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var i := (y * size.x + x) * 2
			if seen[i] == 1 and seen[i + 1] == 0:
				cells.append(Vector2i(x, y))
	return {"cost": flow, "cells": cells}
