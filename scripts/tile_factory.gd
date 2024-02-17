extends Node2D

var textures: Array[Resource] = []
var dark_square_texture: Resource
var light_square_texture: Resource
var peg_texture: Resource
var jem_prefab
var peg_prefab
var block_prefab
var peg_script
var square
var offset: int = 200
var spacing: int
var peg_offset: int = 0
var jem_offset: int = 100
var height: int = 5
var width: int = 5
var pegs: Array[StaticBody2D]
var jems: Array[RigidBody2D]
var blocks: Array[StaticBody2D]
var textures_by_piece_type: Dictionary


# >[Setup]<

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	load_assets()
	initialize()


# Prepare for new game
func initialize():
	initialize_containers()
	

func initialize_containers():
	pegs = [StaticBody2D.new()]
	blocks = [StaticBody2D.new()]
	jems = [RigidBody2D.new()]
	pegs.clear()
	blocks.clear()
	jems.clear()
	
	
func load_assets():
	load_scenes()
	load_textures()
	

func load_scenes():
	jem_prefab = preload("res://scenes/jem.tscn")
	peg_prefab = preload("res://scenes/peg.tscn")
	block_prefab = preload("res://scenes/boarder_block.tscn")


func load_textures():
	textures.append(load("res://icons/chess_pieces/chess_bishop_black.png"))
	textures_by_piece_type[[3, true]] = textures.back()
	textures.append(load("res://icons/chess_pieces/chess_bishop_white.png"))
	textures_by_piece_type[[3, false]] = textures.back()
	textures.append(load("res://icons/chess_pieces/chess_king_black.png"))
	textures_by_piece_type[[5, true]] = textures.back()
	textures.append(load("res://icons/chess_pieces/chess_king_white.png"))
	textures_by_piece_type[[5, false]] = textures.back()
	textures.append(load("res://icons/chess_pieces/chess_knight_black.png"))
	textures_by_piece_type[[2, true]] = textures.back()
	textures.append(load("res://icons/chess_pieces/chess_knight_white.png"))
	textures_by_piece_type[[2, false]] = textures.back()
	textures.append(load("res://icons/chess_pieces/chess_pawn_black.png"))
	textures_by_piece_type[[0, true]] = textures.back()
	textures.append(load("res://icons/chess_pieces/chess_pawn_white.png"))
	textures_by_piece_type[[0, false]] = textures.back()
	textures.append(load("res://icons/chess_pieces/chess_queen_black.png"))
	textures_by_piece_type[[4, true]] = textures.back()
	textures.append(load("res://icons/chess_pieces/chess_queen_white.png"))
	textures_by_piece_type[[4, false]] = textures.back()
	textures.append(load("res://icons/chess_pieces/chess_rook_black.png"))
	textures_by_piece_type[[1, true]] = textures.back()
	textures.append(load("res://icons/chess_pieces/chess_rook_white.png"))
	textures_by_piece_type[[1, false]] = textures.back()
	peg_texture = load("res://icons/peg.png")
	dark_square_texture = load("res://icons/chess_pieces/dark_square.png")
	light_square_texture = load("res://icons/chess_pieces/light_square.png")
	
# >[End Setup]<

#>[Production]<

func new_pegs(size: Vector2i) -> Array[StaticBody2D]:
	pegs.clear()
	var temp_peg: StaticBody2D
	var count: int = size.x * size.y
	for n in count:
		temp_peg = new_peg()
		temp_peg.name = str(n)
		temp_peg.set_sprite_texture(square_texture(is_black_index(n, size)))
		pegs.append(temp_peg)
	return pegs
	

func new_peg() -> StaticBody2D:
	var peg: StaticBody2D
	peg = peg_prefab.instantiate()
	return peg	
	

func is_black_index(a_index: int, a_size: Vector2i) -> bool:
	var column = a_index % a_size.x
	var row = a_index / a_size.x
	return (column + row) % 2 == 0


func new_jems(a_count: int) -> Array[RigidBody2D]:
	var temp_jems: Array[RigidBody2D] = [RigidBody2D.new()]
	temp_jems.clear()
	for n in a_count: 
		temp_jems.append(new_jem())
	return temp_jems


func new_jem() -> RigidBody2D:
	var jem: RigidBody2D
	jem = jem_prefab.instantiate()
	var key: Array = new_piece_key()
	jem.type = key[0]
	jem.is_black = key[1]
	var sprite = jem.get_node("sprite")
	var texture = textures_by_piece_type[key]
	sprite.texture = texture
	sprite.scale = scale * 0.9
	jem.id = jem.latest_id + 1
	jem.latest_id = jem.id
	return jem	


func new_piece_key() -> Array:
	var is_black: bool = true if (randi() % 2 == 0) else false
	return [randi() % 6, is_black]


func new_blocks(size: Vector2i) -> Array[StaticBody2D]:
	blocks.clear()
	var count: int = size.x + 2 + (2 * size.y)
	for n in count:
		blocks.append(new_block())
	return blocks


func new_block() -> StaticBody2D:
	var block: StaticBody2D
	block = block_prefab.instantiate()
	return block
	
#>[End Production]<	

#>[Helpers]<

func random_sprite() -> Sprite2D: 
	var texture = textures[randi() % 8]
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.name = "sprite"
	return sprite


func square_texture(a_is_black: bool) -> Resource:
	var texture = Resource
	texture = dark_square_texture if a_is_black else light_square_texture
	return texture
	
#>[End Helpers]<	



