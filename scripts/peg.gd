extends StaticBody2D


var column: int
var row: int
var area: Area2D
var highlight: Sprite2D
var valid_target_highlight: Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready():
	area = get_node("Area2D")
	highlight = get_node("highlight")
	valid_target_highlight = get_node("valid_target")


func set_sprite_texture(a_texture: Resource):
	get_node("Sprite2D").texture = a_texture


func jem() -> RigidBody2D:
	#var area: Area2D = get_node("Area2D")
	if !(area.jem == null || area.jem.is_queued_for_deletion()):
		return area.jem
	return null


func set_jem_null():
	area.jem = null


func set_jem(a_jem: RigidBody2D):
	area.jem = a_jem


func is_jem_null() -> bool:
	return jem() == null


func show_highlight(a_is_show: bool):
	highlight.visible = a_is_show
	
	
func show_valid_target_highlight(a_is_show: bool):
	valid_target_highlight.visible = a_is_show
	
	
#func destroy_jem():
	#var temp_jem: RigidBody2D = jem()
	#if temp_jem.is_queued_for_deletion() || temp_jem == null:
		#return
	#set_jem_null()
	#set_jem_ethereal(temp_jem)
	#get_tree().create_timer(3).connect("timeout", temp_jem.queue_free)
	
func destroy_jem():
	var temp_jem: RigidBody2D = jem()
	set_jem_null()
	if temp_jem.is_queued_for_deletion() || temp_jem == null:
		return
	temp_jem.on_taken()
	
	
func set_jem_ethereal(a_jem: RigidBody2D):
	a_jem.set_collision_layer_value(2, false)
	a_jem.set_collision_mask_value(2, false)
	a_jem.is_taken = true
	a_jem.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	a_jem.freeze = true
	
	
	
	
	
	
	
	
