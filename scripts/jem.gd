extends RigidBody2D

static var latest_id = 0
var type: int				# Pawn, Knight etc.
var is_black: bool			# is this piece black?
var is_taken: bool			# Marker to skip this jem when board.set_all_jems_frozen()
var sprite: Sprite2D
var fade_time: float = 0.5
var id: int


# Allows manipulation of physics attributes without messing stuff up; we are keeping y-component of velocity = 0
func _integrate_forces(state):
	var vel = state.get_linear_velocity ()
	if !is_taken:
		state.set_linear_velocity (Vector2 (0, vel.y))


# Stop jem from experiencing physics - can still be moved via tween (as in swapping)
func set_frozen(a_is_frozen):
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = a_is_frozen
	

# Actions when this piece is taken
func on_taken():
	if is_queued_for_deletion():
		return
	set_ethereal()
	z_index = 10
	toss()
	get_tree().create_timer(3).connect("timeout", queue_free)
	print("jem with id: " + str(id) + " queue_free")



# Actions when this piece is part of a match
func on_matched():
	if is_queued_for_deletion():
		return
	set_ethereal()
	z_index = 10			# Ensures this piece is visible while shrinking
	shrink()
	get_tree().create_timer(fade_time).connect("timeout", queue_free)
	print("jem with id: " + str(id) + " queue_free")
	


func shrink():
	sprite = get_node("sprite")
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, 'scale', Vector2(0.25, 0.25), fade_time)
	set_frozen(true)


func toss():
	var magnitude: float = randf_range(500.0, 1500.0)
	var angle: float = randf_range(30.0, 150.0) * (PI / 180.0)
	var avelocity: float = randf_range(-2 * PI, 2 * PI)
	var v_x: float = magnitude * cos(angle)
	var v_y: float = -magnitude * sin(angle)
	linear_velocity = Vector2(v_x, v_y)
	lock_rotation = false
	angular_velocity = avelocity

	
func set_ethereal():
	set_collision_layer_value(2, false)
	set_collision_mask_value(2, false)
	set_collision_layer_value(10, true)
	set_collision_mask_value(10, true)
	is_taken = true
	freeze = false	
	
