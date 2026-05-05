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
	
	create_moving_window(Vector2i(200, 200), Vector2i(100, 100), Vector2i(800, 100), 3.0, MoveType.SMOOTH, "Smooth", "res://assets/image/ingame/과녁.png")
	create_moving_window(Vector2i(200, 200), Vector2i(100, 350), Vector2i(800, 350), 3.0, MoveType.LINEAR, "Linear", "res://assets/image/ingame/과녁.png")

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
	tween.tween_callback(window.hide)


func _animate_window_movement_linear(window: Window, target_rel_pos: Vector2i, duration: float) -> void:
	var absolute_target_pos = get_window().position + target_rel_pos
	var tween = window.create_tween()
	
	tween.tween_property(window, "position", absolute_target_pos, duration) \
		.set_trans(Tween.TRANS_LINEAR)
	
	# 💡 [최적화] 삭제(queue_free) 대신 숨김(hide) 처리하여 대기열로 돌려보냅니다.
	tween.tween_callback(window.hide)
