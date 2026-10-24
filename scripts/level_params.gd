class_name LevelParams
extends Resource

@export_group("Grid")
@export var grid_size := Vector2i(22, 22)
@export_range(2, 6) var lattice_spacing := 3
@export_range(0.0, 1.0) var edge_gap_chance := 0.28
@export_range(0.0, 1.0) var edge_half_chance := 0.22

@export_group("Solvability")
@export var min_cut := 3
@export_range(1, 10) var min_cut_floor_step := 3
@export var max_attempts := 80
@export var exit_min_distance := 3
@export var exit_max_distance := 9
@export var exit_count := 2

@export_group("Items")
@export var item_count := 6
@export var min_reachable_items := 3
@export_range(0.0, 1.0) var mask_chance := 0.35
@export_range(0.0, 1.0) var tell_chance := 0.4

@export_group("Run economy")
@export var start_walls := 12

@export var max_carry_over := 0
@export var walls_per_floor := 6
@export var contract_every_floors := 2
@export var contract_score_step := 80
@export var max_active_contracts := 3
