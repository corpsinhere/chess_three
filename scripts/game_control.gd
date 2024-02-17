extends Node


@onready var board: Node = get_node("board")						# Pysical structure and also responsible for managing jems in play
@onready var tile_factory: Node = get_node("tile_factory")			# Creates jems and pegs and blocks - communicates through contol to board via signals
@onready var viewport_size: Vector2 = get_tree().get_root().size	# In pixels
@onready var camera: Camera2D = get_parent().get_node("Camera2D")	# Accessed for zoom adjustment
var game_size: Vector2												# Size (column count x row count) of current game; should probably be Vector2i
var pegs: Array[RigidBody2D]										# Stationary squares which register the current jem at their 2D pos 
var jems: Array[RigidBody2D]										# Items being matched - in this case: chess pieces
const tile_width: int = 128											# size of a tile in pixes; based on sprite texture size.


# Called when the node enters the scene tree for the first time.
func _ready():
	board.pegs_positioned.connect(on_pegs_positioned)
	board.jems_requested.connect(on_jems_requested)
	game_size = Vector2(4, 4)
	new_game(game_size)


func new_game(size: Vector2):
	board.initialize(tile_factory.new_pegs(size), tile_factory.new_blocks(size), size)
	board.setup_tiles()
	var zoomf: float = 6.0 / size.x	# Would max(size.x, size.y) be better?
	camera.set_zoom(Vector2(zoomf, zoomf))


# Triggered in response to signal board.pegs_positioned	
func on_pegs_positioned(a_size: Vector2):
	position_board(a_size)


# Moves board (vs moving camera) depending on board size
func position_board(a_size: Vector2):
	var x: int = 0.5 * (viewport_size.x - a_size.x + board.tile_width)
	var y: int = -0.5 * (viewport_size.y - a_size.y + board.tile_width * (board.size.y - 9))
	board.position = Vector2(x, y)
	

# Triggered in responce to signal board.jems_requested; returns jems created by tile_factory to board
func on_jems_requested(a_jem_count: int):
	board.accept_jems(tile_factory.new_jems(a_jem_count))
