extends Control

@export var main_button_container : VBoxContainer

@export var control_main : Control
@export var control_play : Control
@export var control_settings : Control
@onready var menu_controls : Array[Control] = [control_main,control_play,control_settings]

func _ready() -> void:
	set_menu_visibility(control_main)
	get_main_buttons()
	
	if control_settings.has_signal(&"button_back_pressed"):
		control_settings.connect(&"button_back_pressed", set_menu_visibility.bind(control_main))

func setup_label_button(l:RichTextLabel, pressed_callable:Callable, start_with_focus:bool=false) -> void:
	var b : Button = (l.get_child(0) as Button)
	
	b.mouse_entered.connect(b.grab_focus, CONNECT_DEFERRED)
	b.focus_entered.connect(button_on_focus_entered.bind(l, l.text))
	b.focus_exited.connect(button_on_focus_exited.bind(l, l.text))
	b.pressed.connect(pressed_callable)
	
	if start_with_focus: b.grab_focus.call_deferred()

func button_on_focus_entered(l:RichTextLabel, default_text:String) -> void:
	l.text = "[u]" + default_text + "[/u]"

func button_on_focus_exited(l:RichTextLabel, default_text:String) -> void:
	l.text = default_text

func get_main_buttons() -> void:
	assert(is_instance_valid(main_button_container))
	
	setup_label_button(main_button_container.get_node("rtl_play") as RichTextLabel, on_button_play_pressed, true)
	setup_label_button(main_button_container.get_node("rtl_settings") as RichTextLabel, on_button_settings_pressed)
	setup_label_button(main_button_container.get_node("rtl_quit") as RichTextLabel, on_button_quit_pressed)

func set_menu_visibility(to:Control) -> void:
	for c : Control in menu_controls: c.visible = c == to

func on_button_play_pressed() -> void:
	# here you'd load a scene or something
	pass

func on_button_settings_pressed() -> void:
	set_menu_visibility(control_settings)


func on_button_quit_pressed() -> void:
	ConfigHandler.notification(NOTIFICATION_WM_CLOSE_REQUEST)
