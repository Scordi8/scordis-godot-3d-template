extends Control

@onready var settings_container : VBoxContainer = $"HBoxContainer/settings container" as VBoxContainer
@onready var tab_container: VBoxContainer = $"HBoxContainer/tab container" as VBoxContainer

signal button_back_pressed
var label_back : RichTextLabel

signal discard_changes
var label_save : RichTextLabel
var label_apply : RichTextLabel
var label_discard : RichTextLabel
var tabs : Array[Control] = []

var changed : Dictionary[String, Callable] = {} ## key:address, value: on apply callable
var unsaved : Dictionary[String, Variant] ={} ## key:address, value: value to save

var is_awaiting_input : bool = false
var input_await_callable : Callable
var interactables : Array[Control] = [] # list of buttons and sliders to disable when awaiting input

var stylebox : StyleBox

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	stylebox = StyleBoxEmpty.new()
	
	label_back = add_button("<- Back", tab_container, button_back_pressed.emit)
	
	ConfigHandler.open_config()
	for tab : String in ConfigHandler.config_layout:
		
		var tab_list : VBoxContainer = VBoxContainer.new()
		tabs.append(tab_list)
		add_button(tab.capitalize(), tab_container, button_pressed.bind(tab_list))
		settings_container.add_child.call_deferred(tab_list)
		for data : Dictionary in ConfigHandler.config_layout[tab]:
			var d : Dictionary[String, Variant]; d.assign(data)
			var ctype : String = d["type"]
			var constructor : Callable = ConfigHandler.constructors.get(ctype, get_default_constructer(ctype))
			
			constructor.call(tab_list, d)
			#print(data)
	ConfigHandler.close_config()
	if not tabs.is_empty(): button_pressed.call_deferred(tabs[0])
	
	label_save = add_button("Save", tab_container, save_changes)
	label_apply = add_button("Apply", tab_container, apply_changes)
	label_discard = add_button("Discard", tab_container, discard_changes.emit)
	update_button_visibility.call_deferred()

func add_button(text:String, root:Control, callable:Callable) -> RichTextLabel:
	var l : RichTextLabel = RichTextLabel.new()
	root.add_child.call_deferred(l)
	l.text = text
	l.bbcode_enabled = true
	l.fit_content = true
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	
	var b : Button = Button.new()
	l.add_child.call_deferred(b)
	b.flat = true
	b.add_theme_stylebox_override(&"focus", stylebox)
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	b.mouse_entered.connect(b.grab_focus, CONNECT_DEFERRED)
	b.focus_entered.connect(button_on_focus_entered.bind(l, l.text))
	b.focus_exited.connect(button_on_focus_exited.bind(l, l.text))
	b.pressed.connect(callable)
	return l

func button_on_focus_entered(l:RichTextLabel, default_text:String) -> void: l.text = "[u]" + default_text + "[/u]"
func button_on_focus_exited(l:RichTextLabel, default_text:String) -> void: l.text = default_text
func button_pressed(target_tab:Control) -> void:
	for c : Control in tabs: c.visible = c==target_tab

#region action handling stuff
func get_control_value(c:Control) -> Variant:
	if c is Button:
		if c is ColorPickerButton: return (c as ColorPickerButton).color
		if c is OptionButton: return (c as OptionButton).selected
		if c is InputButton: return (c as InputButton).text
		return (c as Button).pressed
	if c is Range: return (c as Range).value
	if c is LineEdit: return (c as LineEdit).text
	if c is TextEdit: return (c as TextEdit).text
	if c is TabContainer: return (c as TabContainer).current_tab
	return null

func set_control_value(c:Control, v:Variant) -> void:
	if c is Button:
		if c is ColorPickerButton: c.color = v; return
		if c is OptionButton: c.selected = v;return
		if c is InputButton: c.text = v;return
		c.pressed = v; return
	if c is Range: c.value = v; return
	if c is LineEdit: c.text = v; return
	if c is TextEdit: c.text = v; return
	if c is TabContainer: c.current_tab = v; return

func set_control_disabled(c:Control, d:bool) -> void:
	if c is Button: (c as Button).disabled = d; return
	if c is Slider: (c as Slider).editable = not d; return
	if c is LineEdit: (c as LineEdit).editable = not d; return
	if c is TextEdit: (c as TextEdit).editable = not d; return


func apply(address:String, node:Control, apply_callable:Callable) -> void:
	var v : Variant = get_control_value(node)
	apply_callable.call(address, v)
	unsaved.set(address, v)

func on_value_changed(value:Variant, address:String, reset_button:TextureButton, default:Variant, initial_value:Variant, apply_callable:Callable) -> void:
	var value_changed : bool = value != initial_value
	reset_button.visible = value != default
	
	if value_changed: changed[address] = apply_callable
	else: changed.erase(address)
	update_button_visibility()

func set_input_obstruction(obstructing:bool, exception:Control=null) -> void:
	for c : Control in interactables:
		if c == exception: set_control_disabled(c, not obstructing);continue
		set_control_disabled(c, obstructing)

func save_changes() -> void:
	ConfigHandler.open_config()
	for address : String in unsaved:
		ConfigHandler.write_config_address(address, unsaved[address])
	ConfigHandler.close_config(true)
	unsaved.clear()
	update_button_visibility()

func apply_changes() -> void:
	for address : String in changed: changed[address].call()
	changed.clear()
	update_button_visibility()

func update_button_visibility() -> void:
	var has_queued_changes : bool = not changed.is_empty()
	var has_unsaved_changes : bool = not unsaved.is_empty()
	
	label_save.visible = (not has_queued_changes) and has_unsaved_changes
	label_discard.visible = has_queued_changes
	label_apply.visible = has_queued_changes
	var button_back : Button = (label_back.get_child(0) as Button)
	button_back.disabled = (has_unsaved_changes or has_queued_changes)
	button_back.tooltip_text = "Apply, Save, or Discard\nexisting changes to leave" if (has_unsaved_changes or has_queued_changes) else ""

#endregion action handling stuff

#region constructors
func get_default_constructer(type:String) -> Callable:
	match type:
		"TYPE_OPTION": return constructor_type_option
		"TYPE_SLIDER": return constructor_type_slider
		"TYPE_INPUT": return constructor_type_input_button
	
	return constructor_missing

func constructor_missing(_a:Variant=null,_b:Variant=null,_c:Variant=null,_d:Variant=null,_e:Variant=null,_f:Variant=null) -> void:
	return

func add_label(to:Control, text:String) -> void:
	var label : Label = Label.new()
	to.add_child.call_deferred(label)
	label.text = text
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN|Control.SIZE_EXPAND

func add_reset_button(to:Control, target_node:Control, default_value:Variant) -> TextureButton:
	var arc : AspectRatioContainer = AspectRatioContainer.new()
	to.add_child.call_deferred(arc)
	arc.stretch_mode = AspectRatioContainer.STRETCH_HEIGHT_CONTROLS_WIDTH
	arc.alignment_horizontal = AspectRatioContainer.ALIGNMENT_BEGIN
	
	var reset_button : TextureButton = TextureButton.new()
	arc.add_child.call_deferred(reset_button)
	reset_button.ignore_texture_size = true
	reset_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
	reset_button.texture_normal = preload("res://content/assets/misc/icon_anticlockwise_rotation.svg")
	reset_button.pressed.connect(set_control_value.bind(target_node, default_value))
	return reset_button

func constructor_type_option(tab_node:Control, data:Dictionary[String, Variant]) -> void:
	var address : String = data["address"]
	var config_callable : Callable = ConfigHandler.config_callables[ConfigHandler.config_callable_ref[address]]
	var options : Array[String]; options.assign(data["type_hint"])
	var default : int = ConfigHandler.get_default(address)
	var selected : int = ConfigHandler.read_config_address(address)
	var opt_root : HBoxContainer = HBoxContainer.new()
	
	add_label(opt_root, data["title"])
	
	var opt_container : HBoxContainer = HBoxContainer.new()
	opt_root.add_child.call_deferred(opt_container)
	opt_container.size_flags_horizontal = Control.SIZE_SHRINK_END|Control.SIZE_EXPAND
	
	var opt : OptionButton = OptionButton.new()
	opt_container.add_child.call_deferred(opt)
	for o : String in options: opt.add_item(o)
	opt.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	opt.selected = selected
	discard_changes.connect(func()->void:set_control_value(opt, selected))
	interactables.append(opt)
	
	var reset_button : TextureButton = add_reset_button(opt_container, opt, default)
	
	var callable : Callable = apply.bind(address, opt, config_callable)
	opt.item_selected.connect(on_value_changed.bind(address, reset_button, default, selected, callable))
	reset_button.pressed.connect(on_value_changed.bind(default, address, reset_button, default, selected, callable))
	discard_changes.connect(func()->void:on_value_changed(selected, address, reset_button, default, selected, callable))
	reset_button.visible = opt.selected != default
	
	tab_node.add_child.call_deferred(opt_root)

func set_slider_numbers_display(f:float, l:Label) -> void: l.text = str(f)

func constructor_type_slider(tab_node:Control, data:Dictionary[String, Variant]) -> void:
	var address : String = data["address"]
	var config_callable : Callable = ConfigHandler.config_callables[ConfigHandler.config_callable_ref[address]]
	var options : Array[float]; options.assign(data["type_hint"])
	var default : float = ConfigHandler.get_default(address)
	var current : float = ConfigHandler.read_config_address(address)
	var opt_root : HBoxContainer = HBoxContainer.new()
	var title_container : HBoxContainer = HBoxContainer.new()
	title_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	add_label(title_container, data["title"])
	var numbers_label : Label = Label.new()
	title_container.add_child.call_deferred(numbers_label)
	numbers_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	numbers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	opt_root.add_child.call_deferred(title_container)
	
	var opt_container : HBoxContainer = HBoxContainer.new()
	opt_root.add_child.call_deferred(opt_container)
	opt_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var sli : HSlider = HSlider.new()
	assert(options.size() >= 2, "TYPE_SLIDER type hints must provide a start and end value")
	sli.min_value = options[0]
	sli.max_value = options[1]
	if options.size() >= 3: sli.step = options[2]
	sli.scrollable = false
	sli.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sli.size_flags_vertical = Control.SIZE_FILL
	var show_numbers : bool = is_equal_approx(options[3], 1.0) if (options.size() >= 4) else false
	sli.value = current
	if show_numbers:
		numbers_label.custom_minimum_size.x = 50
		sli.value_changed.connect(set_slider_numbers_display.bind(numbers_label))
		set_slider_numbers_display(current, numbers_label)
	interactables.append(sli)
	discard_changes.connect(func()->void:set_control_value(sli, current))
	
	
	opt_container.add_child.call_deferred(sli)
	
	var reset_button : TextureButton = add_reset_button(opt_container, sli, default)
	var callable : Callable = apply.bind(address, sli, config_callable)
	sli.value_changed.connect(on_value_changed.bind(address, reset_button, default, current, callable))
	reset_button.pressed.connect(on_value_changed.bind(default, address, reset_button, default, current, callable))
	discard_changes.connect(func()->void:on_value_changed(current, address, reset_button, default, current, callable))
	reset_button.visible = sli.value != default
	
	tab_node.add_child.call_deferred(opt_root)

func constructor_type_input_button(tab_node:Control, data:Dictionary[String, Variant]) -> void:
	var address : String = data["address"]
	var config_callable : Callable = ConfigHandler.config_callables[ConfigHandler.config_callable_ref[address]]
	var default : String = ConfigHandler.get_default(address).to_upper()
	var current : String = ConfigHandler.read_config_address(address).to_upper()
	var opt_root : HBoxContainer = HBoxContainer.new()
	
	add_label(opt_root, data["title"])
	
	var opt_container : HBoxContainer = HBoxContainer.new()
	opt_root.add_child.call_deferred(opt_container)
	opt_container.size_flags_horizontal = Control.SIZE_SHRINK_END|Control.SIZE_EXPAND
	
	var ib : InputButton = InputButton.new()
	opt_container.add_child.call_deferred(ib)
	ib.text = current
	ib.custom_minimum_size.x = 75
	ib.input_await_started.connect(set_input_obstruction.bind(true, ib))
	ib.input_await_stopped.connect(set_input_obstruction.bind(false))
	interactables.append(ib)
	discard_changes.connect(func()->void:set_control_value(ib, current))
	
	var reset_button : TextureButton = add_reset_button(opt_container, ib, default)
	var callable : Callable = apply.bind(address, ib, config_callable)
	ib.value_changed.connect(on_value_changed.bind(address, reset_button, default, current, callable))
	reset_button.pressed.connect(on_value_changed.bind(default, address, reset_button, default, current, callable))
	discard_changes.connect(func()->void:on_value_changed(current, address, reset_button, default, current, callable))
	reset_button.visible = ib.text != default
	
	tab_node.add_child.call_deferred(opt_root)

#endregion constructors
