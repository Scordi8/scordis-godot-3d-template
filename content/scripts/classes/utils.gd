## Utils is a static class intended to hold various functions that will be reused in many places accross the project.
## By centralising the main ones in [Utils], we can reduce the amount of boilerplate code present in the files.
@tool class_name Utils extends Object

const INV_INT_LIMIT_32 : float = 1./4294967296
const WARNING_SEVERITY_COLOUR_INDEX : Array[Color] = [Color.DIM_GRAY, Color.YELLOW, Color.ORANGE, Color.RED]

#region debug utils
## Prints in the output and/or display on-screen a given warning for 5 seconds.[br]
## - [param warning_text] - what will be printed or displayed.[br]
## - [param severity] - the colour of which the warning shows up as. see [constant Utils._WARNING_SEVERITY_COLOUR_INDEX].[br]
## - [param show_onscreen] - whether the warning will display as a debug toast.[br]
## - [param show_in_output] - whether the warning will be printed to the editor output.[br]
## In an exported build, this function won't do anything
static func warning(warning_text:String, severity:int=1, show_onscreen:bool=false, show_in_output:bool=true) -> void:
	if not OS.is_debug_build(): return # we only want this in editor
	var stack : Array[Dictionary];stack.assign(get_stack())
	if stack.size()<=1: return # no stack :(
	var fp : String = str(stack[1].get("source", "???")).get_file()
	var col_str : String = WARNING_SEVERITY_COLOUR_INDEX[clampi(severity, 0, 3)].to_html(false)
	
	if show_in_output:
		var text : String = "[color={colour}]USER DEFINED WARNING - {script}:{line} - {function}: {warning}".format({
			"colour":col_str,
			"script":fp,
			"line":stack[1].get("line", "?"),
			"function":stack[1].get("function", "???"),
			"warning":warning_text
		})
		if not text.ends_with("."): text += "."
		text += "[/color]"
		print_rich(text)
	
	if show_onscreen and not Engine.is_editor_hint():
		Debug.add_toast(
			"{script}:{line} - {function}: {warning}".format({
				"script":fp,
				"line":stack[1].get("line", "?"),
				"function":stack[1].get("function", "???"),
				"warning":warning_text
			}),
			"[color={colour}]".format({"colour":col_str}),
			"[/color]"
		)

## Returns the given stack array ([method @GDScript.get_stack]) and returns it as a [String].[br]
## - [param depth_limit] controls how far up the stack the returned string will cover.[br]
## - [param line_prefix] appears at the start of each stack line and is used for formatting.
static func stringify_stack(stack:Array, depth_limit:int=10, line_prefix:String="\t") -> String:
	var res : String = ""
	for stack_index : int in range(mini(stack.size(), depth_limit)):
		var fp : String = str(stack[stack_index].get("source", "???")).get_file()
		res += line_prefix + "{script}:{line} - {function}\n".format({"script":fp, "line":stack[stack_index].get("line", "?"), "function":stack[stack_index].get("function", "???"),})
	return res
#endregion debug utils

#region array utils
## Returns the average [Variant] of [param arr].
static func average(arr:Array) -> Variant:
	var sum : Variant = arr[0]
	for v : Variant in arr.slice(1):
		sum += v
	return sum / arr.size()

## Returns the statistics of [param arr] in a dictionaty with the following [StringName] keys:[br]
## - [b]min[/b]: the lowest [Variant].[br]
## - [b]max[/b]: the highest [Variant].[br]
## - [b]sum[/b]: the sum of all the [Variant]s.[br]
## - [b]mid[/b]: the median [Variant].[br]
## - [b]avg[/b]: the mean/average [Variant].
static func stats(arr:Array) -> Dictionary:
	var v_min : Variant = arr[0]
	var v_max : Variant = arr[0]
	var v_sum : Variant = arr[0]
	var v_mid : Variant = arr[0]
	var v_avg : Variant = arr[0]
	for v : Variant in arr.slice(1):
		v_min = min(v_min, v)
		v_max = max(v_max, v)
		v_sum += v
	
	v_mid = (v_min + v_max) * 0.5
	v_avg = v_sum / arr.size()
	
	return {
		&"min":v_min,
		&"max":v_max,
		&"sum":v_sum,
		&"mid":v_mid,
		&"avg":v_avg
		}

## Checks if all [param a1]'s elements are present in [param a2]
static func array_contains_array(a1:Array, a2:Array) -> bool:
	if a2.size() < a1.size(): return false
	for item : Variant in a1:
		if !a2.has(item): return false
		if a1.count(item) != a2.count(item): return false
	return true

## Return a copy of [param arr] without any content of [param exc]
static func array_exclude_array(arr:Array, exc:Array) -> Array:
	var arr2 : Array = arr.duplicate() # prevent modifing the original array
	var i : int = arr.size()
	var res : Array = []
	while i > 0:
		i-=1
		var v : Variant = arr2.pop_back()
		if exc.has(v): continue
		res.push_back(v)
	res.reverse()
	return res

## Filters editor property array for properties with PROPERTY_USAGE_EDITOR
static func filter_property_list_for_editor_displayed(prop:Dictionary) -> bool: return (prop["usage"] & 4)==4
## Maps editor property array to displayed name
static func map_property_list_to_editor_displayed_string(prop:Dictionary) -> String: return prop["name"]

## Filter array of [Node3D] for those within a given distance squared
static func filter_proximity_squared(a:Node3D, p:Vector3, d:float) -> bool:
	return a.global_position.distance_squared_to(p) < d

static func filter_for_node3d(node:Node) -> bool: return node is Node3D
static func filter_for_visual_instance(n:Node) -> bool: return n is VisualInstance3D

static func sort_nodes_by_distance(a:Node3D, b:Node3D, p:Vector3) -> bool:
	return a.global_position.distance_squared_to(p) < b.global_position.distance_squared_to(p)

static func sort_by_file_age(filepath_a:String, filepath_b:String) -> bool:
	return FileAccess.get_modified_time(filepath_a) < FileAccess.get_modified_time(filepath_b)

## Map an array of [VirtualInstance3D] into their respective global-space [AABB]
static func map_vi_to_aabb(vi:VisualInstance3D) -> AABB: return vi.global_transform * vi.get_aabb()

## Map each [Node3D] to their [Transform3D]. if [param local] is true, the node's local transform is given instead of the node's global transform
static func map_node_3d_to_xform(n:Node3D, local:bool=true) -> Transform3D: return n.transform if local else n.global_transform

#endregion array utils

#region editor utils
## Returns the default editor-exposed properties of the given object's class
static func get_node_default_editor_properties(n:Object) -> Array[String]:
	var arr_dict : Array[Dictionary] = []
	arr_dict.assign(ClassDB.class_get_property_list(n.get_class()).filter(Utils.filter_property_list_for_editor_displayed))
	var arr_string : Array[String] = []
	arr_string.assign(arr_dict.map(Utils.map_property_list_to_editor_displayed_string))
	return arr_string

## Retuns a given enum.keys() array as a string, used for property["hint_string"] when used with PROPERTY_HINT_ENUM
static func enum_keys_to_hint_string(arr:Array) -> String:
	var res : String = ""
	var sarr : Array[String] = []; sarr.assign(arr) # ensure it's a string array
	for a : String in sarr: res += a + ","
	return res.substr(0, res.length()-1)
#endregion editor utils

#region misc utils
static func get_decending_nodes(from:Node) -> Array[Node]:
	var res : Array[Node] = []
	var children : Array[Node] = [from]
	while not children.is_empty():
		var n : Node = children.pop_back()
		res.append(n)
		children.append_array(n.get_children())
	return res

## get the complete [AABB]for the given [param node] and all its descendants
static func get_total_aabb(node:Node) -> AABB:
	var vis : Array[VisualInstance3D]
	vis.assign(Utils.get_decending_nodes(node).filter(Utils.filter_for_visual_instance))
	var aabbs : Array[AABB]; aabbs.assign(vis.map(Utils.map_vi_to_aabb))
	if aabbs.is_empty(): return AABB()
	if aabbs.size() == 1: return aabbs[0]
	
	var start : Vector3 = aabbs[0].position
	var end : Vector3 = aabbs[0].end
	for b : AABB in aabbs:
		start = start.min(b.position)
		end = end.max(b.end)
	return AABB(start, end-start)

static func set_rt_remote_path(rt:RemoteTransform3D, target:Node3D) -> void:
	rt.remote_path = rt.get_path_to(target)

## Similar to using [method Object.set], except designed to be connected to signals that give the value first .
static func set_swapped(value:Variant, node:Node, property:StringName) -> void: node.set(property, value)

## Convert an keys and values array into a dictionary.[br]
## If [param keys] is longer than [param values], the final value is used for any extra keys
static func dict_from_arrays(keys:Array, values:Array) -> Dictionary:
	var res : Dictionary = {}
	var s : int = values.size()-1
	for i : int in range(keys.size()):
		res.set(keys[i], values[clampi(i, 0, s)])
	return res

static func on_meta_clicked(meta:Variant) -> void:
	match typeof(meta):
		TYPE_STRING: OS.shell_open(str(meta)); return
		_:push_warning("Meta not accounted for: " + str(meta)); return
#endregion misc utils

#region transformation utils
## Makes [param subject] look at [param target].[br]
## [param offset_yaw] and [param offset_pitch] are used to account for different orientations
static func look_at_without_roll(subject:Node3D, target:Node3D, offset_yaw:float=0, offset_pitch:float=0) -> void:
	look_at_global_position(subject, target.global_position, offset_yaw, offset_pitch)

## Makes [param subject] look at the global position [param target].[br]
## [param offset_yaw] and [param offset_pitch] are used to account for different orientations
static func look_at_global_position(subject:Node3D, target:Vector3, offset_yaw:float=0, offset_pitch:float=0) -> void:
	var delta : Vector3 = target - subject.global_position
	subject.global_rotation.y = (atan2(delta.x, delta.z) - PI) + offset_yaw
	subject.global_rotation.x = (asin(delta.y/delta.length())) + offset_pitch

## Reset the transform of a given [param node] without changing the global transform of child nodes
static func reset_node3d_transform(node:Node3D) -> void:
	var children : Array[Node3D] = []
	children.assign(node.get_children().filter(filter_for_node3d))
	node.set_deferred(&"global_transform", Transform3D())
	for child : Node3D in children:
		child.set_deferred(&"global_transform", child.global_transform)

## Get the transform of [param node] in [param target_node]'s space.[br]
## [param depth_limit] limits how far up the tree it can search for a common parent
static func get_transform_local_to_node(node:Node3D, target_node:Node3D, depth_limit:int=5) -> Transform3D:
	var tree_upwards : Array[Node3D] = [node]
	var d : int = 0
	while d <= depth_limit:
		d += 1
		var p : Node3D = tree_upwards.back().get_parent_node_3d()
		if not is_instance_valid(p): return Transform3D()
		tree_upwards.append(p)
		if p == target_node: break

	var xforms : Array[Transform3D]
	tree_upwards.reverse()
	xforms.assign(tree_upwards.map(map_node_3d_to_xform))
	tree_upwards.clear()
	
	var res : Transform3D = Transform3D()
	while not xforms.is_empty():
		res = xforms.pop_back() * res
	return res

#endregion transformation utils

#region rng
## Get a positionally random float between 0 and 1.[br]
## [param pos] is the position used for the randomness.[br]
## [param _seed] is a general offset and should be used to mix up randomness between instances.[br]
## [param offset] is a general offset that should be used for when sampling the same position twice while wanting different values.
static func rand_from_position(pos:Vector3, _seed:int=0, offset:int=0) -> float:
	return (rand_from_seed(offset + hash(pos) + _seed)[0] * INV_INT_LIMIT_32)

## Pick a positionally random value from a given array.[br]
## [param pos] is the position used for the randomness.[br]
## [param arr] is the array to pick from.[br]
## [param _seed] is a general offset and should be used to mix up randomness between instances.[br]
## [param offset] is a general offset that should be used for when sampling the same position twice while wanting different values.
static func pick_random(pos:Vector3, arr:Array, _seed:bool=false, offset:int=0) -> Variant:
	var f : float = rand_from_position(pos, _seed, offset)
	var s : int = arr.size()
	return arr[roundi(f*(s-1))]
#endregion rng
