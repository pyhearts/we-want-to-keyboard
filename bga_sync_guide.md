# 고도 엔진(Godot 4.x) 리듬 게임 BGA(배경 비디오) 구현 및 싱크(Sync) 가이드

이 가이드는 고도 엔진 4.x(Godot 4.x)를 사용하여 리듬 게임을 개발할 때, 게임 내 배경 애니메이션(BGA, Background Animation)을 안정적이고 프레임 단위로 정확하게(Frame-accurate) 싱크 및 재생하기 위한 구조적 가이드라인과 최적화 팁을 제공합니다.

---

## 1. VideoStreamPlayer 설정 및 오디오/비디오 에셋 포맷 추천

고도 엔진은 엔진의 오픈 소스 라이선스 정책 및 특성상 H.264/H.265 등 특허에 걸려 있는 독점 코덱을 기본 제공하지 않습니다.

### 팩트 시트 및 권장 포맷
* **기본 지원 포맷:** **Ogg Theora (`.ogv`)**
  * 고도 엔진이 기본(Out-of-the-box)으로 디코딩을 지원하는 유일한 비디오 포맷입니다.
* **오디오 트랙 제거 필수의 법칙:**
  * 리듬 게임은 음악의 싱크가 핵심이므로, 배경 영상의 소리를 직접 재생하지 않고 고품질 무압축 `.wav` 또는 `.ogg` 파일을 `AudioStreamPlayer`로 개별 재생해야 합니다.
  * 따라서, 비디오 파일 내부의 **오디오 트랙은 인코딩 단계에서 완전히 제거(Strip)** 해야 합니다. 오디오 스트림이 비디오에 포함되어 있으면 쓸데없는 CPU 자원이 오디오 디코딩에 소모되어 게임 플레이 중 미세한 렉(Stutter)을 유발합니다.

### 추천 FFmpeg 인코딩 명령어
고해상도 비디오를 고도 엔진에 맞는 최적의 `.ogv` 포맷으로 변환하기 위해 다음 FFmpeg 명령어를 사용하는 것을 권장합니다.

```bash
# 비디오는 Ogg Theora 코덱으로 인코딩하고, 오디오 트랙은 완전히 제거(-an)
ffmpeg -i input_bga.mp4 -c:v libtheora -q:v 6 -an output_bga.ogv
```
* `-q:v 6`: 비디오 화질 설정 (0 ~ 10 사이, 6~7 정도가 품질과 용량의 밸런스가 좋습니다).
* `-an`: 오디오(Audio)를 완전히 제거하여 디코딩 오버헤드를 제로(0)로 만듭니다.

### VideoStreamPlayer 기본 속성 구성
Godot 에디터 인스펙터나 스크립트에서 다음과 같이 노드를 설정합니다.
1. **`Volume Db`**: `-80.0` (음소거 상태 확인)
2. **`Audio Track`**: `-1` 또는 변경 금지
3. **`Loop`**: 곡의 성격에 맞춰 설정 (대개 BGA는 단판 재생이므로 비활성화)
4. **`Expand`**: `true` (배경 화면에 맞게 늘리기)
5. **`Anchor`**: Layout Preset을 `Full Rect`로 지정하여 화면 전체를 덮도록 설정

---

## 2. 완벽한 싱크(Sync) 제어 로직

리듬 게임에서 가장 치명적인 문제는 **음악(Audio Server)과 비디오 간의 미세한 싱크 어긋남**입니다. 

### ⚠️ 고도 4.x의 핵심 제한 사항: VideoStreamPlayer의 Seek 기능 부재
> [!WARNING]  
> Godot 4.x의 기본 `VideoStreamPlayer`는 내부 구조상 재생 중 **`stream_position`을 변경하는 임의 탐색(Seeking)이 지원되지 않거나 매우 불안정**합니다. 즉, 프레임이 밀렸다고 해서 비디오의 시간을 강제로 뒤로 당기거나 앞으로 미는 방식(`stream_position = audio_time` 등)은 제대로 작동하지 않거나 비디오 화면을 심하게 버벅거리게 만듭니다.

따라서, 이를 해결하기 위해 두 가지 전략을 사용합니다.
* **전략 A (기본 비디오 플레이어 방식):** 음악이 "실제 스피커로 출력되기 시작하는 타이밍"을 정확히 감지하여 비디오를 정밀하게 동시에 **출발(Start-up Sync)** 시키고 일시정지 상태를 공유합니다.
* **전략 B (정석 리듬 게임 방식 - 이미지 시퀀스):** 비디오를 프레임 단위의 이미지 파일(PNG/WebP)로 변환해 두고, 오디오 시간 기준으로 정확한 프레임을 실시간 계산하여 출력합니다.

---

### [방법 A] VideoStreamPlayer 출발 제어 및 오프셋 동기화 방식

이 방식은 기존 프로젝트의 `game_controller.gd`에 탑재되어 있는 `current_time` 및 `Global.audio_player` 구조와 완벽히 호환되도록 구성되었습니다.

```gdscript
# ==============================================================================
# BgaVideoController.gd
# 기존 game_controller.gd에 결합하거나, 자식 노드로 추가하여 사용할 수 있습니다.
# ==============================================================================
extends Control
class_name BgaVideoController

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var static_fallback: TextureRect = $StaticFallback # 저사양 기기용 정적 이미지

var is_bga_enabled: bool = true
var bga_started: bool = false

func _ready() -> void:
	# 글로벌 설정에서 BGA 활성화 여부 확인 (옵션 메뉴 연동 가능)
	is_bga_enabled = Global.get("enable_bga", true)
	
	if not is_bga_enabled:
		video_player.visible = false
		static_fallback.visible = true
		return
		
	video_player.visible = true
	static_fallback.visible = false
	
	# 비디오 플레이어의 자체 디코딩 사운드 제거
	video_player.volume_db = -80.0
	video_player.audio_track = -1

## BGA 비디오 설정 및 대기
func setup_bga(video_path: String) -> void:
	if not is_bga_enabled:
		return
		
	# 인게임 렉 유발을 막기 위해 곡 시작 단계에서 리소스를 사전에 명시적 로드
	var video_res = load(video_path)
	if video_res:
		video_player.stream = video_res
		bga_started = false
		video_player.stop() # 시작 대기
	else:
		push_error("BGA 파일을 로드할 수 없습니다: " + video_path)

## 매 프레임 동기화 감지 (game_controller.gd의 _process 에서 호출 권장)
func process_sync(current_game_time: float) -> void:
	if not is_bga_enabled or not video_player.stream:
		return

	# 1. 완벽한 오디오 시작 동기화 (Start-up Sync)
	# AudioStreamPlayer가 재생되기 전까지는 비디오를 시작하지 않고 대기합니다.
	if not bga_started:
		if Global.audio_player and Global.audio_player.playing:
			var audio_pos = Global.audio_player.get_playback_position()
			# 오디오가 미세하게라도 진행되기 시작했을 때 비디오 출발
			if audio_pos > 0.0:
				video_player.play()
				bga_started = true
		return

	# 2. 일시정지 상태 동기화
	if Global.audio_player:
		# 오디오 일시정지 상태와 비디오 일시정지 상태를 실시간 매칭
		if Global.audio_player.stream_paused != video_player.paused:
			video_player.paused = Global.audio_player.stream_paused
			
	# 3. 누적 드리프트 감지 (참고용)
	# Seek가 지원되지 않으므로 강제 이동은 불가능하지만, 
	# 싱크 어긋남이 극심할 경우(예: 백그라운드 전환 등) 멈췄다 재정렬하는 안전장치
	var drift = abs(video_player.stream_position - current_game_time)
	if drift > 0.3: # 300ms 이상 심하게 밀렸을 때만 재부팅 싱크
		push_warning("BGA 시간 오차 발생(드리프트: %fs). 재정렬을 시도합니다." % drift)
		# 강제 동기화 우회책: 멈추고 현재 시점에 맞춰 재시작 (렉 발생 가능성 있음)
		video_player.stop()
		video_player.play()
```

---

### [방법 B] 리듬게임의 정석: 프레임 단위 완벽 동기화 (Image Sequence) 방식

> [!TIP]  
> 이 방식은 오디오가 밀리든, 게임 프레임이 떨어지든 **무조건 음악 비트에 100% 칼같이 연동되는 최강의 비주얼 싱크**를 보장합니다. 비디오 코덱 디코딩 부하가 없으므로 저사양 기기 최적화에도 극히 유리합니다.

* **동작 원리:** 영상을 `BGA_0001.webp`, `BGA_0002.webp` 등의 프레임 이미지 폴더로 저장한 후, 오디오 서버의 정밀 시간인 `current_time`에 맞춰 정량 계산된 특정 프레임을 `TextureRect`에 곧바로 꽂아주는 방식입니다.

```gdscript
# ==============================================================================
# FrameSyncBga.gd
# 오디오 마스터 클록에 완전히 바인딩된 프레임 이미지 시퀀스 재생기
# ==============================================================================
extends TextureRect
class_name FrameSyncBga

@export var bga_fps: float = 30.0 # BGA 영상 프레임 레이트 (기본 30fps 권장)
@export var frames_folder: String = "res://assets/bga/frames/"
@export var file_prefix: String = "frame_"
@export var total_frames: int = 0

var frame_textures: Array[Texture2D] = []
var is_bga_enabled: bool = true

## 스테이지 진입 시 사전 로드 (로딩 스크린 추천)
func preload_bga_frames(folder_path: String, prefix: String, count: int, fps: float) -> void:
	frames_folder = folder_path
	file_prefix = prefix
	total_frames = count
	bga_fps = fps
	frame_textures.clear()
	
	# RAM/VRAM 적재 Stutter 방지를 위해 모든 프레임을 한 번에 캐시
	for i in range(total_frames):
		var path = "%s%s%04d.webp" % [frames_folder, file_prefix, i] # 예: frame_0000.webp
		if ResourceLoader.exists(path):
			frame_textures.append(load(path))
		else:
			push_error("BGA 프레임 이미지 누락: " + path)

## game_controller.gd의 _process(delta)에서 직접 호출받아 싱크 처리
func update_bga_sync(current_game_time: float) -> void:
	if not is_bga_enabled or frame_textures.is_empty():
		return
		
	# 1. 오디오 정밀 시간 기준 타겟 프레임 계산 (수학적 맵핑)
	var target_frame = int(current_game_time * bga_fps)
	
	# 2. 범위 예외 처리 및 루프 처리
	if target_frame >= 0 and target_frame < frame_textures.size():
		texture = frame_textures[target_frame]
	elif frame_textures.size() > 0:
		# 곡 종료 전까지 반복(Loop) 재생해야 하는 배경일 경우
		texture = frame_textures[target_frame % frame_textures.size()]
```

---

## 3. 저사양 기기에서의 성능 최적화(Lag 방지) 팁

리듬 게임은 단 1프레임의 인풋 렉이나 화면 버벅임도 유저 경험을 파괴하는 요인이 됩니다. BGA가 활성화되어도 일정한 60FPS(혹은 그 이상)를 방어하기 위한 최적화 비책들입니다.

### ① 전역 BGA 온/오프 옵션 제공 (필수)
* 모든 상용 리듬 게임(DJMAX, EZ2ON, osu! 등)과 동일하게 옵션 설정에서 BGA를 활성화(`enable_bga = true`)하거나 꺼서 검은색 단색 배경 또는 심플한 일러스트(`static_fallback`)로 대체하는 옵션을 구현해 주십시오. 이는 저사양 모바일/내장 그래픽 환경에서 60FPS 고정을 만드는 최고의 해결책입니다.

### ② 해상도 및 비트레이트 하향 다이어트
* 인게임 BGA는 플레이 도중 판정선과 낙하하는 노트들에 가려져 유저가 세세한 화질 화소 디테일을 눈치채기 어렵습니다.
  * **해상도:** FHD(1080p) 대신 **HD(720p, 1280x720)** 또는 **qHD(540p, 960x540)**로 과감히 낮춰서 인코딩하십시오. VRAM 절약 및 디코딩 성능 향상이 엄청납니다.
  * **비트레이트:** Ogg Theora 품질 계수를 낮추어 용량을 줄이십시오 (`-q:v 4~5` 수준으로 타협).

### ③ WebP 포맷 적극 활용 (시퀀스 재생 시)
* 정석 이미지 시퀀스 재생 방식(방법 B)을 채택할 경우, 프레임 이미지는 PNG가 아닌 **Lossy(손실 압축) WebP** 포맷을 강하게 추천합니다.
  * WebP는 PNG 대비 최대 70~80%의 용량 다이어트가 가능하면서도 JPG보다 우수한 아티팩트 보정력을 보여 고도 엔진이 로딩할 때 메모리(RAM)와 대역폭(I/O) 부담을 대폭 감소시킵니다.
  * WebP 시퀀스 변환 명령어 예시: `ffmpeg -i input.mp4 -q:v 70 -c:v webp frames/frame_%04d.webp`

### ④ 동적 로딩 금지 (Pre-load & Caching)
* 플레이 도중에 로컬 드라이브에서 비디오 스트림을 최초로 긁어오거나 이미지 프레임들을 런타임에 실시간으로 디스크에서 `load()`해 오면, I/O 스레드가 병목을 일으키며 게임이 뚝뚝 끊기는 프레임 드랍(Spike) 현상이 발생합니다.
* 반드시 노래를 선택한 뒤 로딩 화면(Loading Screen)에서 BGA 리소스들을 `load()`하여 캐시(Caching)해 둔 상태에서 인게임 씬에 진입하도록 설계하십시오.
