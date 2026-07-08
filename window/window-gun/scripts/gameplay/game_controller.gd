extends Control

const NORMAL_NOTE_MODE = "normal"
const MOVING_NOTE_MODE = "moving"

# ?덈룄???대깽???곸닔 (湲곗〈)
const EVENT_STATIC_WINDOW = "window"
const EVENT_MOVING_LINEAR_WINDOW = "window_moving_linear"
const EVENT_MOVING_SMOOTH_WINDOW = "window_moving_smooth"

# ?대?吏 ?몃뱶 ?대깽???곸닔 (?좉퇋 異붽?)
const EVENT_STATIC_IMAGE = "image"
const EVENT_MOVING_LINEAR_IMAGE = "image_moving_linear"
const EVENT_MOVING_SMOOTH_IMAGE = "image_moving_smooth"

const MUSIC_BASE_PATH = "res://assets/musics/"
const MUSIC_SELECT_SCENE = "res://scenes/menu/music_select.tscn"
const DEFAULT_WINDOW_TEXTURE = "res://assets/image/ingame/怨쇰뀅.png"
const TargetNoteScript = preload("res://scripts/gameplay/target_note.gd")
const DEFAULT_BPM = 120.0
const MIN_POSITIVE_DURATION = 0.01

enum MoveType {
	SMOOTH,
	LINEAR
}

@onready var target_spawner: Control = $TargetNoteSpawner

var texture_cache: Dictionary = {}

# ?ㅻ툕?앺듃 ? (?덈룄?곗슜, ?대?吏??遺꾨━)
var window_pool: Array[Window] = []
var image_pool: Array[TextureRect] = [] # ?좉퇋 異붽?

var chart_data: Dictionary = {}
var current_time: float = 0.0
var is_playing: bool = false
var note_index: int = 0
var event_index: int = 0
var bpm: float = DEFAULT_BPM

# 移대찓???곗씠???쒖뼱 蹂??(?듭뀡 C ?꾨꼍 ???
var shake_timer: float = 0.0
var shake_intensity: float = 0.0
var original_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	original_position = position
	Global.camera_shake_requested.connect(_on_camera_shake_requested)
	
	# ?명듃瑜??댄럺?몃낫???꾩뿉 ?쒖떆?섍린 ?꾪븳 ?꾩슜 ?덉씠???앹꽦
	var note_layer = CanvasLayer.new()
	note_layer.name = "NoteLayer"
	note_layer.layer = 10 # 湲곕낯 ?덉씠??0)蹂대떎 ?믪? 媛??ㅼ젙
	add_child(note_layer)
	
	# 湲곗〈 ?ㅽ룷?덈? ?덈줈???덉씠?대줈 ?대룞
	if target_spawner:
		target_spawner.reparent(note_layer)
	
	Global.reset_run()
	start_chart()



func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if Global.is_editor_test_mode:
			SceneTransition.transition_to_scene("res://scenes/menu/chart_editor.tscn")
		else:
			SceneTransition.transition_to_scene(MUSIC_SELECT_SCENE)
	
	# ?붾쾭洹몄슜 湲곕뒫 (?붾쾭洹?鍮뚮뱶?먯꽌留??숈옉)
	if OS.is_debug_build():
		if event.is_action_pressed("1"):
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
		elif event.is_action_pressed("7"):
			create_moving_image(Vector2i(200, 200), Vector2i(100, 500), Vector2i(800, 500), 3.0, MoveType.SMOOTH, DEFAULT_WINDOW_TEXTURE)
		elif event.is_action_pressed("8"):
			create_moving_image(Vector2i(200, 200), Vector2i(100, 700), Vector2i(800, 700), 3.0, MoveType.LINEAR, DEFAULT_WINDOW_TEXTURE)
		elif event.is_action_pressed("9"):
			create_static_image(Vector2i(200, 200), Vector2i(400, 400), 3.0, DEFAULT_WINDOW_TEXTURE)


func _process(delta: float) -> void:
	# 留??꾨젅???뚮젅???뺤? ?곹깭?щ룄 ?곗씠?뱀? ?낅┰ ?묐룞?섎룄濡??뺤? ?뺤씤 ?꾩뿉 ?섑뻾
	_process_camera_shake(delta)

	if not is_playing:
		return

	# ?ㅻ뵒???뚮젅?댁뼱? ?깊겕 留욎텛湲?(Global.audio_player 李몄“ ?쒖슜)
	if Global.audio_player and Global.audio_player.playing:
		# ?ㅻ뵒???ъ깮 ?꾩튂 + 吏??蹂댁젙 + 湲濡쒕쾶 ?ㅽ봽??
		var audio_pos = Global.audio_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		# Global.music_offset? Res.tres??媛쒕퀎 怨??ㅽ봽??(怨≪씠 ?쒖옉?섍린 ?꾧퉴吏???쒓컙)
		# AudioStreamPlayer媛 ?ъ깮 以묒씠誘濡? ?꾩옱 李⑦듃 ?쒓컙? audio_pos + 怨??쒖옉 ?湲??쒓컙(music_offset) ?댁뼱????
		# ?섏?留?audio_stream_player.gd?먯꽌 timer濡?music_offset留뚰겮 湲곕떎?몃떎媛 play()瑜??섎?濡?
		# audio_pos媛 0???쒖젏??current_time? ?대? music_offset ?댁뼱????
		# ?ㅻ뵒???ㅽ겕由쏀듃??GLOBAL_TIMING_OFFSET(0.6)??怨좊젮?댁빞 ??
		
		# 蹂대떎 ?⑥닚?섍퀬 ?뺥솗??諛⑹떇:
		# ?ㅻ뵒???ъ깮 ?꾧퉴吏??delta濡??꾩쟻?섎떎媛, ?ъ깮???쒖옉?섎㈃ ?ㅻ뵒???꾩튂瑜?湲곗??쇰줈 蹂댁젙
		var target_time = audio_pos + 0.7 - Global.music_offset # GLOBAL_TIMING_OFFSET 蹂댁젙 諛?媛쒕퀎 ?뚯썝 ?ㅽ봽??李④컧
		current_time = lerp(current_time, target_time, 0.1) # 湲됯꺽????諛⑹?
	else:
		current_time += delta
		
	_process_due_notes()
	_process_due_events()
	_check_song_finished()


func _on_camera_shake_requested(intensity: float, duration: float) -> void:
	if not Global.enable_camera_shake:
		return
	shake_intensity = intensity
	shake_timer = duration


func _process_camera_shake(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta
		if shake_timer <= 0.0:
			position = original_position
		else:
			# 臾댁옉???ㅽ봽??吏꾨룞 怨꾩궛 (Perfect/Great 洹뱀쟻 ?먮쭧 ?곗텧)
			var offset_x = randf_range(-shake_intensity, shake_intensity)
			var offset_y = randf_range(-shake_intensity, shake_intensity)
			position = original_position + Vector2(offset_x, offset_y)



func start_chart() -> void:
	TargetNoteScript.reset_state() # ?댁쟾 ?먯쓽 ?명듃 ?붿옱 ?쒓굅
	chart_data = load_chart()
	if chart_data == null:
		push_error("Cannot start chart.")
		return

	# BPM must be loaded before max score calculation so hold-note ticks match gameplay.
	var res_path = Global.get_music_res_path(Global.selected_music)
	if FileAccess.file_exists(res_path):
		var music_res = load(res_path)
		if music_res and "bpm" in music_res:
			bpm = _sanitize_positive_float(music_res.bpm, DEFAULT_BPM, "BPM")
			print("BPM loaded: ", bpm)
		else:
			print("BPM property not found in Res.tres, using default 120.0")
	else:
		print("Res.tres not found, using default 120.0")

	var total_max_score = 0
	for note in chart_data.get("notes", []):
		if not note is Dictionary:
			continue
		var note_type = str(note.get("type", "normal"))
		if note_type == "hold":
			var dur = _sanitize_positive_float(note.get("duration", 3.0), 3.0, "hold duration")
			var beat_div = _sanitize_positive_int(note.get("beat_division", 4), 4, "hold beat_division")
			var interval = max((60.0 / bpm) * (4.0 / float(beat_div)), MIN_POSITIVE_DURATION)
			var scoring_duration = max(dur - Global.judgment_perfect_margin, 0.0)
			var ticks = int(scoring_duration / interval)
			total_max_score += ticks * 10
		else:
			total_max_score += 100

	Global.max_base_score = max(total_max_score, 100)
	print("Max theoretical base score calculated: ", Global.max_base_score)
	
	if Global.is_editor_test_mode and Global.editor_test_start_time > 0.01:
		current_time = max(0.0, Global.editor_test_start_time - 1.0)
	else:
		current_time = 0.0
	is_playing = true
	print("李⑦듃 濡쒕뱶 ?깃났: ", chart_data.get("notes", []).size(), "媛쒖쓽 ?명듃")


func load_chart() -> Variant:
	_ensure_selected_music()
	if Global.selected_music == "":
		push_error("No music is selected.")
		return null

	var path = Global.get_music_chart_path(Global.selected_music)
	if not FileAccess.file_exists(path):
		push_error("Chart file not found: " + path)
		return null

	var file = FileAccess.open(path, FileAccess.READ)
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

	chart = _sanitize_chart(chart)

	# ?몃옒 湲몄씠 ?鍮??명듃 理쒕? 媛쒖닔 ?쒗븳 怨꾩궛
	var song_len = 180.0
	var res_path = Global.get_music_res_path(Global.selected_music)
	if FileAccess.file_exists(res_path):
		var music_res = load(res_path)
		if music_res and music_res.get("audio_stream"):
			song_len = music_res.get("audio_stream").get_length()
	
	var max_notes = int(song_len / Global.note_limit_seconds_interval)
	if chart["notes"].size() > max_notes:
		push_warning("Note count exceeds max limit (" + str(max_notes) + ")! Exceeding latest notes will be filtered out.")
		# ?쒓컙 湲곗??쇰줈 ?뺣젹 ?? ?덉슜移섎? 珥덇낵?????쒓컙????명듃?ㅼ? ?멸쾶??濡쒕뵫?먯꽌 諛곗젣
		chart["notes"].sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
		chart["notes"] = chart["notes"].slice(0, max_notes)

	# --- 異붽???遺遺? time 湲곗??쇰줈 ?먮룞 ?뺣젹 ---
	chart["notes"].sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	
	# 移????녿뒗 ?명듃 ?꾪꽣留?(?쒓컙 ?鍮?嫄곕━媛 ?띾룄 ?쒕룄 珥덇낵)
	var filtered_notes = []
	var last_hittable_note = null
	
	for note in chart["notes"]:
		if not note is Dictionary:
			continue
		
		if last_hittable_note == null:
			filtered_notes.append(note)
			last_hittable_note = note
		else:
			var t1 = float(last_hittable_note.get("time", 0.0))
			if str(last_hittable_note.get("type", "normal")) == "hold":
				t1 += float(last_hittable_note.get("duration", 3.0))
				
			var t2 = float(note.get("time", 0.0))
			var dt = t2 - t1
			
			var p1 = Vector2(float(last_hittable_note.get("x", 960.0)), float(last_hittable_note.get("y", 540.0)))
			var p2 = Vector2(float(note.get("x", 960.0)), float(note.get("y", 540.0)))
			var dist = p1.distance_to(p2)
			
			# ?몄젒 ?명듃 媛?嫄곕━媛 留ㅼ슦 媛源뚯슦硫??? 50px 誘몃쭔) 移????덈뒗 寃껋쑝濡?媛꾩＜?섏뿬 ?꾪꽣留?????쒖쇅
			var speed = 0.0
			if dist >= 50.0:
				speed = dist / dt if dt > 0.001 else 999999.0
			else:
				speed = 0.0 if dt >= 0.0 else 999999.0
			
			if speed <= Global.max_note_speed:
				filtered_notes.append(note)
				last_hittable_note = note
			else:
				print("Unhittable note blocked! Speed: ", speed, " px/s, Limit: ", Global.max_note_speed)
				
	chart["notes"] = filtered_notes
	chart["events"].sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	# ----------------------------------------

	# 援щ쾭??李⑦듃 醫뚰몴 蹂댁젙 (offset_corrected ?뚮옒洹멸? ?녿뒗 寃쎌슦)
	if not chart.get("offset_corrected", false):
		for note in chart["notes"]:
			if note is Dictionary:
				if note.has("x"):
					note["x"] = float(note["x"]) - 230.0
				if note.has("y"):
					note["y"] = float(note["y"]) - 90.0
				if note.has("start_x"):
					note["start_x"] = float(note["start_x"]) - 230.0
				if note.has("start_y"):
					note["start_y"] = float(note["start_y"]) - 90.0
		chart["offset_corrected"] = true

	return chart


func _sanitize_chart(chart: Dictionary) -> Dictionary:
	var sanitized_notes: Array = []
	for i in range(chart.get("notes", []).size()):
		var note = chart["notes"][i]
		if not note is Dictionary:
			push_warning("Skipping non-dictionary note at index " + str(i))
			continue
		var clean_note = _sanitize_note(note, i)
		if clean_note != null:
			sanitized_notes.append(clean_note)
	chart["notes"] = sanitized_notes

	var sanitized_events: Array = []
	for i in range(chart.get("events", []).size()):
		var event = chart["events"][i]
		if not event is Dictionary:
			push_warning("Skipping non-dictionary event at index " + str(i))
			continue
		var clean_event = _sanitize_event(event, i)
		if clean_event != null:
			sanitized_events.append(clean_event)
	chart["events"] = sanitized_events
	return chart


func _sanitize_note(note: Dictionary, index: int) -> Variant:
	var note_type = str(note.get("type", NORMAL_NOTE_MODE))
	if note_type not in [NORMAL_NOTE_MODE, MOVING_NOTE_MODE, "hold"]:
		push_warning("Skipping note with unknown type at index " + str(index) + ": " + note_type)
		return null

	note["time"] = _sanitize_non_negative_float(note.get("time", 0.0), 0.0, "note time")

	if note_type == "hold":
		note["duration"] = _sanitize_positive_float(note.get("duration", 3.0), 3.0, "hold duration")
		note["beat_division"] = _sanitize_positive_int(note.get("beat_division", 4), 4, "hold beat_division")
		return note

	if not note.has("x") or not note.has("y"):
		push_warning("Skipping note without x/y at index " + str(index))
		return null
	note["x"] = float(note["x"])
	note["y"] = float(note["y"])

	if note_type == MOVING_NOTE_MODE:
		if note.has("start_x"):
			note["start_x"] = float(note["start_x"])
		if note.has("start_y"):
			note["start_y"] = float(note["start_y"])
		if note.has("curve_control_x"):
			note["curve_control_x"] = float(note["curve_control_x"])
		if note.has("curve_control_y"):
			note["curve_control_y"] = float(note["curve_control_y"])
		note["move_duration"] = _sanitize_non_negative_float(note.get("move_duration", 0.0), 0.0, "move_duration")
	return note


func _sanitize_event(event: Dictionary, index: int) -> Variant:
	var event_type = str(event.get("type", ""))
	if event_type not in [
		EVENT_STATIC_WINDOW,
		EVENT_MOVING_LINEAR_WINDOW,
		EVENT_MOVING_SMOOTH_WINDOW,
		EVENT_STATIC_IMAGE,
		EVENT_MOVING_LINEAR_IMAGE,
		EVENT_MOVING_SMOOTH_IMAGE
	]:
		push_warning("Skipping event with unknown type at index " + str(index) + ": " + event_type)
		return null

	if not event.has("x") or not event.has("y"):
		push_warning("Skipping event without x/y at index " + str(index))
		return null
	event["time"] = _sanitize_non_negative_float(event.get("time", 0.0), 0.0, "event time")
	event["x"] = float(event["x"])
	event["y"] = float(event["y"])
	event["width"] = _sanitize_positive_int(event.get("width", 200), 200, "event width")
	event["height"] = _sanitize_positive_int(event.get("height", 200), 200, "event height")
	event["duration"] = _sanitize_positive_float(event.get("duration", 3.0), 3.0, "event duration")
	event["opacity"] = clamp(float(event.get("opacity", 1.0)), 0.0, 1.0)
	return event


func _sanitize_positive_float(value: Variant, fallback: float, label: String) -> float:
	var result = float(value)
	if result <= 0.0:
		push_warning(label + " must be positive; using " + str(fallback))
		return fallback
	return result


func _sanitize_non_negative_float(value: Variant, fallback: float, label: String) -> float:
	var result = float(value)
	if result < 0.0:
		push_warning(label + " must be non-negative; using " + str(fallback))
		return fallback
	return result


func _sanitize_positive_int(value: Variant, fallback: int, label: String) -> int:
	var result = int(value)
	if result <= 0:
		push_warning(label + " must be positive; using " + str(fallback))
		return fallback
	return result


func _ensure_selected_music() -> void:
	if Global.selected_music != "":
		return

	if Global.music_titles.size() == 0:
		Global.music_titles = Global.get_folder_list(Global.MUSIC_BASE_PATH)

	if "R" in Global.music_titles:
		Global.selected_music = "R"
	elif Global.music_titles.size() > 0:
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
	var note_type = str(note_info.get("type", NORMAL_NOTE_MODE))
	if note_type == "hold":
		_spawn_hold_note(note_info)
		return

	if not note_info.has("x") or not note_info.has("y"):
		push_warning("Skipping invalid note: " + str(note_info))
		return

	var pos = Vector2(float(note_info["x"]), float(note_info["y"]))
	var mode = NORMAL_NOTE_MODE
	var start_pos = null
	if str(note_info.get("type", NORMAL_NOTE_MODE)) == MOVING_NOTE_MODE:
		mode = MOVING_NOTE_MODE
		if note_info.has("start_x") and note_info.has("start_y"):
			start_pos = Vector2(float(note_info["start_x"]), float(note_info["start_y"]))

	# 而ㅻ툕 諛?以묐젰 ?곗씠??異붿텧 (?섏쐞 ?명솚: ?놁쑝硫?null/false)
	var curve_control = null
	if note_info.has("curve_control_x") and note_info.has("curve_control_y"):
		curve_control = Vector2(float(note_info["curve_control_x"]), float(note_info["curve_control_y"]))
	var use_gravity = note_info.get("use_gravity", false)
	var move_duration = float(note_info.get("move_duration", 0.0))
	
	_spawn_note(mode, pos, start_pos, curve_control, use_gravity, move_duration)


func _spawn_hold_note(note_info: Dictionary) -> void:
	var duration = float(note_info.get("duration", 3.0))
	var beat_division = int(note_info.get("beat_division", 4)) # 湲곕낯 4諛뺤옄(4遺꾩쓬??
	duration = _sanitize_positive_float(duration, 3.0, "hold duration")
	beat_division = _sanitize_positive_int(beat_division, 4, "hold beat_division")
	var hold_script = load("res://scripts/gameplay/hold_note.gd")
	if hold_script:
		var hold_instance = hold_script.new()
		hold_instance.duration = duration
		hold_instance.bpm = bpm
		hold_instance.beat_division = beat_division
		
		var note_layer = get_node_or_null("NoteLayer")
		if note_layer:
			note_layer.add_child(hold_instance)
		else:
			add_child(hold_instance)
		print("Spawned HoldNote with duration: ", duration, ", BPM: ", bpm, ", Division: ", beat_division)


func _process_event(event_info: Dictionary) -> void:
	var event_type = str(event_info.get("type", ""))
	if not event_info.has("x") or not event_info.has("y"):
		push_warning("Skipping invalid event: " + str(event_info))
		return

	var size = Vector2i(int(event_info.get("width", 200)), int(event_info.get("height", 200)))
	var pos = Vector2i(int(event_info["x"]), int(event_info["y"]))
	var target_pos = _get_event_target_position(event_info, pos)
	var duration = float(event_info.get("duration", 3.0))
	duration = _sanitize_positive_float(duration, 3.0, "event duration")
	var title = str(event_info.get("title", "Event Window"))
	var texture_path = str(event_info.get("texture_path", ""))
	if texture_path == "":
		texture_path = DEFAULT_WINDOW_TEXTURE

	var opacity = float(event_info.get("opacity", 1.0))

	opacity = clamp(opacity, 0.0, 1.0)

	var node: Node = null
	match event_type:
		# --- 湲곗〈 ?덈룄???대깽??---
		EVENT_STATIC_WINDOW:
			node = create_static_window(size, pos, duration, title, texture_path)
		EVENT_MOVING_LINEAR_WINDOW:
			node = create_moving_window(size, pos, target_pos, duration, MoveType.LINEAR, title, texture_path)
		EVENT_MOVING_SMOOTH_WINDOW:
			node = create_moving_window(size, pos, target_pos, duration, MoveType.SMOOTH, title, texture_path)
			
		# --- ?좉퇋 異붽???寃뚯엫 ???대?吏 ?대깽??---
		EVENT_STATIC_IMAGE:
			node = create_static_image(size, pos, duration, texture_path)
		EVENT_MOVING_LINEAR_IMAGE:
			node = create_moving_image(size, pos, target_pos, duration, MoveType.LINEAR, texture_path)
		EVENT_MOVING_SMOOTH_IMAGE:
			node = create_moving_image(size, pos, target_pos, duration, MoveType.SMOOTH, texture_path)
		_:
			push_warning("Unknown chart event type: " + event_type)
	
	if node:
		if node is Window:
			var tr = node.get_node_or_null("TextureRect")
			if tr:
				tr.modulate.a = opacity
		elif node is CanvasItem:
			node.modulate.a = opacity


func _get_event_target_position(event_info: Dictionary, fallback_pos: Vector2i) -> Vector2i:
	return Vector2i(
		int(event_info.get("target_x", event_info.get("to_x", fallback_pos.x))),
		int(event_info.get("target_y", event_info.get("to_y", fallback_pos.y)))
	)


func _spawn_note(mode: String, target_pos: Variant = null, start_pos: Variant = null, curve_control: Variant = null, use_gravity: bool = false, move_duration: float = 0.0) -> void:
	if target_spawner and target_spawner.has_method("spawn_node"):
		target_spawner.spawn_node(mode, target_pos, start_pos, curve_control, use_gravity, move_duration)


# ==========================================
# 湲곗〈 Window 湲곕컲 ?앹꽦 ?⑥닔??(?좎???
# ==========================================

func create_moving_window(size: Vector2i, start_rel_pos: Vector2i, target_rel_pos: Vector2i, move_duration: float, move_type: MoveType, title: String, img_path: String) -> Window:
	if _is_headless_display():
		return null
	move_duration = max(move_duration, MIN_POSITIVE_DURATION)

	var window = _get_or_create_window(size, title, img_path)
	if window == null:
		return

	window.current_screen = get_window().current_screen
	window.position = get_window().position + start_rel_pos
	window.show()

	if move_type == MoveType.SMOOTH:
		_animate_window_movement_smooth(window, target_rel_pos, move_duration)
	else:
		_animate_window_movement_linear(window, target_rel_pos, move_duration)
	
	return window


func create_static_window(size: Vector2i, rel_pos: Vector2i, duration: float, title: String, img_path: String) -> Window:
	if _is_headless_display():
		return null

	var window = _get_or_create_window(size, title, img_path)
	if window == null:
		return

	window.current_screen = get_window().current_screen
	window.position = get_window().position + rel_pos
	window.show()

	if duration > 0.0:
		var tween = window.create_tween()
		tween.tween_interval(duration)
		tween.tween_callback(window.hide)
	
	return window



func _get_cached_texture(img_path: String) -> Texture2D:
	if not texture_cache.has(img_path):
		if ResourceLoader.exists(img_path):
			texture_cache[img_path] = load(img_path)
		else:
			texture_cache[img_path] = null
	return texture_cache[img_path]

func _get_or_create_window(size: Vector2i, title: String, img_path: String) -> Window:
	var texture = _get_cached_texture(img_path)
	if texture == null:
		push_error("Window texture not found: " + img_path)
		return null

	for i in range(window_pool.size() - 1, -1, -1):
		var window = window_pool[i]
		if not is_instance_valid(window):
			window_pool.remove_at(i)
			continue
		if not window.visible:
			window.size = size
			window.title = title
			var texture_rect = window.get_node("TextureRect") as TextureRect
			texture_rect.texture = texture
			return window

	var new_window = Window.new()
	new_window.title = title
	new_window.size = size
	new_window.transient = true
	new_window.transparent = true
	new_window.unfocusable = true
	new_window.close_requested.connect(new_window.hide)

	var texture_rect = TextureRect.new()
	texture_rect.name = "TextureRect"
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	new_window.add_child(texture_rect)
	add_child(new_window)
	window_pool.append(new_window)
	return new_window

func _animate_window_movement_smooth(window: Window, target_rel_pos: Vector2i, duration: float) -> void:
	var absolute_target_pos = get_window().position + target_rel_pos
	var tween = window.create_tween()
	tween.tween_property(window, "position", absolute_target_pos, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(window.hide)

func _animate_window_movement_linear(window: Window, target_rel_pos: Vector2i, duration: float) -> void:
	var absolute_target_pos = get_window().position + target_rel_pos
	var tween = window.create_tween()
	tween.tween_property(window, "position", absolute_target_pos, duration) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(window.hide)


# ==========================================
# ?좉퇋 TextureRect (寃뚯엫 ???몃뱶) ?ㅽ룿 ?⑥닔??
# ==========================================

func create_moving_image(size: Vector2i, start_pos: Vector2i, target_pos: Vector2i, move_duration: float, move_type: MoveType, img_path: String) -> TextureRect:
	move_duration = max(move_duration, MIN_POSITIVE_DURATION)
	var img_node = _get_or_create_image(size, img_path)
	if img_node == null:
		return null

	img_node.position = start_pos
	img_node.show()

	if move_type == MoveType.SMOOTH:
		_animate_image_movement_smooth(img_node, target_pos, move_duration)
	else:
		_animate_image_movement_linear(img_node, target_pos, move_duration)
	
	return img_node


func create_static_image(size: Vector2i, pos: Vector2i, duration: float, img_path: String) -> TextureRect:
	var img_node = _get_or_create_image(size, img_path)
	if img_node == null:
		return null

	img_node.position = pos
	img_node.show()

	if duration > 0.0:
		var tween = img_node.create_tween()
		tween.tween_interval(duration)
		tween.tween_callback(img_node.hide)
	
	return img_node


func _get_or_create_image(size: Vector2i, img_path: String) -> TextureRect:
	var texture = _get_cached_texture(img_path)
	if texture == null:
		push_error("Image texture not found: " + img_path)
		return null

	# ?(Pool)?먯꽌 ???곌퀬 ?덈뒗 TextureRect 李얘린
	for i in range(image_pool.size() - 1, -1, -1):
		var img_node = image_pool[i]
		if not is_instance_valid(img_node):
			image_pool.remove_at(i)
			continue
		if not img_node.visible:
			# [?섏젙?듭떖 1] ?띿뒪泥섎? ?ｊ퀬 ?댁쟾 ?ш린 湲곗뼲??媛뺤젣濡?吏???????ш린 ??뼱?곌린
			img_node.texture = texture
			img_node.reset_size() 
			img_node.size = size
			return img_node

	# ????놁쑝硫??덈줈 ?앹꽦?섏뿬 寃뚯엫 ?붾㈃(???몃━)??異붽?
	var new_image = TextureRect.new()
	
	# [?섏젙?듭떖 2] expand_mode瑜?媛??癒쇱? ?ㅼ젙?댁빞 ?먮낯 ?ш린濡????寃껋쓣 諛⑹???
	new_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	new_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	new_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	new_image.texture = texture
	new_image.size = size # ?ㅻ쪟瑜??쇱쑝?ㅻ뜕 custom_minimum_size ?띿꽦 ??젣

	add_child(new_image)
	image_pool.append(new_image)
	return new_image


func _animate_image_movement_smooth(img_node: TextureRect, target_pos: Vector2i, duration: float) -> void:
	var tween = img_node.create_tween()
	tween.tween_property(img_node, "position", Vector2(target_pos), duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(img_node.hide)


func _animate_image_movement_linear(img_node: TextureRect, target_pos: Vector2i, duration: float) -> void:
	var tween = img_node.create_tween()
	tween.tween_property(img_node, "position", Vector2(target_pos), duration) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(img_node.hide)


# ?좏떥由ы떚 ?⑥닔
func _is_headless_display() -> bool:
	return OS.has_feature("headless") or "--headless" in OS.get_cmdline_args() or "--headless-test" in OS.get_cmdline_user_args() or OS.get_environment("GODOT_HEADLESS_TEST") == "1"


# 怨??꾨즺 ?щ? 泥댄겕 ?⑥닔
func _check_song_finished() -> void:
	if not is_playing:
		return

	# 李⑦듃??紐⑤뱺 ?명듃媛 諛⑹텧?섏뿀?붿? ?뺤씤
	if note_index < chart_data.get("notes", []).size():
		return

	# ?꾩옱 ?붾㈃???댁븘 ?덈뒗 TargetNote 媛쒖닔 ?뺤씤
	var has_active_notes = false
	if target_spawner:
		for child in target_spawner.get_children():
			if "TargetNote" in child.name or child.has_method("activate_stationary"):
				has_active_notes = true
				break

	# ?꾩옱 ?붾㈃???댁븘 ?덈뒗 HoldNote 媛쒖닔 ?뺤씤
	var hold_notes_active = false
	var note_layer = get_node_or_null("NoteLayer")
	if note_layer:
		for child in note_layer.get_children():
			if "HoldNote" in child.name or child.has_method("_is_holding"):
				hold_notes_active = true
				break

	if not has_active_notes and not hold_notes_active:
		# 留덉?留??명듃??由대━利??댄썑 吏???쒓컙 ?뺣낫
		var last_note_time = 0.0
		var notes = chart_data.get("notes", [])
		if notes.size() > 0:
			var last_note = notes[-1]
			last_note_time = float(last_note.get("time", 0.0)) + float(last_note.get("duration", 2.0))

		# ?ㅻ뵒???ㅽ듃由쇱씠 硫덉톬嫄곕굹 留덉?留??명듃 ?뚮젅???쒓컙??異⑸텇???섎?????醫낅즺
		var audio_stopped = Global.audio_player != null and not Global.audio_player.playing
		if (audio_stopped and current_time > last_note_time) or (current_time > last_note_time + 3.0):
			is_playing = false
			_transition_to_result_scene()


# 寃곌낵 ?붾㈃ ???꾪솚
func _transition_to_result_scene() -> void:
	print("Song complete! Transitioning to result scene...")
	# SceneTransition ?꾩뿭 ?먮룞濡쒕뱶瑜??댁슜???먯뿰?ㅻ윭???섏씠???꾪솚
	var result_path = "res://scenes/menu/result_scene.tscn"
	SceneTransition.transition_to_scene(result_path)
