## DevCamera3D is an extension of Camera3D that includes basic mobility functions.
## It will collide with objects on its [param collision_mask], but objects will not collide with it. Effectively, it is a ghost.[br]
## Default behaviours are: esc (action ui_cancel) to toggle mouse mode, scroll mouse wheel up/down to increase/decrease movement speed respectively.
## Hardcoded inputs KEY_E and KEY_Q for vertical movement.
class_name DevCamera3D extends Camera3D

@export_flags_3d_physics var collision_mask : int = 1 : ## The layers in which the node will be physically obstructed by. To disable collisions, set to 0
	set(v):
		collision_mask = v
		if is_instance_valid(_body): _body.collision_mask = v

var _mouse_multiplier : Vector2 = Vector2.ONE
var _move_speed : float = 1.0
var _body : CharacterBody3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_body = CharacterBody3D.new()
	var collider : CollisionShape3D = CollisionShape3D.new()
	_body.add_child.call_deferred(collider)
	collider.shape = SphereShape3D.new()
	_body.collision_mask = collision_mask;
	_on_config_data_changed.call_deferred()
	ConfigHandler.data_changed.connect(_on_config_data_changed, CONNECT_DEFERRED)

func _on_config_data_changed() -> void:
	_mouse_multiplier = ConfigHandler.data.get(ConfigHandler.DATA.MOUSE_INVERSION, Vector2.ONE)\
		* ConfigHandler.data.get(ConfigHandler.DATA.MOUSE_SENSITIVITY, 0.3)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_VISIBLE
		return
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE: return
	if event is InputEventMouseMotion:
		var mouse : Vector2 = (event as InputEventMouseMotion).relative * _mouse_multiplier
		var newPitch : float = rotation_degrees.x - mouse.y
		var newYaw : float = rotation_degrees.y - mouse.x
		rotation = Vector3(deg_to_rad(minf(absf(newPitch), 89) * signf(newPitch)), deg_to_rad(newYaw), 0)
		return
	
	if event is InputEventMouseButton:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP:
			_move_speed = minf(100.0, _move_speed + 1.0)
			return
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move_speed = maxf(1.0, _move_speed - 1.0)
			return
		return

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE: return
	var input_dir : Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	var vertical : float = float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
	var movement_dir : Vector3 = Vector3(input_dir.x, vertical, input_dir.y).rotated(Vector3.UP, rotation.y).normalized()
	global_position += movement_dir * delta * _move_speed
