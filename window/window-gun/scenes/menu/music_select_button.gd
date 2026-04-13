extends Control

func _ready() -> void:
	# 1. 씬에 있는 원본 버튼을 틀(Template)로 가져옵니다.
	var template_button = $MusicSelectButton
	var music_titles = Global.music_titles
	
	# 2. 원본 버튼은 게임 화면에 보이지 않게 숨깁니다.
	template_button.hide()
	
	# 3. 배열의 크기만큼 반복합니다. (i는 0, 1, 2... 인덱스 번호)
	for i in range(music_titles.size()):
		# 곡 이름 가져오기
		var title = music_titles[i]
		
		# 4. 원본을 복제하여 새로운 버튼 생성
		var new_button = template_button.duplicate()
		
		# 5. 숨겨져 있던 복사본을 보이게 설정하고, 데이터 입력
		new_button.show()
		new_button.text_change(title) # 복사된 새 버튼의 텍스트 변경
		
		# 6. 위치 계산: i값에 비례하여 Y축으로 170씩 간격을 벌림
		# (예: 첫 번째는 0, 두 번째는 170, 세 번째는 340...)
		new_button.position = template_button.position + Vector2(0, 170 * i)
		
		# 7. 씬에 자식으로 추가
		add_child(new_button)
