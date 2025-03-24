## API of sorts for [method ResourceLoader.load_threaded_request].
extends Node

var _loaders : Array[LoadRequest] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Default callable for [method Loader.request_load]'s [param process_callable]. Does nothing.
func on_progress(_progress:float) -> void:return
## Default callable for [method Loader.request_load]'s [param failed_callable]. Prints a warning to the output via [method Utils.warning].
func on_failed(resource_path: String, err:ResourceLoader.ThreadLoadStatus) -> void:
	var msg : String = "Failed to load resource {resource_path}, {reason}".format({
		"resource_path":resource_path,
		"reason":
			"resource is invalid" if (err == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)\
			else "an error occurred during loading and it failed."
	})
	Utils.warning(msg)

func _filter_by_path(l:LoadRequest, p:String) -> bool: return l.path == p

class LoadRequest extends Object: # just a data container. i'd use structs 😔 but no structs
	var path : String
	var on_success : Callable
	var on_progress : Callable
	var on_fail : Callable
	var force_load_next_poll : bool = false
	var timeout : float = 20.0
	
	func _init(_path : String, _on_success : Callable, _on_progress : Callable, _on_fail : Callable, time_until_force:float=20.0) -> void:
		path = _path
		on_success = _on_success
		on_progress = _on_progress
		on_fail = _on_fail
		timeout = time_until_force

## Request the threaded loading of a resource.[br]
## - [param resource_path] is the filepath or uid  to load.[br]
## - [param result_callable] will be called on success, with the loaded resource as the only argument.[br]
## - [param load_time_limit] limits how long the resource may take to load before forcing the resource to load.[br]
## - [param sub_threads] determines if multiple threads will be used to load the resource, which make loading faster, but may affect the main thread.[br]
## - [param process_callable] if provided, will be called each frame with a float between 0.0 an 1.0 that represents to loaded progress.[br]
## - [param failed_callable] if provided, will be called if the resource fails to load.
func request_load(resource_path:String,
		result_callable:Callable,
		load_time_limit:float=20.0,
		sub_threads:bool=false,
		progress_callable:Callable=on_progress,
		failed_callable:Callable=on_failed
		) -> void:
	
	if not ResourceLoader.exists(resource_path):
		failed_callable.call_deferred(resource_path, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
		return
	if ResourceLoader.has_cached(resource_path):
		result_callable.call_deferred(load(resource_path))
		return
	var path_matching_loaders : Array[LoadRequest] = []
	path_matching_loaders.assign(_loaders.filter(_filter_by_path.bind(resource_path)))
	if not path_matching_loaders.is_empty():
		var existing_loader_index : int = _loaders.find(path_matching_loaders.front())
		_loaders[existing_loader_index].force_load_next_poll = true
		return
	
	ResourceLoader.load_threaded_request(resource_path, "", sub_threads)
	
	_loaders.append(
		LoadRequest.new(resource_path, result_callable, progress_callable, failed_callable, load_time_limit)
	)
	

func _process(delta: float) -> void:
	var to_free : Array[LoadRequest] = []
	for l : LoadRequest in _loaders:
		var res : Array = [] # this breaks godot design pattern 😔
		var status : ResourceLoader.ThreadLoadStatus =\
			ResourceLoader.load_threaded_get_status(l.path, res)
		match status:
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				l.on_fail.call_deferred(l.path, status)
				to_free.append(l)
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				l.on_progress.call_deferred(res[0])
				if l.force_load_next_poll:
					l.on_success.call_deferred(ResourceLoader.load_threaded_get(l.path))
					to_free.append(l)
				else:
					l.timeout -= delta
					if l.timeout <= 0.0:
						l.force_load_next_poll = true
			ResourceLoader.THREAD_LOAD_LOADED:
				l.on_success.call_deferred(
					ResourceLoader.load_threaded_get(l.path)
				)
				to_free.append(l)
	
	while not to_free.is_empty():
		var l : LoadRequest = to_free.pop_back()
		_loaders.erase(l)
		l.free()
	to_free.clear()
