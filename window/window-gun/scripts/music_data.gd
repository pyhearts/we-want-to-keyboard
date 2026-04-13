extends Resource

class_name MusicData # class_name을 지정해야 에디터에서 새로운 리소스로 인식합니다.

# @export를 붙이면 Godot 인스펙터(우측 창)에서 직접 값을 수정할 수 있습니다.
@export var id: String = "song_001"
@export var title: String = "Unknown Title"
@export var composer: String = "Unknown Composer"
@export var bpm: int = 120
@export var offset: float = 0.0

# 오디오 파일과 이미지 파일을 직접 연결할 수 있습니다! (JSON과의 가장 큰 차이점)
@export var audio_stream: AudioStream
@export var jacket_image: Texture2D
