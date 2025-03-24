## Global is a general script used to contain misc properties and methods that need to be access from anywhere
extends Node

var player : Node ## The Player node is intended to hold a reference to whatever the user is currently controlling
var spawn_devcam : bool = ProjectSettings.get_setting("application/run/spawn_devcam_without_player") ## If true, will spawn in instance of [DevCamera3D] if the active scene root is a [Node3D] and [member Global.player] is invalid

var avg_fps: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fps_timer_init()
	
	if spawn_devcam and (get_tree().current_scene is Node3D) and (not is_instance_valid(player)):
		player = DevCamera3D.new()
		get_tree().current_scene.add_child.call_deferred(player)

#region fps timer
var _fps_stack: Array[int] = []

func _fps_timer_init() -> void:
	_fps_stack.resize(5)
	_fps_stack.fill(30)
	var fps_timer : Timer = Timer.new()
	fps_timer.timeout.connect(fps_timer.start.bind(1.0))
	fps_timer.timeout.connect(_fps_timer_timeout)
	fps_timer.autostart = true
	fps_timer.wait_time = 1.0
	fps_timer.ignore_time_scale = true
	fps_timer.name = "fps update timer" # so we can identify it in the scenetree at runtime
	add_child.call_deferred(fps_timer)

func _fps_timer_timeout() -> void:
	_fps_stack.remove_at(0)
	_fps_stack.append(int(Performance.get_monitor(Performance.TIME_FPS)))
	avg_fps = Utils.average(_fps_stack)
#endregion fps timer

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	_process_queued_callbacks()

#region callable queue
# The callable queue is designed to spread a collection of events over many frames to prevent doing too much at once.[br]
# for example, if you needed to do a thousand mid complexity behaviours, you'd queue them all here to be done over the next few seconds.
var _callable_queue : Array[Callable] = []
var _cq_total : int = 0 # The total about of callables queued since the game started
var _cq_failed : int = 0 # The amount of callables that were invalid when called
var _cq_called : int = 0 # The amount of callables valid and called successfully
func _process_queued_callbacks() -> void:
	if _callable_queue.is_empty(): return
	var c : float = _callable_queue.size() * .5
	var iter_c : int = 1 + floori(c/float(avg_fps))
	
	while iter_c > 0:
		iter_c -= 1
		if _callable_queue.is_empty(): return
		var qc : Callable = _callable_queue.pop_front()
		if not qc.is_valid():
			_cq_failed += 1
			continue
		qc.call_deferred()
		_cq_called += 1

## Queue a [Callable] to be called over the next few seconds
func queue_callable(c:Callable) -> void:
	_cq_total += 1
	_callable_queue.append(c)
#endregion callable queue
