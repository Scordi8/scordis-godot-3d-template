class_name InputButton extends Button

signal input_await_started
signal input_await_stopped
signal value_changed(new_value:String)
var _is_awaiting_input : bool = false
var _input_await_callable : Callable

func _ready() -> void:
	set_process_input(false)
	set_process_internal(true)

func _pressed() -> void:
	_get_new_binding()


func _get_new_binding() -> void:
	if _is_awaiting_input: return
	var original_key : String = text
	
	_input_await_callable = func(key:String, discard:bool=false)->void:
		if discard:
			text = original_key
			_is_awaiting_input = false
			return
		text = key
		value_changed.emit(key)
		_is_awaiting_input = false
		input_await_stopped.emit()
		
	_is_awaiting_input = true
	input_await_started.emit()
	set_process_input(true)
	
	text = "..."

func _input(event: InputEvent) -> void:
	if not _is_awaiting_input:return
	if not event.is_pressed(): return
	var return_key : int = -1
	if event.is_action_pressed(&"ui_cancel"): _input_await_callable.call("", true)
	if event is InputEventKey: return_key = (event as InputEventKey).keycode
	if event is InputEventMouseButton: return_key = (event as InputEventMouseButton).button_index
	if return_key == -1: _input_await_callable.call("", true)
	var key : String = ConfigHandler.mouse_binds[maxi(0, return_key)] if return_key < 10 else OS.get_keycode_string(return_key)
	_input_await_callable.call(key.to_upper())
