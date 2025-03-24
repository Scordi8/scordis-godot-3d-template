extends Node

var draw : DebugDraw


const _DEBUG_DRAW : Dictionary[int, Viewport.DebugDraw] = {
	KEY_F1:Viewport.DEBUG_DRAW_DISABLED,
	KEY_F2:Viewport.DEBUG_DRAW_UNSHADED,
	KEY_F3:Viewport.DEBUG_DRAW_LIGHTING,
	KEY_F4:Viewport.DEBUG_DRAW_OVERDRAW,
	KEY_F5:Viewport.DEBUG_DRAW_WIREFRAME,
	KEY_F6:Viewport.DEBUG_DRAW_NORMAL_BUFFER,
	KEY_F7:Viewport.DEBUG_DRAW_OCCLUDERS
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ready_tracelines()
	draw = DebugDraw.new(self)
	_ready_toasts()


func _process(delta: float) -> void:
	_process_tracelines()
	_process_toasts(delta)

func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey:
		var keycode : int = (event as InputEventKey).keycode
		if not keycode in _DEBUG_DRAW: return
		var vp : Viewport = get_viewport()
		vp.debug_draw = _DEBUG_DRAW[keycode]
		vp.set_input_as_handled()
		return

#region line rendering
class DebugDraw extends RefCounted:
	var debug_instance : Debug
	const _default_transform : Transform3D = Transform3D()
	
	const _aabb_corners : Array[Vector3] = [
			Vector3i(0, 2, 4),  Vector3i(0, 2, 5), Vector3i(1, 2, 4), Vector3i(1, 2, 5),
			Vector3i(0, 3, 4),  Vector3i(0, 3, 5), Vector3i(1, 3, 4), Vector3i(1, 3, 5)
		]
	const _aabb_lines : Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 3), Vector2i(3, 2), Vector2i(2, 0),
		Vector2i(4, 5), Vector2i(5, 7), Vector2i(7, 6), Vector2i(6, 4),
		Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)]
	
	func _init(d:Debug) -> void: debug_instance = d
	
	func line(from:Vector3, to:Vector3, duration:float=0.0, colour:Color=Color.WHITE) -> void:
		debug_instance.lines.push_back(TraceLine.new(from, to, debug_instance.msec_now + int(duration * 1000), colour))
	
	func aabb(bb:AABB, duration:float=0.0, colour:Color=Color.WHITE, xform:Transform3D=_default_transform) -> void:
		var b : AABB = xform*bb
		
		var xyz : Array[float] = [b.position.x, b.end.x, b.position.y, b.end.y, b.position.z, b.end.z]
		
		for l : Vector2i in _aabb_lines:
			var vi_a : Vector3 = _aabb_corners[l.x]
			var vi_b : Vector3 = _aabb_corners[l.y]
			Vector3(xyz[vi_a.x], xyz[vi_a.y], xyz[vi_a.z])
			Vector3(xyz[vi_b.x], xyz[vi_b.y], xyz[vi_b.z])
			self.line(
				Vector3(xyz[vi_a.x], xyz[vi_a.y], xyz[vi_a.z]),
				Vector3(xyz[vi_b.x], xyz[vi_b.y], xyz[vi_b.z]),
				duration, colour
				)
	
	func axis(origin:Vector3, duration:float=0.0, basis:Basis=_default_transform.basis) -> void:
		self.line(origin, origin+(basis*Vector3.FORWARD), duration, Color.BLUE)
		self.line(origin, origin+(basis*Vector3.UP), duration, Color.GREEN)
		self.line(origin, origin+(basis*Vector3.RIGHT), duration, Color.RED)

class TraceLine extends RefCounted:
	var origin : Vector3
	var target : Vector3
	var expiration : int
	var colour : Color
	
	func _init(from:Vector3, to:Vector3, expir:int, col:Color) -> void:
		origin = from
		target = to
		expiration = expir
		colour = col

var msec_now : int = 0
var lines : Array[TraceLine] = []
var line_mesh : ImmediateMesh
var line_object : MeshInstance3D

func _ready_tracelines() -> void:
	line_mesh = ImmediateMesh.new()
	line_object = MeshInstance3D.new()
	add_child.call_deferred(line_object)
	line_object.mesh = line_mesh
	line_object.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line_object.material_override = preload("res://content/assets/misc/debug_line.material")

func _process_tracelines() -> void:
	msec_now = Time.get_ticks_msec()
	line_mesh.clear_surfaces()
	if lines.is_empty(): return
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var remaining_lines : Array[TraceLine] = []
	while not lines.is_empty():
		var l : TraceLine = lines.pop_back() as TraceLine
		line_mesh.surface_set_color(l.colour)
		line_mesh.surface_add_vertex(l.origin)
		line_mesh.surface_set_color(l.colour)
		line_mesh.surface_add_vertex(l.target)
		if (l.expiration < msec_now): continue
		remaining_lines.push_back(l)
	line_mesh.surface_end()
	lines = remaining_lines
	remaining_lines.clear()


#endregion

#region on-screen text debug
var debug_hud : MarginContainer
var debug_text_container : VBoxContainer

var current_toasts : Dictionary[int, DebugToast] = {}

class DebugToast extends RefCounted:
	var label : RichTextLabel
	var text : String # the content of the toast
	var prefix : String # added to the start of the string. usually used for bbcode
	var suffix : String # added to the end of the string. usually used for bbcode
	var occurances : int = 1 # how many times has this specific message appeared
	var duration : float = 5.0 # how long until it disappears
	
	func _init(_t:String, _p:String, _s:String, _d:float, container:VBoxContainer) -> void:
		text = _t
		prefix = _p
		suffix = _s
		duration = _d
		label = RichTextLabel.new()
		label.fit_content = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child.call_deferred(label)
	
	func _process_toast(delta:float) -> bool:
		var count_suffix : String = "" if occurances == 1 else " x{count}".format({"count":occurances})
		label.text = prefix + text + count_suffix + suffix
		duration -= delta
		if duration <= 0.0:
			label.queue_free()
			return true
		
		return false

func _ready_toasts() -> void:
	debug_hud = MarginContainer.new()
	add_child.call_deferred(debug_hud)
	const overrides : Array[StringName] = [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]
	for o : StringName in overrides: debug_hud.add_theme_constant_override(o, 10)
	debug_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	debug_text_container = VBoxContainer.new()
	debug_hud.add_child.call_deferred(debug_text_container)
	debug_text_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_text_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process_toasts(delta:float) -> void:
	var to_free : Array[int] = []
	for i : int in current_toasts:
		var should_del : bool = current_toasts[i]._process_toast(delta)
		if not should_del: continue
		to_free.push_back(i)
	while not to_free.is_empty():
		current_toasts.erase(to_free.pop_back())

func add_toast(text:String, prefix:String="", suffix:String="", duration:float=5.0) -> void:
	var text_hash : int = text.hash()
	if current_toasts.has(text_hash):
		current_toasts[text_hash].occurances += 1
		current_toasts[text_hash].duration = maxf(current_toasts[text_hash].duration, duration)
		return
	current_toasts[text_hash] = DebugToast.new(text, prefix, suffix, duration, debug_text_container)
#endregion
