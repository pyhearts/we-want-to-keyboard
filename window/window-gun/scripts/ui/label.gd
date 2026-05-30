extends Label

@export var max_width: float = 300.0   # UI 박스의 고정 가로 폭
@export var scroll_speed: float = 60.0 # 스크롤 속도
@export var wait_time: float = 1.5    # 처음 시작할 때와 한 바퀴 돌았을 때 멈춤 시간

var is_scrolling: bool = false
var text_width: float = 0.0
var timer: float = 0.0
var state: int = 0 # 0: 대기, 1: 스크롤, 2: 루프 후 재대기

# 곡명이 바뀔 때마다 이 함수를 호출해줍니다.
func set_song_title(title_text: String):
	text = title_text
	position.x = 0  # 위치 초기화
	is_scrolling = false
	state = 0
	timer = 0.0
	
	# 1. 현재 설정된 폰트와 글자 크기를 기준으로 실제 가로 길이(픽셀)를 계산
	var font = get_theme_font("font")
	var font_size = get_theme_font_size("font_size")
	text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	# 2. 글자 길이가 UI 가로폭보다 길 때만 스크롤 활성화
	if text_width > max_width:
		is_scrolling = true

func _process(delta):
	if not is_scrolling:
		return
		
	match state:
		0: # 출발 전 잠깐 대기 (플레이어가 제목을 읽을 시간 확보)
			timer += delta
			if timer >= wait_time:
				state = 1
				timer = 0.0
				
		1: # 왼쪽으로 스크롤
			position.x -= scroll_speed * delta
			
			# 글자가 완전히 왼쪽으로 다 지나갔다면 (여백 50픽셀 추가)
			if position.x <= -(text_width - max_width + 50):
				state = 2
				timer = 0.0
				
		2: # 끝까지 간 후 잠깐 대기했다가 다시 처음으로 리셋
			timer += delta
			if timer >= wait_time:
				position.x = 0
				state = 0
				timer = 0.0
