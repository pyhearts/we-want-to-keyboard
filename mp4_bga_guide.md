# 고도 엔진(Godot 4.x) 로컬 .mp4 파일을 BGA로 직접 재생하는 방법

유튜브 등의 연동을 거치지 않고, 프로젝트 내의 로컬 **`.mp4`** 비디오 파일(H.264/AAC 코덱)을 `VideoStreamPlayer`를 통해 직접 불러와 인게임 BGA로 재생하기 위한 가이드라인입니다.

---

## ⚠️ 고도 엔진의 기본적 한계 및 라이선스 이슈
고도 엔진은 오픈 소스 정책 및 엔진 무료 배포 특성상 특허 침해 우려가 있는 **H.264 / H.265 (MP4)** 코덱을 네이티브 코어에 탑재할 수 없습니다. 따라서 기본 상태의 고도 엔진에서 `.mp4` 파일을 불러오면 임포트 에러가 나거나 재생되지 않습니다.

로컬 `.mp4` 파일을 재생하려면 다음 **두 가지 해결책** 중 하나를 선택해야 합니다.

---

## 해결책 1. FFmpeg GDExtension 플러그인 장착 (가장 확실한 MP4 재생법)

외부 C++ 라이브러리를 동적 링킹하여 고도 엔진에 MP4 재생 능력을 부여하는 방식입니다. 플러그인을 설치하면, 기본 `VideoStreamPlayer` 노드가 추가적인 변환 없이 `.mp4` 확장자를 가진 고품질 비디오를 인게임에서 직접 해독하여 재생할 수 있게 됩니다.

### 🛠️ 구현 단계

1. **플러그인 다운로드:**
   * Godot 4.x용 대표적 FFmpeg 플러그인인 **[EIRTeam.FFmpeg (GitHub)](https://github.com/EIRTeam/EIRTeam.FFmpeg)** 또는 에셋 라이브러리에서 `FFmpeg Video Decoder` 관련 GDExtension 플러그인을 다운로드합니다.
2. **프로젝트 설치:**
   * 다운로드한 파일들의 압축을 풀어 `addons/` 디렉터리에 넣거나 프로젝트 루트에 플러그인 지침에 맞게 배치합니다.
   * 고도 에디터를 재시작하여 **프로젝트 설정 > 플러그인(Plugins)** 탭에서 해당 플러그인을 **[활성화(Enable)]** 상태로 체크합니다.
3. **인게임 스크립트 작성:**
   * 플러그인이 성공적으로 마운트되면 GDScript 코드는 매우 단순해집니다.

```gdscript
# ==============================================================================
# Mp4BgaPlayer.gd - 플러그인을 통해 로컬 .mp4 파일을 직접 로드해 재생
# ==============================================================================
extends Control
class_name Mp4BgaPlayer

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

func play_mp4_bga(mp4_relative_path: String) -> void:
	# 플러그인이 적용되면 .mp4 파일도 표준 Resource처럼 load()할 수 있습니다.
	var video_stream = load(mp4_relative_path)
	
	if video_stream:
		video_player.stream = video_stream
		video_player.volume_db = -80.0 # BGA 사운드는 제거 (오디오는 AudioStreamPlayer 개별 재생 권장)
		video_player.audio_track = -1
		video_player.play()
		print("MP4 BGA 재생 시작: ", mp4_relative_path)
	else:
		push_error("MP4 파일을 로드할 수 없습니다: " + mp4_relative_path)
```

---

## 해결책 2. 원터치 로컬 배치(Batch) 자동 변환 파이프라인 구성

> [!TIP]
> **추천 이유:** 외부 C++ 바이너리(GDExtension)를 늘리면 게임 실행 파일 배포 용량이 대폭 증가하고, 모바일/웹 빌드 등 멀티 플랫폼으로 패키징할 때 플랫폼마다 C++ 라이브러리를 맞춰 빌드해야 하는 복잡한 지옥이 펼쳐집니다. 
> 
> 개발 시에는 편하게 `.mp4`를 작업 폴더에 넣고, **빌드(Export)나 로딩 시점에 자동으로 1회만 `.ogv`로 바꾸어 재생**하는 변환 파이프라인을 구축하는 것이 성능과 크로스플랫폼 배포 관점에서 훨씬 이득입니다.

### 💻 동적 변환 스크립트 작성 (`mp4_auto_converter.gd`)
게임 플레이어가 커스텀 `.mp4` 파일을 곡 폴더에 직접 넣었을 때, 첫 실행 시점에 딱 1번 자동으로 `.ogv`로 인코딩 캐싱하여 재생하도록 설계하는 스크립트 예제입니다.

```gdscript
# ==============================================================================
# Mp4AutoConverter.gd
# 유저가 mp4를 넣어두었을 때 최초 실행 시 1회만 무음 .ogv로 변환해 캐시하는 노드
# ==============================================================================
extends Node
class_name Mp4AutoConverter

signal conversion_finished(cached_ogv_path: String)
signal conversion_failed(error_msg: String)

## 로컬 mp4 주소를 넣으면 변환 처리 후 변환된 ogv 경로 반환
func convert_mp4_to_ogv_if_needed(mp4_path: String, output_dir: String) -> void:
	var global_mp4 = ProjectSettings.globalize_path(mp4_path)
	var file_name = mp4_path.get_file().get_basename()
	var cache_ogv_path = output_dir + "/" + file_name + ".ogv"
	var global_ogv = ProjectSettings.globalize_path(cache_ogv_path)
	
	# 1. 이미 인코딩 완료된 캐시 파일이 있다면 변환 생략
	if FileAccess.file_exists(cache_ogv_path):
		emit_signal("conversion_finished", cache_ogv_path)
		return
		
	# 2. 로컬 컴퓨터의 FFmpeg 명령어 구동
	# -y (덮어쓰기), -an (음소거), -c:v libtheora (테오라 코덱)
	var ffmpeg_args = [
		"-y",
		"-i", global_mp4,
		"-c:v", "libtheora",
		"-q:v", "6",
		"-an",
		global_ogv
	]
	
	# 백그라운드 스레드에서 비동기 변환 처리를 할 수 있게 스레드 실행을 권장합니다.
	var output = []
	var exit_code = OS.execute("ffmpeg", ffmpeg_args, output, true)
	
	if exit_code == 0:
		emit_signal("conversion_finished", cache_ogv_path)
	else:
		emit_signal("conversion_failed", "FFmpeg 변환 오류 발생.")
```

---

## 🚨 프로젝트 내보내기(Export) 시 필수 점검 설정

고도 엔진은 기본적으로 자신이 리소스로 인식하지 않는 포맷(예: 외부 플러그인이 깔리기 전의 `.mp4` 파일)은 게임 패키지 빌드(`.pck` 파일) 시 강제로 제외시킵니다. 

따라서 빌드된 게임을 배포했을 때 MP4가 정상적으로 나오게 하려면 **반드시** 내보내기(Export) 설정을 세팅해야 합니다.

1. 고도 에디터 좌측 상단의 **[프로젝트(Project)] -> [내보내기(Export)]** 메뉴로 진입합니다.
2. 사용 중인 빌드 프리셋(예: Windows Desktop)을 클릭합니다.
3. 상단의 **[리소스(Resources)]** 탭을 클릭합니다.
4. **"리소스가 아닌 파일/폴더를 내보내기 위한 필터(Filters to export non-resource files/folders)"** 입력란을 찾습니다.
5. 여기에 **`*.mp4`** (또는 하위 폴더 전체 포함 시 `*.mp4, *.mkv`)를 정확히 입력해 줍니다.
   * 이렇게 명시해 두어야 고도의 리소스 컴파일러가 배포용 패키지를 만들 때 MP4 비디오 소스 파일을 버리지 않고 최종 `.pck` 리소스 파일 속에 포함시켜 줍니다.
