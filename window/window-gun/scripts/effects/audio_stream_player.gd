extends AudioStreamPlayer

# 노래 파일이 들어있는 기본 경로
const MUSIC_BASE_PATH = "res://assets/musics/"

# 불러온 오프셋 값을 저장할 변수
var music_offset: float = 0.0

func _ready() -> void:
	# 1. 곡이 선택되어 있는지 확인
	if Global.selected_music == "":
		return

	# 2. Res.tres 파일에서 오프셋 정보 가져오기
	var res_path = MUSIC_BASE_PATH + Global.selected_music + "/Res.tres"
	var music_res = load(res_path)
	
	if music_res and "offset" in music_res:
		music_offset = music_res.offset + 0.7
		print("설정된 오프셋: ", music_offset, "초")
	else:
		music_offset = 0.0
		print("리소스를 찾을 수 없거나 offset 정보가 없어 0초로 설정합니다.")

	# 3. [핵심] 오프셋만큼 기다리기
	if music_offset > 0:
		print(music_offset, "초 대기 시작...")
		await get_tree().create_timer(music_offset).timeout
	
	# 4. 대기 완료 후 음악 재생 호출
	play_selected_music(Global.selected_music)


## 특정 곡 이름을 받아 파일을 로드하고 바로 재생하는 함수
func play_selected_music(music_name: String) -> void:
	# 오디오 파일 경로 조합
	var audio_path = MUSIC_BASE_PATH + music_name + "/" + music_name + ".mp3"
	var song = load(audio_path)
	
	if song:
		self.stream = song
		self.play()
		print("음악 재생 시작: ", audio_path)
	else:
		push_error("노래 파일을 찾을 수 없습니다: " + audio_path)

## 재생을 멈추는 함수
func stop_music() -> void:
	if self.playing:
		self.stop()
