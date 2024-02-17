extends Node


var pegs: Array[Array]		# Passed from board.initialize()
var all_peg_sets: Array[Array]
var size: Vector2i
var all_matched_sets: Array[Array]


func initialize(a_pegs: Array[Array]):
	pegs = a_pegs
	size = Vector2i(pegs.size(), pegs[0].size())
	all_matched_sets = []
	setup_peg_sets()
	
	
func setup_peg_sets():
	all_peg_sets = []
	var i_set: Array[Array]
	for col: Array[StaticBody2D] in pegs:
		for peg: StaticBody2D in col:
			i_set = jem_sets_to_evaluate(peg)
			for ii_set in i_set:
				all_peg_sets.append(ii_set)


#Returns a set of sets of pegs; each set of jems(each owned by a given peg) is to be evaluated as a possilbe matched set	
func jem_sets_to_evaluate(a_seed_peg: StaticBody2D) -> Array[Array]:
	var set_of_sets: Array[Array] = []
	var i_set: Array[StaticBody2D]
	for count: int in [3, 4, 5]:
		i_set = linear_set(a_seed_peg, count, true)
		if i_set.size() == count:
			set_of_sets.append(i_set)
	for count: int in [3, 4, 5]:
		i_set = linear_set(a_seed_peg, count, false)
		if i_set.size() == count:
			set_of_sets.append(i_set)
	for count: int in [3, 4, 5]:
		i_set = diagonal_set(a_seed_peg, count, true)
		if i_set.size() == count:
			set_of_sets.append(i_set)
	for count: int in [3, 4, 5]:
		i_set = diagonal_set(a_seed_peg, count, false)
		if i_set.size() == count:
			set_of_sets.append(i_set)
	return set_of_sets


func find_matched_sets():
	for i_set: Array[StaticBody2D] in all_peg_sets:
		var i_peg: StaticBody2D = i_set[0]
		if i_peg.column == 1 && i_peg.row == 2:
			pass
		if is_matching_set(i_set):
			all_matched_sets.append(i_set)


func clear_all_matched_sets():
	all_matched_sets.clear()

#Set returned is up to size a_length (including a_seed_peg) in row or column direction
func linear_set(a_seed_peg: StaticBody2D, a_length: int, a_is_horizontal: bool) -> Array[StaticBody2D]:
	if a_seed_peg.column == 5:
		pass
	var peg_set: Array[StaticBody2D] = [a_seed_peg]
	var i: int = 1
	var i_peg: StaticBody2D = a_seed_peg
	while i < a_length:
		if a_is_horizontal:
			i_peg = peg_to_right(i_peg)
		else:
			i_peg = peg_below(i_peg)
		if i_peg == null:
			return peg_set
		peg_set.append(i_peg)
		i = i + 1
	return peg_set


func diagonal_set(a_seed_peg: StaticBody2D, a_length: int, a_is_up: bool) -> Array[StaticBody2D]:
	var peg_set: Array[StaticBody2D] = [a_seed_peg]
	var i: int = 1
	var i_peg: StaticBody2D = a_seed_peg
	while i < a_length:
		if a_is_up:
			i_peg = peg_up_right(i_peg)
		else:
			i_peg = peg_down_right(i_peg)
		if i_peg == null:
			return peg_set
		peg_set.append(i_peg)
		i = i + 1
	return peg_set


func peg_up_right(a_seed_peg: StaticBody2D) -> StaticBody2D:
	var col: int = a_seed_peg.column + 1
	var row: int = a_seed_peg.row - 1
	if is_valid_peg_coord(Vector2i(col, row)):
		return pegs[col][row]
	return null


func peg_down_right(a_seed_peg: StaticBody2D) -> StaticBody2D:
	var col: int = a_seed_peg.column + 1
	var row: int = a_seed_peg.row + 1
	if is_valid_peg_coord(Vector2i(col, row)):
		return pegs[col][row]
	return null
	
	
func peg_to_right(a_seed_peg: StaticBody2D) -> StaticBody2D:
	var col: int = a_seed_peg.column + 1
	var row: int = a_seed_peg.row
	if col < size.x:
		return pegs[col][row]
	return null


func peg_below(a_seed_peg: StaticBody2D) -> StaticBody2D:
	var col: int = a_seed_peg.column
	var row: int = a_seed_peg.row + 1
	if row < size.y:
		return pegs[col][row]
	return null


func is_valid_peg_coord(a_coord: Vector2i) -> bool:
	var col: int = a_coord.x
	var row: int = a_coord.y
	var is_valid_col: bool = col >= 0 && col < size.x
	var is_valid_row: bool = row >= 0 && row < size.y
	return is_valid_col && is_valid_row  
	

func is_matching_set(a_pegs: Array[StaticBody2D]) -> bool:
	return is_all_non_null_set(a_pegs) && is_contiguous_set(a_pegs) && (is_linear_set(a_pegs) || is_diagonal_set(a_pegs)) && is_match_by_value(a_pegs)
	
	
func is_all_non_null_set(a_pegs: Array[StaticBody2D]) -> bool:
	for i_peg: StaticBody2D in a_pegs:
		if i_peg.jem() == null: return false
	return true


func is_horizontal_set(a_pegs: Array[StaticBody2D]) -> bool:
	for i: int in range(1, a_pegs.size()):
		if a_pegs[i - 1].row != a_pegs[i].row:
			return false
	return true


func is_vertical_set(a_pegs: Array[StaticBody2D]) -> bool:
	for i: int in range(1, a_pegs.size()):
		if a_pegs[i - 1].column != a_pegs[i].column:
			return false
	return true


func is_linear_set(a_pegs: Array[StaticBody2D]) -> bool:
	return is_horizontal_set(a_pegs) || is_vertical_set(a_pegs)


func is_diagonal_set(a_pegs: Array[StaticBody2D]) -> bool:
	var temp_pegs: Array[StaticBody2D] = Array(a_pegs)
	for i_peg: StaticBody2D in a_pegs:
		if !is_any_diagonally_adjacent(i_peg, temp_pegs):
			return false
	return true


func is_match_by_value(a_pegs: Array[StaticBody2D]) -> bool:
	#var area: Area2D = a_pegs[0].area
	var type: int = a_pegs[0].jem().type
	var is_black: bool = a_pegs[0].jem().is_black
	for i_peg: StaticBody2D in a_pegs:
		if i_peg.jem() == null: return false
		if i_peg.jem().type != type || i_peg.jem().is_black != is_black:
			return false
	return true


# Is every peg in a_pegs adjacent (inc diagonally) to some other peg in a_pegs?
func is_contiguous_set(a_pegs: Array[StaticBody2D]) -> bool:
	var temp_pegs: Array[StaticBody2D] = Array(a_pegs)
	for i_peg:StaticBody2D in a_pegs:
		if !is_any_adjacent(i_peg, temp_pegs) && !is_any_diagonally_adjacent(i_peg, temp_pegs):
			return false
	return true


# Is a_peg adjacent to any member of a_pegs?
func is_any_adjacent(a_peg: StaticBody2D, a_pegs:Array[StaticBody2D]) -> bool:
	#var is_adjacent: bool = false
	for i_peg: StaticBody2D in a_pegs:
		if is_pair_adjacent(a_peg, i_peg):
			return true
	return false	


func is_any_diagonally_adjacent(a_peg: StaticBody2D, a_pegs:Array[StaticBody2D]) -> bool:
	for i_peg: StaticBody2D in a_pegs:
		if is_pair_diagonally_adjacent(a_peg, i_peg):
			return true
	return false	


func is_pair_adjacent(a_peg_1, a_peg_2: StaticBody2D) -> bool:
	var coord_1: Vector2 = Vector2(a_peg_1.column, a_peg_1.row)
	var coord_2: Vector2 = Vector2(a_peg_2.column, a_peg_2.row)
	return is_adjacent(coord_1, coord_2)
	

func is_pair_diagonally_adjacent(a_peg_1, a_peg_2: StaticBody2D) -> bool:
	var coord_1: Vector2 = Vector2(a_peg_1.column, a_peg_1.row)
	var coord_2: Vector2 = Vector2(a_peg_2.column, a_peg_2.row)
	return is_diagonally_adjacent(coord_1, coord_2)
	

func is_pair_radially_adjacent(a_peg_1, a_peg_2: StaticBody2D) -> bool:
	return abs(a_peg_1.column - a_peg_2.column) <= 1 && abs(a_peg_1.row - a_peg_2.row) <= 1


func is_adjacent(a_vec1: Vector2i, a_vec2: Vector2i) -> bool:
	var value: int = absi(a_vec1.x - a_vec2.x) + abs(a_vec1.y - a_vec2.y)
	return value == 1


func is_diagonally_adjacent(a_vec1: Vector2i, a_vec2: Vector2i) -> bool:
	var delta_x: int = absi(a_vec1.x - a_vec2.x)
	var delta_y: int = abs(a_vec1.y - a_vec2.y)
	return delta_y == 1 && delta_x == 1
	
