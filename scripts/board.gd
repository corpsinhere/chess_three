extends Node2D

signal pegs_positioned(size: Vector2)						# Size is pixel width and height (as opposed to tile count)
signal jems_requested(a_jem_count: int)
signal jems_accepted()

#region Globals
@onready var match_finder: Node = get_node("match_finder")	# Node which holds matching logic
var pegs: Array[Array]										# Array of columns which are arrays of pegs(StaticBody2D); e.g. pegs[2][5] refs peg at 3rd column and 6th row
var all_peg_sets: Array[Array] = []							# Precomputed all possible sets of 3, 4, 5 pegs (inc diag) which might make a matched set
var all_matched_sets: Array[Array] = []						# Of the sets in all_peg_sets which _currently_ have a matching set
var new_jems: Array[RigidBody2D]							# Jems just delivered from tile_factory to be dropped onto board
var all_extant_jems: Array[RigidBody2D] = []				# All jems added during this game which have not been deleted
var swap_jem_pair: Array[RigidBody2D] = [] 					# Holds swap_jem and swap_co_jem while swapping; we usually keep track of jems by assoc peg - this does not work while swapping
var blocks: Array[StaticBody2D]								# Make up the walls and floor of the board
var target_pegs: Array[StaticBody2D] = []					# Set of pegs which could be attacked by selected peg
var missing_jems: Array[StaticBody2D] = []					# Set of pegs (despite "jem" in the name) which donot currently own a jem
var size: Vector2i											# Column count, row count
var spacing: float											# For spacially setting up pegs and jems
var tile_width: float										# Width in pixels of a tile
var is_initialized: bool									# Has the board been initialized
var is_jems_requested: bool									# Has signal jems_requested been triggered and not yet fulfilled?
var is_poling_available: bool								# Is it okay to look for missing jems?
var is_jem_request_fulfilled: bool							# Like it says
var swap_peg: StaticBody2D									# Peg which initiated swap
var swap_co_peg: StaticBody2D								# Other peg participating in swap
var peg_under_mouse: StaticBody2D							# Like it says
var board_state: BoardState									# State determines what actions are allowed
enum BoardState {STATIC, FALLING, SWAPPING}					# List of states
const padding: float = 0.1									# Together with tile_width gives actual space tiles use
const swap_time: float = 0.2								# How long hsould swap take?
#endregion

#region Initialization

func _ready():
	set_board_state(BoardState.FALLING)

func initialize(a_pegs: Array[StaticBody2D], a_blocks: Array[StaticBody2D], a_size: Vector2):
	if is_non_empty_array(a_pegs) && a_size != null && a_pegs.size() == (a_size.x * a_size.y):
		size = a_size
		blocks = a_blocks
		setup_2d_pegs_array(a_pegs)
		define_scale(pegs[0][0])
		match_finder.initialize(pegs)
		is_initialized = true


func setup_2d_pegs_array(a_pegs: Array[StaticBody2D]):
	pegs = new_n_x_m_array(size)
	var index: int = 0
	var i_peg: StaticBody2D
	for i_row: int in range(size.y):
		for i_col: int in range(size.x):
			index = i_row * size.x + i_col
			i_peg = a_pegs[index]
			i_peg.column = i_col
			i_peg.row = i_row
			pegs[i_col][i_row] = i_peg

# Setup pegs and blocks, and then request first batch of jems
func setup_tiles():
	setup_pegs()
	setup_blocks()


# Add pegs to board and connect peg signals to board functions
func setup_pegs():
	var width: int = size.x
	var height: int = size.y
	var area: Area2D
	for row: Array[StaticBody2D] in pegs:
		for peg: StaticBody2D in row:
			area = peg.get_node("Area2D")
			area.peg_entered.connect(on_peg_entered)
			area.peg_exited.connect(on_peg_exited)
			area.jem_deleted.connect(on_delete_jem)
			add_child(peg)
			peg.position = Vector2(peg.column * spacing, peg.row * spacing)	
	pegs_positioned.emit(Vector2(width * spacing, height * spacing))	


func on_delete_jem(_a_peg: StaticBody2D):
	pass

	
# Setup walls and floor
func setup_blocks():
	var block: StaticBody2D
	var index: int = 0
	var width: int = size.x
	var height: int = size.y
	for i in height:
		block = blocks[index]
		add_child(block)
		block.position = Vector2(-1 * spacing, i * spacing)
		index = index + 1
	for i in height:
		block = blocks[index]
		add_child(block)
		block.position = Vector2(width * spacing, i * spacing)
		index = index + 1
	for i in (width + 2):
		block = blocks[index]
		add_child(block)
		block.position = Vector2((i - 1) * spacing, height * spacing)
		index = index + 1


#endregion

func _process(_delta):
	evaluate_board_state()
	if board_state != BoardState.SWAPPING:
		if is_tenth_second_tic() && !is_new_jems_incoming():
			if !is_all_extant_jems_filled():
				#print("Beep")
				pole_pegs_for_missing_jems()
	if is_jems_requested && is_jem_request_fulfilled:
		is_jems_requested = false
		is_jem_request_fulfilled = false
		place_jems()
	process_clicks()


var board_resolved_count: int = 0
var all_non_null_jems_sleeping_count: int = 0
const all_non_null_jems_sleeping_count_limit: int = 4
# Looking at current board_state and jem conditions, change board state if called for
func evaluate_board_state():
	if board_state == BoardState.SWAPPING : return	# If swapping we do not want to interrupt
	if board_state == BoardState.FALLING:			# Change name to BoardState.RESOLVING
		if is_all_non_null_jems_sleeping_count_limit_reached():
			if !is_all_jems_non_null():
				pole_pegs_for_missing_jems()
				all_non_null_jems_sleeping_count = 0
			else:
				do_matching()
		if is_all_extant_jems_sleeping():
			all_non_null_jems_sleeping_count += 1


func is_all_non_null_jems_sleeping_count_limit_reached() -> bool:
	return all_non_null_jems_sleeping_count > all_non_null_jems_sleeping_count_limit

# Computes count of jems required for each column, and then places them
func place_jems():
	if new_jems.is_empty(): return
	var column_counts = [0]		#index == column; value == count
	column_counts.resize(size.x)
	column_counts.fill(0)
	var col: int
	var value: int
	for i_peg: StaticBody2D in missing_jems:
		col = i_peg.column
		value = column_counts[col]
		column_counts[col] = value + 1
	#Go through column_counts - each item is a loop length, to add jems to the referenced column (the current index)
	var index: int = 0	#Index in jems
	var col_num: int = 0	#current column
	for i_col in column_counts: 
		for i_th in i_col:
			if index >= new_jems.size(): return
			add_jem_to_column(new_jems[index], col_num, i_th)
			index = index + 1
		col_num = col_num + 1
	new_jems.clear()

# Process clicks
func process_clicks():
	if board_state == BoardState.SWAPPING:
		return
	if Input.is_action_just_pressed("ui_touch") && swap_peg == null:
		set_swap_peg(peg_under_mouse)
		return
	if Input.is_action_just_pressed("ui_touch") && swap_peg != null:
		swap_co_peg = peg_under_mouse
		return
	# This should be in _process()
	if is_swappable_pair(swap_peg, swap_co_peg):
		set_board_state(BoardState.SWAPPING)
		swap_jems(swap_peg, swap_co_peg)
	else:
		if swap_peg != null && swap_co_peg != null:
			set_swap_peg(null)
			swap_co_peg = null


# Set (or clear) swap_peg and set (or clear) assoc highlights
func set_swap_peg(a_peg: StaticBody2D):
	swap_peg = a_peg
	if a_peg == null:
		clear_all_highlights()
		clear_all_valid_target_highlights()
	else:
		swap_peg.show_highlight(true)
		mark_target_pegs(swap_peg)


# Ensure highlight is turned off for every peg
func clear_all_highlights():
	for column: Array in pegs:
		for i_peg in column:
			i_peg.show_highlight(false)


# Ensure valid target highlight is turned off for every peg
func clear_all_valid_target_highlights():
	for column: Array in pegs:
		for i_peg in column:
			i_peg.show_valid_target_highlight(false)


#region Swapping and Matching

# Could a_peg_1 move to location of a_peg_2?
func is_swappable_pair(a_peg_1, a_peg_2: StaticBody2D) -> bool:
	if a_peg_1 == null || a_peg_2 == null:
		return false
	if a_peg_1.is_jem_null() || a_peg_2.is_jem_null():
		return false
	if is_matching_colors(a_peg_1, a_peg_2):
		return false
	if a_peg_1.jem().type == 3:
		return is_on_diagonal(a_peg_1, a_peg_2)
	if a_peg_1.jem().type == 1:
		return is_on_col_row(a_peg_1, a_peg_2)
	if a_peg_1.jem().type == 5:
		return is_pair_radially_adjacent(a_peg_1, a_peg_2)
	if a_peg_1.jem().type == 4:
		return is_on_diagonal(a_peg_1, a_peg_2) || is_on_col_row(a_peg_1, a_peg_2)
	if a_peg_1.jem().type == 2:
		return is_on_knight_move(a_peg_1, a_peg_2)
	if a_peg_1.jem().type == 0:
		return is_on_pawn_move(a_peg_1, a_peg_2)
	return true


# Show valid_target_highlight for any peg which can be reached by a_peg
func mark_target_pegs(a_peg: StaticBody2D):
	for column: Array in pegs:
		for i_peg: StaticBody2D in column:
			if is_swappable_pair(a_peg, i_peg):
				i_peg.show_valid_target_highlight(true)


# Does jem of a_peg_1 have same color as jem of a_peg_2?
func is_matching_colors(a_peg_1, a_peg_2: StaticBody2D) -> bool:
	if a_peg_1 == null || a_peg_2 == null: return false
	if a_peg_1.is_jem_null() || a_peg_2.is_jem_null(): return false
	return a_peg_1.jem().is_black == a_peg_2.jem().is_black


# Not necessarily adjacent
func is_on_diagonal(a_peg, a_other_peg: StaticBody2D) -> bool:
	return abs(a_peg.column - a_other_peg.column) == abs(a_peg.row - a_other_peg.row)
	
	
# Not necessarily adjacent
func is_on_col_row(a_peg, a_other_peg: StaticBody2D) -> bool:
	return (a_peg.column == a_other_peg.column) || (a_peg.row == a_other_peg.row)


# Is a_other_peg a knight move away from a_peg?
func is_on_knight_move(a_peg, a_other_peg: StaticBody2D) -> bool:
	var cdistance: int = abs(a_peg.column - a_other_peg.column)
	var rdistance: int = abs(a_peg.row - a_other_peg.row)
	return (cdistance == 1 && rdistance == 2) || (cdistance == 2 && rdistance == 1)


# Is a_other_peg up and diagonal from a_peg?
func is_on_pawn_move(a_peg, a_other_peg: StaticBody2D) -> bool:
	return abs(a_peg.column - a_other_peg.column) == 1 && a_peg.row - a_other_peg.row == 1


# Vs swap swap (currently disabled)
func is_take_swap() -> bool:
	return swap_peg.jem().is_black != swap_co_peg.jem().is_black


# Physically swaps jems associated with a_peg and a_co_peg; sets actions to perform after swaps complete
func swap_jems(a_peg: StaticBody2D, a_co_peg: StaticBody2D):
	var jem: RigidBody2D = a_peg.get_node("Area2D").jem
	var co_jem: RigidBody2D = a_co_peg.get_node("Area2D").jem
	if jem == null || co_jem == null:
		return
	swap_jem_pair.clear()
	swap_jem_pair.resize(2)
	swap_jem_pair[0] = jem
	swap_jem_pair[1] = co_jem
	var jem_pos: Vector2 = jem.position
	var co_jem_pos: Vector2 = co_jem.position
	var tween = get_tree().create_tween()
	tween.tween_property(jem, 'position', co_jem_pos, swap_time)
	var co_tween = get_tree().create_tween()
	if !is_take_swap():
		co_tween.tween_property(co_jem, 'position', jem_pos, swap_time)
	else:
		a_co_peg.destroy_jem()
	tween.finished.connect(on_swap_finished)


# Actions to perform on swap completion
func on_swap_finished():
	swap_co_peg.set_jem(swap_jem_pair[0])
	set_swap_peg(null)
	swap_co_peg = null
	do_matching()
	pole_pegs_for_missing_jems()
	#print("set_board_state: FALLING - from on_swap_finished - " + str(Time.get_ticks_msec() / 100))
	set_board_state(BoardState.FALLING)


func do_matching():
	find_matched_sets()
	process_matches()

#endregion


#region Helpers

var start: int
var end: int
func elapsed_time(a_is_start: bool, a_name: String):
	if a_is_start:
		start = Time.get_ticks_usec()
	else:
		end = Time.get_ticks_usec()
		print_debug(a_name + ": " + str((end-start)/1000000.0))


func new_n_x_m_array(a_size: Vector2) -> Array[Array]:
	var new_array: Array[Array] = []
	var row: Array[StaticBody2D]
	for n: int in range(a_size.x):
		row = []
		for m: int in range(a_size.y):
			row.append(null)
		new_array.append(row)
	return new_array


func is_non_empty_array(a_array: Array) -> bool:
	return (a_array != null && !a_array.is_empty())


#endregion

#Add a jem to a_column column above the board, at stacked position a_ith
func add_jem_to_column(a_jem: RigidBody2D, a_column: int, a_ith: int):
	add_child(a_jem)
	a_jem.position = Vector2(a_column * spacing, -(a_ith + 2) * spacing)


#Check each peg for a null jem and add peg to missing_jems
func pole_pegs_for_missing_jems():
	missing_jems.clear()
	var area: Area2D
	for row: Array[StaticBody2D] in pegs:
		for peg: StaticBody2D in row:
			area = peg.get_node("Area2D")
			if area.jem == null:
				missing_jems.append(peg)
	if !missing_jems.is_empty() && !is_jems_requested:
		if is_new_jems_incoming(): return
		request_jems()
		#print("set_board_state: FALLING - from pole_pegs_for_missing_jems - " + str(Time.get_ticks_msec() / 100))
		set_board_state(BoardState.FALLING)
	#set_is_poling_available(false)


# Make all jems immune to gravity
func set_all_jems_frozen(a_is_frozen: bool):
	var t_jems: Array[RigidBody2D] = current_jems()
	for jem: RigidBody2D in t_jems:
		if !jem.is_taken:
			jem.set_frozen(a_is_frozen)
	if a_is_frozen:
		align_all_jems()


# Snap jems to center of peg-owner
func align_all_jems():
	var jem: RigidBody2D
	for row: Array[StaticBody2D] in pegs:
		for i_peg: StaticBody2D in row:
			jem = i_peg.jem()
			if jem != null:
				jem.position = i_peg.position


# All jems currently claimed by a peg
func current_jems() -> Array[RigidBody2D]:
	var jems: Array[RigidBody2D] = []
	for row: Array[StaticBody2D] in pegs:
		for peg: StaticBody2D in row:
			if !(peg.jem() == null || peg.jem().is_queued_for_deletion()):
				jems.append(peg.jem())
	return jems


#Send out a signal that jems are needed
func request_jems():
	var total: int = size.x * size.y
	var count: int = total - new_jems.size()
	jems_requested.emit(count)
	is_jems_requested = true


# Are we inside the jem fulfilment interval?
func is_new_jems_incoming() -> bool:
	return is_jems_requested && !is_jem_request_fulfilled


# Is true about every 0.1 sec
func is_tenth_second_tic() -> bool:
	var current_time: int = Time.get_ticks_msec()
	return current_time % 100 == 0


# Why do we need this and also current_jems()?
func jem_count() -> int:
	var count: int = 0
	for i_column: Array[StaticBody2D] in pegs:
		for i_peg: StaticBody2D in i_column:
			if !i_peg.is_jem_null():
				count += 1
	return count


#Accept the jems requested by request_jems()
func accept_jems(a_jems: Array[RigidBody2D]):
	new_jems = a_jems
	process_into_all_extant_jems(a_jems)
	is_jem_request_fulfilled = true


# Remove all deleted jems from all_extant_jems and then append a_jems
func process_into_all_extant_jems(a_jems: Array[RigidBody2D]):
	tidy_all_extant_jems_array()
	all_extant_jems.append_array(a_jems)
	print_debug("all_extant_jems.size(): " + str(all_extant_jems.size()))


func tidy_all_extant_jems_array():
	var temp_array: Array[RigidBody2D] = []
	for i_jem: RigidBody2D in all_extant_jems:
		if !(i_jem == null || i_jem.is_queued_for_deletion()):
			temp_array.append(i_jem)
	all_extant_jems = temp_array


func is_all_extant_jems_filled() -> bool:
	return all_extant_jems.size() == size.x * size.y


# Takes a tile.tcsn and uses its width to set scale
func define_scale(tile: StaticBody2D):
	tile_width = tile.get_node("peg_shape").shape.get_rect().size.x
	spacing = tile_width + padding


#Does every peg have a sleeping jem? (null jems count as not sleeping)
func is_all_jems_sleeping() -> bool:
	var is_all_sleeping: bool = false
	var area: Area2D
	if is_initialized:
		is_all_sleeping = true
		var jem: RigidBody2D
		for row: Array[StaticBody2D] in pegs:
			for i_peg: StaticBody2D in row:
				area = i_peg.get_node("Area2D")
				if area.jem == null || area.jem.is_queued_for_deletion():
					jem = null
				else:
					jem = i_peg.get_node("Area2D").jem
				is_all_sleeping = jem != null && is_jem_sleeping(jem)
				if !is_all_sleeping:
					return false
	return is_all_sleeping


#Does every peg have a sleeping jem? (null jems *do* count as sleeping)
func is_all_non_null_jems_sleeping() -> bool:
	var is_all_sleeping: bool = false
	var area: Area2D
	if is_initialized:
		is_all_sleeping = true
		var jem: RigidBody2D
		for row: Array[StaticBody2D] in pegs:
			for i_peg: StaticBody2D in row:
				area = i_peg.get_node("Area2D")
				if area.jem == null || area.jem.is_queued_for_deletion():
					jem = null
				else:
					jem = i_peg.get_node("Area2D").jem
				is_all_sleeping = jem == null || is_jem_sleeping(jem)
				if !is_all_sleeping:
					return false
	return is_all_sleeping


func is_all_extant_jems_sleeping() -> bool:
	if is_initialized:
		for i_jem: RigidBody2D in all_extant_jems:
			if !(i_jem == null || i_jem.is_queued_for_deletion()):
				if !is_jem_sleeping(i_jem):
					return false
	return true


# Is they? IS THEY?!
func is_all_jems_non_null() -> bool:
	for col: Array[StaticBody2D] in pegs:
		for i_peg: StaticBody2D in col:
			if i_peg.jem() == null:
				return false
	return true
	

# Why are we using this instead of the built in sleeping function?
func is_jem_sleeping(a_jem: RigidBody2D) -> bool:
	if a_jem == null:
		return false
	return abs(a_jem.linear_velocity.y) < 2.0
	


func set_is_poling_available(a_is_available: bool):
	is_poling_available = a_is_available



func board_state_string_from_board_state(a_state: int) -> String:
	if a_state == 0: return "STATIC"
	if a_state == 1: return "FALLING"
	if a_state == 2: return "SWAPPING"
	return "ERROR"


# This is a mess - probably this should setthe board_state *only* with no side effects.
func set_board_state(a_state: BoardState):
	#print(board_state_string_from_board_state(a_state))
	board_state = a_state
	if board_state == BoardState.STATIC:
		pass
	if board_state == BoardState.FALLING:
		set_all_jems_frozen(false)
	if board_state == BoardState.SWAPPING:
		set_all_jems_frozen(true)


func on_peg_entered(a_peg: StaticBody2D):
	peg_under_mouse = a_peg


func on_peg_exited(_a_peg: StaticBody2D):
	peg_under_mouse = null

#region Matching
func is_pair_radially_adjacent(a_peg_1, a_peg_2: StaticBody2D) -> bool:
	return abs(a_peg_1.column - a_peg_2.column) <= 1 && abs(a_peg_1.row - a_peg_2.row) <= 1


func find_matched_sets():
	match_finder.find_matched_sets()
	all_matched_sets = match_finder.all_matched_sets


func is_any_matches_found() -> bool:
	return !match_finder.all_matched_sets.is_empty()


func process_matches():
	for i_set: Array[StaticBody2D] in all_matched_sets:
		for i_peg: StaticBody2D in i_set:
			i_peg.area.delete_jem()
	all_matched_sets = []
	match_finder.clear_all_matched_sets()

#endregion
