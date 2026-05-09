extends Control

const NORMAL_NOTE_MODE := "normal"
const MOVING_NOTE_MODE := "moving"

const EVENT_STATIC_WINDOW := "window"
const EVENT_MOVING_LINEAR_WINDOW := "window_moving_linear"
const EVENT_MOVING_SMOOTH_WINDOW := "window_moving_smooth"

const MUSIC_BASE_PATH := "res://assets/musics/"
const MUSIC_SELECT_SCENE := "res://scenes/menu/music_select.tscn"
const DEFAULT_WINDOW_TEXTURE := "res://assets/image/ingame/과녁.png"

enum MoveType {
	SMOOTH,
	LINEAR
}

@onready var target_spawner: Control = $TargetNoteSpawner

var texture_cache: Dictionary = {}
var window_pool: Array[Window] = []

var chart_data: Dictionary = {}
var current_time: float = 0.0
var is_playing: bool = false
var note_index: int = 0
var event_index: int = 0


func _ready() -> void:
	Global.reset_run()
	start_chart()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MUSIC_SELECT_SCENE)
	elif event.is_action_pressed("1"):
		_spawn_note(NORMAL_NOTE_MODE)
	elif event.is_action_pressed("2"):
		_spawn_note(MOVING_NOTE_MODE)
	elif event.is_action_pressed("3"):
		_spawn_note(NORMAL_NOTE_MODE, Vector2(2000.0, 1000.0))
	elif event.is_action_pressed("4"):
		create_moving_window(Vector2i(200, 200), Vector2i(100, 100), Vector2i(800, 100), 3.0, MoveType.SMOOTH, "Smooth", DEFAULT_WINDOW_TEXTURE)
	elif event.is_action_pressed("5"):
		create_moving_window(Vector2i(200, 200), Vector2i(100, 350), Vector2i(800, 350), 3.0, MoveType.LINEAR, "Linear", DEFAULT_WINDOW_TEXTURE)
	elif event.is_action_pressed("6"):
		create_static_window(Vector2i(200, 200), Vector2i(220, 220), 3.0, "Static", DEFAULT_WINDOW_TEXTURE)


func _process(delta: float) -> void:
	if not is_playing:
		return

	current_time += delta
	_process_due_notes()
	_process_due_events()


func start_chart() -> void:
	chart_data = load_chart()
	if chart_data == null:
		push_error("Cannot start chart.")
		return

	chart_data["notes"].sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	chart_data["events"].sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))

	note_index = 0
	event_index = 0
	current_time = 0.0
	is_playing = true
	print("Chart started: ", Global.selected_music)


func load_chart() -> Variant:
	_ensure_selected_music()
	if Global.selected_music == "":
		push_error("No music is selected.")
		return null

	var path := MUSIC_BASE_PATH + Global.selected_music + "/chart.json"
	if not FileAccess.file_exists(path):
		push_error("Chart file not found: " + path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open chart file: " + path)
		return null

	var chart = JSON.parse_string(file.get_as_text())
	if chart == null:
		push_error("Failed to parse chart JSON: " + path)
		return null
	if not chart is Dictionary:
		push_error("Chart root must be a Dictionary: " + path)
		return null

	if not chart.has("notes") or not chart["notes"] is Array:
		chart["notes"] = []
	if not chart.has("events") or not chart["events"] is Array:
		chart["events"] = []

	return chart


func _ensure_selected_music() -> void:
	if Global.selected_music != "":
		return

	if Global.music_titles.size() == 0:
		Global.music_titles = Global.get_folder_list(MUSIC_BASE_PATH)

	if Global.music_titles.size() > 0:
		Global.selected_music = Global.music_titles[0]


func _process_due_notes() -> void:
	while note_index < chart_data["notes"].size():
		var note: Dictionary = chart_data["notes"][note_index]
		if current_time < float(note.get("time", 0.0)):
			break

		_process_note(note)
		note_index += 1


func _process_due_events() -> void:
	while event_index < chart_data["events"].size():
		var event: Dictionary = chart_data["events"][event_index]
		if current_time < float(event.get("time", 0.0)):
			break

		_process_event(event)
		event_index += 1


func _process_note(note_info: Dictionary) -> void:
	if not note_info.has("x") or not note_info.has("y"):
		push_warning("Skipping invalid note: " + str(note_info))
		return

	var pos := Vector2(float(note_info["x"]), float(note_info["y"]))
	var mode := NORMAL_NOTE_MODE
	if str(note_info.get("type", NORMAL_NOTE_MODE)) == MOVING_NOTE_MODE:
		mode = MOVING_NOTE_MODE

	_spawn_note(mode, pos)


func _process_event(event_info: Dictionary) -> void:
	var event_type := str(event_info.get("type", ""))
	if not event_info.has("x") or not event_info.has("y"):
		push_warning("Skipping invalid event: " + str(event_info))
		return

	var size := Vector2i(int(event_info.get("width", 200)), int(event_info.get("height", 200)))
	var pos := Vector2i(int(event_info["x"]), int(event_info["y"]))
	var target_pos := _get_event_target_position(event_info, pos)
	var duration := float(event_info.get("duration", 3.0))
	var title := str(event_info.get("title", "Event Window"))
	var texture_path := str(event_info.get("texture_path", ""))
	if texture_path == "":
		texture_path = DEFAULT_WINDOW_TEXTURE

	match event_type:
		EVENT_STATIC_WINDOW:
			create_static_window(size, pos, duration, title, texture_path)
		EVENT_MOVING_LINEAR_WINDOW:
			create_moving_window(size, pos, target_pos, duration, MoveType.LINEAR, title, texture_path)
		EVENT_MOVING_SMOOTH_WINDOW:
			create_moving_window(size, pos, target_pos, duration, MoveType.SMOOTH, title, texture_path)
		_:
			push_warning("Unknown chart event type: " + event_type)


func _get_event_target_position(event_info: Dictionary, fallback_pos: Vector2i) -> Vector2i:
	return Vector2i(
		int(event_info.get("target_x", event_info.get("to_x", fallback_pos.x))),
		int(event_info.get("target_y", event_info.get("to_y", fallback_pos.y)))
	)


func _spawn_note(mode: String, target_pos: Variant = null) -> void:
	if target_spawner and target_spawner.has_method("spawn_node"):
		target_spawner.spawn_node(mode, target_pos)


func create_moving_window(size: Vector2i, start_rel_pos: Vector2i, target_rel_pos: Vector2i, move_duration: float, move_type: MoveType, title: String, img_path: String) -> void:
	if _is_headless_display():
		return

	var window := _get_or_create_window(size, title, img_path)
	if window == null:
		return

	window.current_screen = get_window().current_screen
	window.position = get_window().position + start_rel_pos
	window.show()

	if move_type == MoveType.SMOOTH:
		_animate_window_movement_smooth(window, target_rel_pos, move_duration)
	else:
		_animate_window_movement_linear(window, target_rel_pos, move_duration)


func create_static_window(size: Vector2i, rel_pos: Vector2i, duration: float, title: String, img_path: String) -> void:
	if _is_headless_display():
		return

	var window := _get_or_create_window(size, title, img_path)
	if window == null:
		return

	window.current_screen = get_window().current_screen
	window.position = get_window().position + rel_pos
	window.show()

	if duration > 0.0:
		var tween := window.create_tween()
		tween.tween_interval(duration)
		tween.tween_callback(window.hide)


func _get_or_create_window(size: Vector2i, title: String, img_path: String) -> Window:
	if not texture_cache.has(img_path):
		texture_cache[img_path] = load(img_path)
	if texture_cache[img_path] == null:
		push_error("Window texture not found: " + img_path)
		return null

	for i in range(window_pool.size() - 1, -1, -1):
		var window := window_pool[i]
		if not is_instance_valid(window):
			window_pool.remove_at(i)
			continue
		if not window.visible:
			window.size = size
			window.title = title
			var texture_rect := window.get_node("TextureRect") as TextureRect
			texture_rect.texture = texture_cache[img_path]
			return window

	var new_window := Window.new()
	new_window.title = title
	new_window.size = size
	new_window.transient = true
	new_window.transparent = true
	new_window.unfocusable = true
	new_window.close_requested.connect(new_window.hide)

	var texture_rect := TextureRect.new()
	texture_rect.name = "TextureRect"
	texture_rect.texture = texture_cache[img_path]
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	new_window.add_child(texture_rect)
	add_child(new_window)
	window_pool.append(new_window)
	return new_window


func _is_headless_display() -> bool:
	return OS.has_feature("headless") or "--headless" in OS.get_cmdline_args() or "--headless-test" in OS.get_cmdline_user_args() or OS.get_environment("GODOT_HEADLESS_TEST") == "1"


func _animate_window_movement_smooth(window: Window, target_rel_pos: Vector2i, duration: float) -> void:
	var absolute_target_pos := get_window().position + target_rel_pos
	var tween := window.create_tween()
	tween.tween_property(window, "position", absolute_target_pos, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(window.hide)


func _animate_window_movement_linear(window: Window, target_rel_pos: Vector2i, duration: float) -> void:
	var absolute_target_pos := get_window().position + target_rel_pos
	var tween := window.create_tween()
	tween.tween_property(window, "position", absolute_target_pos, duration) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(window.hide)
