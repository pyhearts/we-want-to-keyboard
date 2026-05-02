extends VBoxContainer

@export var btn_up: BaseButton 
@export var btn_down: BaseButton 

@export var scroll_step: float = 100.0 # 한 칸 스크롤 시 이동 거리
@export var scroll_duration: float = 0.2 # 스크롤 애니메이션 시간

var current_index: int = 0
var base_y: float = 0.0
var scroll_tween: Tween

func _ready() -> void:
	base_y = position.y
	
	if Global.music_titles.size() == 0:
		return
		
	var template_button = get_child(0)
	
	# 1. 화면에 보이도록 무조건 딱 5개의 버튼만 복제하여 채웁니다.
	while get_child_count() < 5:
		var new_button = template_button.duplicate()
		add_child(new_button)

	# Up/Down 버튼 시그널 연결
	if btn_up: btn_up.pressed.connect(_on_up_pressed)
	if btn_down: btn_down.pressed.connect(_on_down_pressed)
	
	update_ui()

# 배열 인덱스를 계산하는 함수 (루프 및 반복 처리)
func get_title(offset: int) -> String:
	var n = Global.music_titles.size()
	# 현재 선택된 곡에서 offset만큼 떨어진 곡을 찾습니다.
	var idx = (current_index + offset) % n
	
	# 음수 인덱스 처리 (리스트의 처음에서 뒤로 넘어갈 때)
	if idx < 0:
		idx += n
		
	return Global.music_titles[idx]

# 5개 버튼의 텍스트와 강조 효과를 업데이트하는 함수
func update_ui() -> void:
	var buttons = get_children()
	
	# 딱 5개의 버튼만 조작합니다.
	for i in range(5):
		# i가 0, 1, 2, 3, 4 일 때 -> offset은 -2, -1, 0, 1, 2 가 됩니다.
		var offset = i - 2 
		var title = get_title(offset)
		buttons[i].label.text = get_title(offset)
		
		# 2. 가운데(3번째, 인덱스 2) 버튼 강조
		if i == 2: 
			buttons[i].modulate = Color(1, 1, 1, 1) # 선택됨 (흰색)
			Global.selected_music = title
		else:
			buttons[i].modulate = Color(0.779, 0.779, 0.779, 1.0) # 선택 안 됨 (어둡게)

	# 가운데 선택된 곡을 전역 변수에 저장 (게임 씬에서 활용)
	# Global.selected_music = get_title(0)

func _on_up_pressed() -> void:
	# 애니메이션 도중 중복 입력 방지
	if scroll_tween and scroll_tween.is_valid() and scroll_tween.is_running(): return
	if Global.music_titles.size() == 0: return

	# 이전 곡으로 인덱스 이동
	var n = Global.music_titles.size()
	current_index = (current_index - 1) % n
	if current_index < 0: current_index += n

	# 텍스트 교체
	update_ui()

	# 3. 트릭: UI를 순간적으로 한 칸 위로 보낸 뒤, 원래 위치로 부드럽게 내려옵니다.
	position.y = base_y - scroll_step
	animate_scroll()

func _on_down_pressed() -> void:
	if scroll_tween and scroll_tween.is_valid() and scroll_tween.is_running(): return
	if Global.music_titles.size() == 0: return

	# 다음 곡으로 인덱스 이동
	current_index = (current_index + 1) % Global.music_titles.size()

	# 텍스트 교체
	update_ui()

	# 3. 트릭: UI를 순간적으로 한 칸 아래로 보낸 뒤, 원래 위치로 부드럽게 올라갑니다.
	position.y = base_y + scroll_step
	animate_scroll()

func animate_scroll() -> void:
	scroll_tween = create_tween()
	scroll_tween.set_trans(Tween.TRANS_CUBIC)
	scroll_tween.set_ease(Tween.EASE_OUT)
	scroll_tween.tween_property(self, "position:y", base_y, scroll_duration)
