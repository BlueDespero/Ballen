extends CharacterBody2D

var dragging: bool = false
var spawn_point: Vector2i
@export var player_board: TileMapLayer

func _ready() -> void:
	spawn_point = Vector2i(self.position.x, self.position.y)

func _process(delta: float) -> void:
	if dragging:
		var mousepos = get_viewport().get_mouse_position()
		self.position = Vector2(mousepos.x, mousepos.y)
		
func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event : InputEventMouseButton = event
		if event.is_pressed():
			dragging = true
		if event.is_released():
			dragging = false
			snap_to_grid()
			
func snap_to_grid() -> void:
	var chosen_cell_coords : Vector2i =  player_board.local_to_map(player_board.get_local_mouse_position())
	var chosen_cell : TileData = player_board.get_cell_tile_data(chosen_cell_coords)
	# Cell not in Player Board
	if not chosen_cell:
		return_to_spawn()
		return
	# Cell in Player board
	snap_to_tile(chosen_cell_coords)
	
func return_to_spawn() -> void:
	self.position = spawn_point

func snap_to_tile(cell_coords: Vector2i) -> void:
		self.position = player_board.to_global(player_board.map_to_local(cell_coords))
