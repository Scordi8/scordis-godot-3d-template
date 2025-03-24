extends Node

var current_config_version : int = ProjectSettings.get_setting("application/config/config_compatibility_version", 0)
const user_config_reference_path : String = "res://content/assets/misc/user_config_ref.json"
const user_config_path : String = "user://userconfig.cfg"
const user_logs_folder : String = "user://logs"
var user_config : ConfigFile
var is_config_open : bool = false

signal data_changed
enum DATA {MOUSE_SENSITIVITY, MOUSE_INVERSION, FOV}
var _data_change_queued : bool = false
var data : Dictionary[int, Variant] = {}

signal default_config_parsed
var constructors : Dictionary[String, Callable] = {} ## key:option type, value: option type constructor
var config_layout : Dictionary[String, Array] = {} ## key:tab name, value: dictionary of data
var config_reset : Dictionary[String, Variant] = {} ## key:address, value:default Variant from the reference
var config_callable_ref : Dictionary[String, String] = {} ## key:address, value: callable name
var config_callables : Dictionary[String, Callable] = {
	"":apply_missing_setting,
	"graphics":apply_graphics_setting,
	"audio":apply_audio_setting,
	"input":apply_input_setting
	} ## key:callable name, value: callable to apply settings
var config_input_actions : Dictionary[String, StringName] = {} ## key:address, value: input action name
signal config_validified

var vp : Viewport
var viewport_scale : Vector2 = Vector2.ONE
var base_sensitivity : float = 0.3 ## There's a bug related to mouse movement when changing scalevar mouseSensitivity : float
const inversion_map : PackedVector2Array = [Vector2(1.0, 1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(-1.0, -1.0)]
const mouse_binds : PackedStringArray = ["N/A","LMB","RMB","MMB","MWU","MWD","MWL","MWR","MBX1","MBX2"]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	parse_default_config()
	validify_user_config()
	load_config()
	get_tree().auto_accept_quit = false
	set_game_exit_status(FAILED)

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST: return
	set_game_exit_status(OK)
	get_tree().quit()

## Adds a setting to [member ConfigHandler.config_layout] and [member ConfigHandler.config_reset].
func add_setting(setting_data:Dictionary) -> void:
	var tab_array : Array = config_layout.get_or_add(setting_data["tab"], []) as Array
	tab_array.push_back(setting_data)
	config_reset[setting_data["address"]] = setting_data["default"]
	config_callable_ref[setting_data["address"]] = setting_data.get("call", "")
	
	if setting_data.get("type") == "TYPE_INPUT":
		config_input_actions[setting_data["address"]] = StringName(setting_data["type_hint"])
		

## Open and read the default user config and add them to [member ConfigHandler.config_layout] and [member ConfigHandler.config_reset]
func parse_default_config() -> void:
	var fcfg : FileAccess = FileAccess.open(user_config_reference_path, FileAccess.READ)
	var jcfg : JSON = JSON.new()
	jcfg.parse(fcfg.get_as_text())
	fcfg = null
	var default_settings : Array[Dictionary] = []
	default_settings.assign((jcfg.data as Dictionary).get("settings", []))
	jcfg = null
	for setting : Dictionary in default_settings: add_setting(setting)
	
	default_config_parsed.emit()

func hasnt(v:Variant, a:Array) -> bool: return not a.has(v) ## it's like filter(array.has) but used like hasnt.bind(array)
func get_default(address:String) -> Variant: return config_reset.get(address)
## Loads and scans the user's local config and compares it to the reference to ensure all fields exist.
## Does not ensure the values are correct, only that they exist.
## If you need to validify mod settings in more depth, you can connect your own validification function to signal [signal ConfigHandler.config_validified]
func validify_user_config() -> void:
	var expected : Array[String]; expected.assign(config_reset.keys()) # expected addresses
	var cfg : ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(user_config_path): cfg.load(user_config_path)
	if cfg.get_value("core", "exit_code", 0): exit_code_failed()
	var existing : Array[String] = [] # existing addresses
	for section : String in cfg.get_sections():
		for key : String in cfg.get_section_keys(section):
			existing.append("{section}/{key}".format({"section":section,"key":key}))
	
	var missing : Array[String]; missing.assign(expected.filter(hasnt.bind(existing)))
	var extras : Array[String]; extras.assign(existing.filter(hasnt.bind(expected)))
	var changes : Dictionary[String, Variant];changes.assign(Utils.dict_from_arrays(missing, missing.map(get_default)).merged(Utils.dict_from_arrays(extras, [null])))
	
	for address : String in changes:
		var sect_key : PackedStringArray = address.split("/", false, 1)
		cfg.set_value(sect_key[0], sect_key[1], changes[address])
	
	cfg.set_value("core", "version", current_config_version) # no breaking changes exist in this game yet
	cfg.save(user_config_path)
	config_validified.emit()

func exit_code_failed() -> void:
	if OS.is_debug_build(): return # editor is bound to crash every now and then, and we only need this stuff for release builds
	Utils.warning("Exit code was 1 on launch. Game may have closed unexpectedly")
	var directory : DirAccess = DirAccess.open(user_logs_folder)
	if DirAccess.get_open_error() != OK:
		Utils.warning("Couldn't find or open godot logs folder")
		return
	
	# We've found the logs, get the most recently modified log
	# Godot only keeps the 5 most recent logs, no need to prune
	var dir_content : Array[String] = [] 
	for path : String in directory.get_files(): dir_content.append(user_logs_folder.path_join(path))
	if dir_content.is_empty(): return ## No files to send, abort
	dir_content.sort_custom(Utils.sort_by_file_age)
	
	var _most_recent_log : String = dir_content[0]
	# usually we'd also do some sort of error handling, or crash log collection if possible,
	# but that's outside of the template's scope.

func set_game_exit_status(status:Error) -> void:
	if is_config_open:
		user_config.set_value("core", "exit_code", status)
		save_config()
		return
	var cfg : ConfigFile = ConfigFile.new()
	cfg.load(user_config_path)
	cfg.set_value("core", "exit_code", status)
	cfg.save(user_config_path)
	cfg = null

func open_config() -> void:
	assert(not is_config_open, "ConfigHandler: open_config - Config is already open. - Stack:\n" + Utils.stringify_stack(get_stack(), 4))
	user_config = ConfigFile.new()
	user_config.load(user_config_path)
	is_config_open = true

func save_config() -> void:
	assert(is_config_open, "ConfigHander: save_config - Config is closed. - Stack:\n" + Utils.stringify_stack(get_stack(), 4))
	user_config.save(user_config_path)

func close_config(save_changes:bool=true) -> void:
	assert(is_config_open, "ConfigHander: close_config - Config is already closed. - Stack:\n" + Utils.stringify_stack(get_stack(), 4))
	if save_changes: save_config()
	user_config = null
	is_config_open = false

func write_config_address(address:String, value:Variant) -> void:
	var sk : PackedStringArray = address.split("/", false, 1)
	write_config(sk[0], sk[1], value)

func write_config(section:String, key:String, value:Variant) -> void:
	assert(is_config_open, "ConfigHander: write_config - Cannot write to closed config. - Stack:\n" + Utils.stringify_stack(get_stack(), 4))
	user_config.set_value(section, key, value)

func read_config_address(address:String) -> Variant:
	var sk : PackedStringArray = address.split("/", false, 1)
	return read_config(sk[0], sk[1])

func read_config(section:String, key:String) -> Variant:
	assert(is_config_open, "ConfigHander: read_config - Cannot read from closed config. - Stack:\n" + Utils.stringify_stack(get_stack(), 4))
	return user_config.get_value(section, key)

func load_config() -> void:
	
	if is_config_open:
		push_warning("ConfigHander: load_config - Config is loading while open, unsaved changes will not apply")
	var cfg : ConfigFile = ConfigFile.new()
	cfg.load(user_config_path)
	
	for section in cfg.get_sections():
		if section == "core": continue
		
		for key : String in cfg.get_section_keys(section):
			var address : String = section + "/" + key
			var value : Variant = cfg.get_value(section, key)
			(config_callables.get(config_callable_ref[address], apply_missing_setting) as Callable)\
			.call_deferred(address, value)


func apply_missing_setting(a:Variant=null,b:Variant=null,c:Variant=null,d:Variant=null,e:Variant=null,f:Variant=null,g:Variant=null) -> void:
	var r : String = "No matching callable found to apply setting: "
	for arg : Variant in [a,b,c,d,e,f,g]:
		if arg==null:continue
		r += str(arg) + ", "
	push_warning(r)
	return

func apply_audio_setting(key:String, value:float) -> void:
	var key2 : String = key.split("/", false, 1)[1].capitalize()
	for busID : int in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(busID) == key2:
			AudioServer.set_bus_volume_db(busID, linear_to_db(clampf(value*0.01, 0, 1)))
			return
	push_warning("ConfigHandler - apply_audio_bus_settings: no bus with the name \"%s\" exists" % key2)


func apply_graphics_setting(key:String, value:int) -> void:
	var vprid : RID
	if not is_instance_valid(vp): vp = get_viewport()
	vprid = vp.get_viewport_rid()
	var env : Environment = vp.world_3d.environment if vp else null
	match key:
		"graphics/display":
			match value:
				0: # windowed mode
					var mode : DisplayServer.WindowMode = DisplayServer.window_get_mode()
					if (mode == DisplayServer.WINDOW_MODE_FULLSCREEN) or (mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN):
						DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
						DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
						DisplayServer.window_set_size(DisplayServer.screen_get_size() / Vector2i(2, 2))
				1: # Borderless mode
					DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				2: # fullscreen mode
					DisplayServer.window_set_size(DisplayServer.screen_get_size())
					DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
				_:
					pass
			viewport_scale = Vector2(DisplayServer.window_get_size()) / Vector2(3840.0, 2160.0)
			data[DATA.MOUSE_SENSITIVITY] = Vector2.ONE * base_sensitivity * viewport_scale
			data_has_changed()
			return
		"graphics/vsync":
			DisplayServer.window_set_vsync_mode(value)
			return
		
		"graphics/gi": # goes from 0 to 4 but 0 is off so quality is 1 to 4
			if env:
				env.sdfgi_enabled = value > 0
				if value > 0:
					# GI won't turn on if the 3d rendering and tree is paused. (at least in 4.3)
					# the solution is literally to turn it off and on again
					get_tree().create_timer(0.1, false).timeout.connect(env.set_deferred.bind(&"sdfgi_enabled", false))
					get_tree().create_timer(0.2, false).timeout.connect(env.set_deferred.bind(&"sdfgi_enabled", true))
			if value == 0: return # rest doesn't matter if it's disabled
			RenderingServer.gi_set_use_half_resolution(value <= 2)
			RenderingServer.environment_set_sdfgi_frames_to_update_light(5 - value) # 1=16, 2=8, 3=4, 4=2
			RenderingServer.environment_set_sdfgi_ray_count(value - 1) # 1=4
			RenderingServer.environment_set_sdfgi_frames_to_converge(value)
			return
		"graphics/aa":
			if vp:
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if value == 0 else Viewport.SCREEN_SPACE_AA_FXAA
				vp.msaa_3d = clampi(value-1, 0, 3) as Viewport.MSAA
				vp.use_taa = value > 4
			return
		
		"graphics/shadow":
			const SHADOW_ATLAS_SIZE : Array[int] = [0, 1024, 2048, 4096]
			const SHADOW_FILTER_QUALITY : Array[RenderingServer.ShadowQuality] = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_HARD,
				RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH]
			RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS_SIZE[value], value > 2)
			if vprid:RenderingServer.viewport_set_positional_shadow_atlas_size(vprid, SHADOW_ATLAS_SIZE[value], value > 2)
			var shadowQuality : RenderingServer.ShadowQuality = SHADOW_FILTER_QUALITY[value]
			RenderingServer.directional_soft_shadow_filter_set_quality(shadowQuality)
			RenderingServer.positional_soft_shadow_filter_set_quality(shadowQuality)
			return
		"graphics/scaling":
			if vprid:
				const VIEWPORT_SCALING_SIZE : Array[float] = [0.5, 0.5, 0.59, 0.67, 0.77, 1.0]
				var mode : RenderingServer.ViewportScaling3DMode =\
				RenderingServer.VIEWPORT_SCALING_3D_MODE_BILINEAR if (value == 0 or value == 5)\
				else RenderingServer.VIEWPORT_SCALING_3D_MODE_FSR2
				RenderingServer.viewport_set_scaling_3d_mode(vprid, mode)
				RenderingServer.viewport_set_scaling_3d_scale(vprid, VIEWPORT_SCALING_SIZE[value])
			return
		"graphics/ssr":
			if env: env.ssr_enabled = value>0
			RenderingServer.environment_set_ssr_roughness_quality(value)
			return
		"graphics/ssil":
			if env: env.ssil_enabled = value>0
			RenderingServer.environment_set_ssil_quality(
				clampi(value-1, 0, 4),
				value==4,
				ProjectSettings.get_setting("rendering/environment/ssil/adaptive_target"),
				ProjectSettings.get_setting("rendering/environment/ssil/blur_passes"),
				ProjectSettings.get_setting("rendering/environment/ssil/fadeout_from"),
				ProjectSettings.get_setting("rendering/environment/ssil/fadeout_to")
				)
			return
		"graphics/ssao":
			if env: env.ssao_enabled = value>0
			RenderingServer.environment_set_ssil_quality(
				clampi(value-1, 0, 4),
				value==4,
				ProjectSettings.get_setting("rendering/environment/ssao/adaptive_target"),
				ProjectSettings.get_setting("rendering/environment/ssao/blur_passes"),
				ProjectSettings.get_setting("rendering/environment/ssao/fadeout_from"),
				ProjectSettings.get_setting("rendering/environment/ssao/fadeout_to")
				)
			return
		"graphics/fov":
			data[DATA.FOV] = value
			data_has_changed()
			return
		_:
			Utils.warning("{key} has no matching entry".format({"key":key}))
			return

func apply_input_setting(address:String, value:Variant) -> void:
	match address:
		"input/sensitivity":
			base_sensitivity = value
			data[DATA.MOUSE_SENSITIVITY] = Vector2.ONE * base_sensitivity * viewport_scale
			data_has_changed()
			return
		"input/inversion":
			data[DATA.MOUSE_INVERSION] = inversion_map[value]
			data_has_changed()
			return
		"input/primary", "input/secondary", "input/right", "input/left", "input/backward", "input/forward":
			var event : InputEvent
			var action : StringName = config_input_actions[address]
			
			if is_instance_of(value, TYPE_STRING):
				if value in mouse_binds:
					value = mouse_binds.find(value)
				else:
					value = OS.find_keycode_from_string(value)
			
			if value < 10: event = InputEventMouseButton.new(); event.button_index = value
			else: event = InputEventKey.new(); event.keycode = value
			if InputMap.has_action(action): InputMap.erase_action(action)
			InputMap.add_action(action)
			InputMap.action_add_event(action, event)
			return

func data_has_changed() -> void:
	if _data_change_queued: return
	_data_change_queued = true
	data_changed.emit.call_deferred()
