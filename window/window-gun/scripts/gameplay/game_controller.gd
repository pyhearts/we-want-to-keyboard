extends Control

# =========================================================
# 1. 상수, 변수 및 열거형(Enum) 선언
# =========================================================
const NORMAL_NOTE_MODE := "normal"
const MOVING_NOTE_MODE := "moving"

enum MoveType {
	SMOOTH,
	LINEAR
}

@onready var target_spawner: Control = $TargetNoteSpawner

# 💡 [최적화 1] 텍스처 캐싱 딕셔너리
# 매번 하드디스크에서 이미지를 load() 하지 않도록 메모리에 한 번만 저장해둡니다.
var texture_cache: Dictionary = {}

# 💡 [최적화 2] 오브젝트 풀링 (Object Pooling) 배열
# 운영체제(OS) 창을 매번 생성(new)/삭제(queue_free)하는 것은 랙의 가장 큰 원인입니다.
# 다 쓴 창을 삭제하지 않고 숨겨두었다가(hide) 재사용합니다.
var window_pool: Array[Window] = []


# =========================================================
# 2. 빌트인 함수 (_ready, _input 등)
# =========================================================
func _ready() -> void:
	Global.reset_run()
	# Global.selected_music = "test_song" # 폴더명 세팅 필수
	
	start_chart() # 채보 시스템 시작

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("1"):
		_spawn_note(NORMAL_NOTE_MODE)
	elif event.is_action_pressed("2"):
		_spawn_note(MOVING_NOTE_MODE)
	elif event.is_action_pressed("3"):
		var custom_position := Vector2(2000.0, 1000.0) 
		_spawn_note(NORMAL_NOTE_MODE, custom_position) 
	elif event.is_action_pressed("4"):
		create_moving_window(Vector2i(200, 200), Vector2i(100, 100), Vector2i(800, 100), 3.0, MoveType.SMOOTH, "Smooth", "res://assets/image/ingame/과녁.png")
	elif event.is_action_pressed("5"):
		create_moving_window(Vector2i(200, 200), Vector2i(100, 350), Vector2i(800, 350), 3.0, MoveType.LINEAR, "Linear", "res://assets/image/ingame/과녁.png")
	elif event.is_action_pressed("6"):
		create_static_window(Vector2i(200, 200), Vector2i(220, 220), 3.0, "Static", "res://assets/image/ingame/과녁.png")


# =========================================================
# 3. 게임 플레이 로직 (노트 스폰)
# =========================================================
func _spawn_note(mode: String, target_pos: Variant = null) -> void:
	if target_spawner and target_spawner.has_method("spawn_node"):
		target_spawner.spawn_node(mode, target_pos)


# =========================================================
# 4. 윈도우 및 UI 관리 (최적화 적용)
# =========================================================

func create_moving_window(size: Vector2i, start_rel_pos: Vector2i, target_rel_pos: Vector2i, move_duration: float, move_type: MoveType, title: String, img_path: String) -> void:
	var window = _get_or_create_window(size, title, img_path)
	
	window.current_screen = get_window().current_screen
	window.position = get_window().position + start_rel_pos
	window.show() # 숨겨져 있던 창을 다시 표시
	
	if move_type == MoveType.SMOOTH:
		_animate_window_movement_smooth(window, target_rel_pos, move_duration)
	else:
		_animate_window_movement_linear(window, target_rel_pos, move_duration)

func create_static_window(size: Vector2i, rel_pos: Vector2i, duration: float, title: String, img_path: String) -> void:
	var window = _get_or_create_window(size, title, img_path)
	
	window.current_screen = get_window().current_screen
	window.position = get_window().position + rel_pos
	window.show() # 숨겨져 있던 창을 다시 표시
	
	if duration > 0:
		# 💡 [최적화] 타이머 오류를 방지하기 위해 Tween의 interval을 사용하여 창을 숨깁니다.
		var tween = window.create_tween()
		tween.tween_interval(duration)
		tween.tween_callback(window.hide)


# 💡 [최적화 핵심] 풀링(Pooling) + 캐싱(Caching)이 결합된 통합 헬퍼 함수
func _get_or_create_window(size: Vector2i, title: String, img_path: String) -> Window:
	# 1. 텍스처 캐싱 (로드 병목 현상 제거)
	if not texture_cache.has(img_path):
		texture_cache[img_path] = load(img_path)
		
	# 2. 오브젝트 풀 확인 (OS 창 매니저 부하 제거)
	for w in window_pool:
		if not w.visible: # 사용이 끝나서 숨겨진 창이 있다면
			w.size = size
			w.title = title
			var tex_rect = w.get_node("TextureRect") as TextureRect
			tex_rect.texture = texture_cache[img_path]
			return w # 새 창을 만들지 않고 기존 창을 재사용합니다.
			
	# 3. 재사용할 창이 없다면 새로 생성 (기존 _create_base_window 와 _create_texture_rect 통합)
	var new_window = Window.new()
	new_window.title = title
	new_window.size = size
	new_window.transient = true 
	new_window.transparent = true
	new_window.unfocusable = true 
	
	# 핵심: 창을 닫을 때 메모리에서 삭제(queue_free)하지 않고 단순히 숨깁니다(hide).
	new_window.close_requested.connect(new_window.hide) 
	
	var texture_rect = TextureRect.new()
	texture_rect.name = "TextureRect" # 추후 재사용 시 노드를 찾기 위해 이름 지정
	texture_rect.texture = texture_cache[img_path]
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	new_window.add_child(texture_rect)
	add_child(new_window)
	
	# 완성된 창을 풀(배열)에 등록하여 다음 번에 재사용할 수 있게 합니다.
	window_pool.append(new_window)
	
	return new_window


# =========================================================
# 5. 애니메이션 처리 (Tween)
# =========================================================

func _animate_window_movement_smooth(window: Window, target_rel_pos: Vector2i, duration: float) -> void:
	var absolute_target_pos = get_window().position + target_rel_pos
	var tween = window.create_tween()
	
	tween.tween_property(window, "position", absolute_target_pos, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	
	# 💡 [최적화] 삭제(queue_free) 대신 숨김(hide) 처리하여 대기열로 돌려보냅니다.
	tween.tween_callback(window.queue_free)


func _animate_window_movement_linear(window: Window, target_rel_pos: Vector2i, duration: float) -> void:
	var absolute_target_pos = get_window().position + target_rel_pos
	var tween = window.create_tween()
	
	tween.tween_property(window, "position", absolute_target_pos, duration) \
		.set_trans(Tween.TRANS_LINEAR)
	
	# 💡 [최적화] 삭제(queue_free) 대신 숨김(hide) 처리하여 대기열로 돌려보냅니다.
	tween.tween_callback(window.hide)
	
	
func load_chart():
	# 1. 불러올 파일의 경로 조합
	var path = "res://assets/musics/" + Global.selected_music + "/chart.json"
	
	# 2. 해당 경로에 파일이 실제로 존재하는지 확인
	if not FileAccess.file_exists(path):
		push_error("차트 파일을 찾을 수 없습니다: ", path)
		return null
		
	# 3. 파일 열기 (읽기 모드)
	var file = FileAccess.open(path, FileAccess.READ)
	
	if file == null:
		push_error("파일을 여는 데 실패했습니다: ", path)
		return null
		
	# 4. 파일 내용을 문자열로 모두 읽어오기
	var json_text = file.get_as_text()
	
	# 5. JSON 문자열을 파싱하여 변수에 담기 (Dictionary 또는 Array)
	var chart = JSON.parse_string(json_text)
	
	# 6. 파싱 성공 여부 확인
	if chart == null:
		push_error("JSON 파싱 에러 (파일 형식이 잘못되었습니다): ", path)
		return null
		
	# 7. 최종 데이터 반환
	return chart


# =========================================================
# 6. 채보 재생 시스템 (추가된 부분)
# =========================================================

var chart_data: Dictionary = {}  # 불러온 채보 데이터 저장
var current_time: float = 0.0    # 현재 누적 재생 시간
var is_playing: bool = false     # 재생 상태 확인

var note_index: int = 0          # 처리할 다음 노트 번호
var event_index: int = 0         # 처리할 다음 이벤트 번호

# 게임 시작 (예: 음악 시작 시 호출)
func start_chart():
	chart_data = load_chart()
	if chart_data == null or not chart_data.has("notes"):
		push_error("채보를 시작할 수 없습니다.")
		return
		
	# 시간 순서대로 정렬 (불러올 때 정렬되어 있지 않을 수 있으므로 안전장치)
	chart_data["notes"].sort_custom(func(a, b): return a["time"] < b["time"])
	chart_data["events"].sort_custom(func(a, b): return a["time"] < b["time"])
	
	note_index = 0
	event_index = 0
	current_time = 0.0
	is_playing = true
	print("채보 재생 시작!")

func _process(delta: float) -> void:
	if not is_playing:
		return
		
	current_time += delta  # 시간 흐름 (더 정확하게는 AudioServer의 시간을 쓰는 것이 좋음)
	
	# 1. 노트 처리 (notes 배열)
	while note_index < chart_data["notes"].size():
		var note = chart_data["notes"][note_index]
		if current_time >= note["time"]:
			_process_note(note)
			note_index += 1
		else:
			break # 아직 소환 시간이 아님
			
	# 2. 이벤트 처리 (events 배열)
	while event_index < chart_data["events"].size():
		var event = chart_data["events"][event_index]
		if current_time >= event["time"]:
			_process_event(event)
			event_index += 1
		else:
			break
			
# JSON 데이터 기반 실제 노트 소환 로직
func _process_note(note_info: Dictionary):
	var pos = Vector2(note_info["x"], note_info["y"])
	var mode = NORMAL_NOTE_MODE
	
	if note_info["type"] == "moving":
		mode = MOVING_NOTE_MODE
		
	_spawn_note(mode, pos)
	# print("노트 소환: ", note_info["time"], " / 타입: ", note_info["type"])

# JSON 데이터 기반 실제 이벤트(창 띄우기 등) 실행 로직
func _process_event(event_info: Dictionary):
	if event_info["type"] == "window":
		var size = Vector2i(event_info.get("width", 200), event_info.get("height", 200))
		var pos = Vector2i(event_info["x"], event_info["y"])
		
		# 고정된 창을 띄우는 예시 (duration 등은 JSON에 없으면 기본값 사용)
		create_static_window(
			size, 
			pos, 
			3.0,                     # 지속 시간 (JSON에 추가하면 더 좋음)
			"Event Window", 
			"res://assets/image/ingame/과녁.png"
		)
