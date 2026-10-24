class_name GridUtil
extends RefCounted

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const NO_CELL := Vector2i(-1, -1)


static func in_bounds(size: Vector2i, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


static func is_border(size: Vector2i, c: Vector2i) -> bool:
	return c.x == 0 or c.y == 0 or c.x == size.x - 1 or c.y == size.y - 1


static func one(c: Vector2i) -> Array[Vector2i]:
	var a: Array[Vector2i] = [c]
	return a


## Breadth-first search from one or more seed cells.
## Returns { "dist": Dictionary (cell -> steps from nearest seed), "order": Array[Vector2i] (visit order) }.
static func bfs(size: Vector2i, blocked: Dictionary, seeds: Array[Vector2i]) -> Dictionary:
	var dist := {}
	var order: Array[Vector2i] = []
	for s in seeds:
		if in_bounds(size, s) and not blocked.has(s) and not dist.has(s):
			dist[s] = 0
			order.append(s)
	var head := 0
	while head < order.size():
		var cur: Vector2i = order[head]
		head += 1
		var d: int = dist[cur]
		for dir in DIRS:
			var nb: Vector2i = cur + dir
			if not in_bounds(size, nb) or blocked.has(nb) or dist.has(nb):
				continue
			dist[nb] = d + 1
			order.append(nb)
	return {"dist": dist, "order": order}


## Same as bfs() plus an "escaped" flag that is true when the filled area touches the edge of the map.
static func flood(size: Vector2i, blocked: Dictionary, start: Vector2i) -> Dictionary:
	var res := bfs(size, blocked, one(start))
	var escaped := false
	var order: Array = res["order"]
	for c in order:
		if is_border(size, c):
			escaped = true
			break
	res["escaped"] = escaped
	return res


static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
