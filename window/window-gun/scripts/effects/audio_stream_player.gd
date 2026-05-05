extends AudioStreamPlayer

# 노래 파일이 들어있는 기본 경로 (프로젝트 구조에 맞게 수정하세요)
const MUSIC_BASE_PATH = "res://assets/musics/"

func _ready() -> void:
	# 예시: Global 변수에 저장된 선택된 곡을 바로 재생하고 싶을 때
	if Global.selected_music != "":
		play_selected_music(Global.selected_music)

## 특정 곡 이름을 받아 파일을 로드하고 재생하는 함수
func play_selected_music(music_name: String) -> void:
	# 1. 파일 경로 조합 (곡 이름 폴더 안에 music.mp3가 있다고 가정)
	# 확장자는 .mp3, .ogg, .wav 등 실제 파일에 맞춰주세요.
	var path = MUSIC_BASE_PATH + music_name + "/" + Global.selected_music + ".mp3"
	
	# 2. 리소스 로드
	var song = load(path)
	
	if song:
		# 3. 오디오 스트림 할당 및 재생
		self.stream = song
		self.play()
		print("재생 시작: ", path)
	else:
		push_error("노래 파일을 찾을 수 없습니다: " + path)

## 재생을 멈추는 함수
func stop_music() -> void:
	if self.playing:
		self.stop()
