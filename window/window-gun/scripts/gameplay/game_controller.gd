extends Control

const NORMAL_NOTE_MODE = "normal"
const MOVING_NOTE_MODE = "moving"

# 윈도우 이벤트 상수 (기존)
const EVENT_STATIC_WINDOW = "window"
const EVENT_MOVING_LINEAR_WINDOW = "window_moving_linear"
const EVENT_MOVING_SMOOTH_WINDOW = "window_moving_smooth"

# 이미지 노드 이벤트 상수 (신규 추가)
const EVENT_STATIC_IMAGE = "image"
const EVENT_MOVING_LINEAR_IMAGE = "image_moving_linear"
const EVENT_MOVING_SMOOTH_IMAGE = "image_moving_smooth"

const MUSIC_BASE_PATH = "res://assets/musics/"
const MUSIC_SELECT_SCENE = "res://scenes/menu/music_select.tscn"
const DEFAULT_WINDOW_TEXTURE = "res://assets/image/ingame/과녁.png"
const TargetNoteScript = preload("res://scripts/gameplay/target_note.gd")

enum MoveType {
	SMOOTH,
	LINEAR
}

@onready var target_spawner: Control = $TargetNoteSpawner

var texture_cache: Dictionary = {}

# 오브젝트 풀 (윈도우용, 이미지용 분리)
var window_pool: Array[Window] = []
var image_pool: Array[TextureRect] = [] # 신규 추가

var chart_data: Dictionary = {}
var current_time: float = 0.0
var is_playing: bool = false
var note_index: int = 0
var event_index: int = 0
var bpm: float = 120.0

# 카메라 셰이크 제어 변수 (옵션 C 완벽 대응)
var shake_timer: float = 0.0
var shake_intensity: float = 0.0
var original_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	original_position = position
	Global.camera_shake_requested.connect(_on_camera_shake_requested)
	
	# 노트를 이펙트보다 위에 표시하기 위한 전용 레이어 생성
	var note_layer = CanvasLayer.new()
	note_layer.name = "NoteLayer"
	note_layer.layer = 10 # 기본 레이어(0)보다 높은 값 설정
	add_child(note_layer)
	
	# 기존 스포너를 새로운 레이어로 이동
	if target_spawner:
		target_spawner.reparent(note_layer)
	
	Global.reset_run()
	start_chart()



func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		SceneTransition.transition_to_scene(MUSIC_SELECT_SCENE)
	
	# 디버그용 기능 (디버그 빌드에서만 동작)
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
	# 매 프레임 플레이 정지 상태여도 셰이킹은 독립 작동하도록 정지 확인 전에 수행
	_process_camera_shake(delta)

	if not is_playing:
		return

	# 오디오 플레이어와 싱크 맞추기 (Global.audio_player 참조 활용)
	if Global.audio_player and Global.audio_player.playing:
		# 오디오 재생 위치 + 지연 보정 + 글로벌 오프셋
		var audio_pos = Global.audio_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		# Global.music_offset은 Res.tres의 개별 곡 오프셋 (곡이 시작되기 전까지의 시간)
		# AudioStreamPlayer가 재생 중이므로, 현재 차트 시간은 audio_pos + 곡 시작 대기 시간(music_offset) 이어야 함
		# 하지만 audio_stream_player.gd에서 timer로 music_offset만큼 기다렸다가 play()를 하므로,
		# audio_pos가 0인 시점의 current_time은 이미 music_offset 이어야 함.
		# 오디오 스크립트의 GLOBAL_TIMING_OFFSET(0.6)도 고려해야 함.
		
		# 보다 단순하고 정확한 방식:
		# 오디오 재생 전까지는 delta로 누적하다가, 재생이 시작되면 오디오 위치를 기준으로 보정
		var target_time = audio_pos + 0.7 # GLOBAL_TIMING_OFFSET 보정 (judgment_time 일치)
		current_time = lerp(current_time, target_time, 0.1) # 급격한 튐 방지
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
			# 무작위 오프셋 진동 계산 (Perfect/Great 극적 손맛 연출)
			var offset_x = randf_range(-shake_intensity, shake_intensity)
			var offset_y = randf_range(-shake_intensity, shake_intensity)
			position = original_position + Vector2(offset_x, offset_y)



func start_chart() -> void:
	TargetNoteScript.reset_state() # 이전 판의 노트 잔재 제거
	chart_data = load_chart()
	if chart_data == null:
		push_error("Cannot start chart.")
		return

	# 이론상 최대 기본 점수(max_base_score) 계산 로직
	var total_max_score = 0
	for note in chart_data.get("notes", []):
		if not note is Dictionary:
			continue
		var note_type = str(note.get("type", "normal"))
		if note_type == "hold":
			var dur = float(note.get("duration", 3.0))
			var beat_div = int(note.get("beat_division", 4))
			var interval = (60.0 / bpm) * (4.0 / float(beat_div))
			var ticks = int(dur / interval)
			total_max_score += ticks * 10
		else:
			total_max_score += 100

	Global.max_base_score = max(total_max_score, 100)
	print("Max theoretical base score calculated: ", Global.max_base_score)
	
	# BPM 로드
	var res_path = MUSIC_BASE_PATH + Global.selected_music + "/Res.tres"
	if FileAccess.file_exists(res_path):
		var music_res = load(res_path)
		if music_res and "bpm" in music_res:
			bpm = float(music_res.bpm)
			print("BPM loaded: ", bpm)
		else:
			print("BPM property not found in Res.tres, using default 120.0")
	else:
		print("Res.tres not found, using default 120.0")
		
	current_time = Global.music_offset
	is_playing = true
	print("차트 로드 성공: ", chart_data.get("notes", []).size(), "개의 노트")


func load_chart() -> Variant:
	_ensure_selected_music()
	if Global.selected_music == "":
		push_error("No music is selected.")
		return null

	var path = MUSIC_BASE_PATH + Global.selected_music + "/chart.json"
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
	if not chart.has("notes") or not chart["notes"] is Array:
		chart["notes"] = []
	if not chart.has("events") or not chart["events"] is Array:
		chart["events"] = []

	# --- 추가된 부분: time 기준으로 자동 정렬 ---
	chart["notes"].sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	chart["events"].sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	# ----------------------------------------

	# 구버전 차트 좌표 보정 (offset_corrected 플래그가 없는 경우)
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


func _ensure_selected_music() -> void:
	if Global.selected_music != "":
		return

	if Global.music_titles.size() == 0:
		Global.music_titles = Global.get_folder_list(MUSIC_BASE_PATH)

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

	_spawn_note(mode, pos, start_pos)


func _spawn_hold_note(note_info: Dictionary) -> void:
	var duration = float(note_info.get("duration", 3.0))
	var beat_division = int(note_info.get("beat_division", 4)) # 기본 4박자(4분음표)
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
	var title = str(event_info.get("title", "Event Window"))
	var texture_path = str(event_info.get("texture_path", ""))
	if texture_path == "":
		texture_path = DEFAULT_WINDOW_TEXTURE

	var opacity = float(event_info.get("opacity", 1.0))

	var node: Node = null
	match event_type:
		# --- 기존 윈도우 이벤트 ---
		EVENT_STATIC_WINDOW:
			node = create_static_window(size, pos, duration, title, texture_path)
		EVENT_MOVING_LINEAR_WINDOW:
			node = create_moving_window(size, pos, target_pos, duration, MoveType.LINEAR, title, texture_path)
		EVENT_MOVING_SMOOTH_WINDOW:
			node = create_moving_window(size, pos, target_pos, duration, MoveType.SMOOTH, title, texture_path)
			
		# --- 신규 추가된 게임 내 이미지 이벤트 ---
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


func _spawn_note(mode: String, target_pos: Variant = null, start_pos: Variant = null) -> void:
	if target_spawner and target_spawner.has_method("spawn_node"):
		target_spawner.spawn_node(mode, target_pos, start_pos)


# ==========================================
# 기존 Window 기반 생성 함수들 (유지됨)
# ==========================================

func create_moving_window(size: Vector2i, start_rel_pos: Vector2i, target_rel_pos: Vector2i, move_duration: float, move_type: MoveType, title: String, img_path: String) -> Window:
	if _is_headless_display():
		return null

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


func _get_or_create_window(size: Vector2i, title: String, img_path: String) -> Window:
	if not texture_cache.has(img_path):
		texture_cache[img_path] = load(img_path)
	if texture_cache[img_path] == null:
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
			texture_rect.texture = texture_cache[img_path]
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
	texture_rect.texture = texture_cache[img_path]
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
# 신규 TextureRect (게임 내 노드) 스폰 함수들
# ==========================================

func create_moving_image(size: Vector2i, start_pos: Vector2i, target_pos: Vector2i, move_duration: float, move_type: MoveType, img_path: String) -> TextureRect:
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
	if not texture_cache.has(img_path):
		texture_cache[img_path] = load(img_path)
	if texture_cache[img_path] == null:
		push_error("Image texture not found: " + img_path)
		return null

	# 풀(Pool)에서 안 쓰고 있는 TextureRect 찾기
	for i in range(image_pool.size() - 1, -1, -1):
		var img_node = image_pool[i]
		if not is_instance_valid(img_node):
			image_pool.remove_at(i)
			continue
		if not img_node.visible:
			# [수정핵심 1] 텍스처를 넣고 이전 크기 기억을 강제로 지운 뒤 새 크기 덮어쓰기
			img_node.texture = texture_cache[img_path]
			img_node.reset_size() 
			img_node.size = size
			return img_node

	# 풀에 없으면 새로 생성하여 게임 화면(씬 트리)에 추가
	var new_image = TextureRect.new()
	
	# [수정핵심 2] expand_mode를 가장 먼저 설정해야 원본 크기로 튀는 것을 방지함
	new_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	new_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	new_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	new_image.texture = texture_cache[img_path]
	new_image.size = size # 오류를 일으키던 custom_minimum_size 속성 삭제

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


# 유틸리티 함수
func _is_headless_display() -> bool:
	return OS.has_feature("headless") or "--headless" in OS.get_cmdline_args() or "--headless-test" in OS.get_cmdline_user_args() or OS.get_environment("GODOT_HEADLESS_TEST") == "1"


# 곡 완료 여부 체크 함수
func _check_song_finished() -> void:
	if not is_playing:
		return

	# 차트의 모든 노트가 방출되었는지 확인
	if note_index < chart_data.get("notes", []).size():
		return

	# 현재 화면에 살아 있는 TargetNote 개수 확인
	var has_active_notes = false
	if target_spawner:
		for child in target_spawner.get_children():
			if "TargetNote" in child.name or child.has_method("activate_stationary"):
				has_active_notes = true
				break

	# 현재 화면에 살아 있는 HoldNote 개수 확인
	var hold_notes_active = false
	var note_layer = get_node_or_null("NoteLayer")
	if note_layer:
		for child in note_layer.get_children():
			if "HoldNote" in child.name or child.has_method("_is_holding"):
				hold_notes_active = true
				break

	if not has_active_notes and not hold_notes_active:
		# 마지막 노트의 릴리즈 이후 지연 시간 확보
		var last_note_time = 0.0
		var notes = chart_data.get("notes", [])
		if notes.size() > 0:
			var last_note = notes[-1]
			last_note_time = float(last_note.get("time", 0.0)) + float(last_note.get("duration", 2.0))

		# 오디오 스트림이 멈췄거나 마지막 노트 플레이 시간이 충분히 흘렀을 때 종료
		var audio_stopped = Global.audio_player != null and not Global.audio_player.playing
		if (audio_stopped and current_time > last_note_time) or (current_time > last_note_time + 3.0):
			is_playing = false
			_transition_to_result_scene()


# 결과 화면 씬 전환
func _transition_to_result_scene() -> void:
	print("Song complete! Transitioning to result scene...")
	# SceneTransition 전역 자동로드를 이용해 자연스러운 페이드 전환
	var result_path = "res://scenes/menu/result_scene.tscn"
	SceneTransition.transition_to_scene(result_path)
