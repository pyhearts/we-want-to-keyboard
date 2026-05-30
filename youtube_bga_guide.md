# 고도 엔진(Godot 4.x) 유튜브 영상을 리듬 게임 BGA로 넣는 구현 가이드

유튜브(YouTube) 영상을 게임 내 배경 비디오(BGA)로 삽입하는 것은 개발 용량 단축 및 무한한 유저 커스텀 차트 생성을 위해 매우 매력적인 선택지입니다.

그러나 고도 엔진의 기본 `VideoStreamPlayer`는 로컬 `.ogv` 파일 재생만 지원하며, 유튜브 스트림의 실시간 디코딩 기능이 없습니다. 이를 구현하기 위한 **3가지 실무 아키텍처 방식**과 **가장 추천하는 비동기 다운로드/로컬 인코딩 파이프라인 구현법**을 제시합니다.

---

## 🗺️ 유튜브 BGA 구현을 위한 3가지 접근 방식 비교

| 아키텍처 방식 | 동작 메커니즘 | 장점 | 단점 및 리스크 | 추천 여부 |
| :--- | :--- | :--- | :--- | :---: |
| **A. 비동기 다운로드 및 로컬 변환 (Offline Cache)** | 유저가 유튜브 링크를 입력하면 게임이 백그라운드에서 `yt-dlp`와 `ffmpeg`를 사용해 영상을 조용히 다운로드 후 최적의 `.ogv` 파일로 로컬 캐싱합니다. | * **버퍼링 렉 제로 (0%):** 플레이 도중 인터넷 끊김, 버퍼링 지연이 전혀 없어 노트 싱크가 완벽히 보장됩니다.<br>* **안정성:** 유튜브 API 규격 변화에 런타임 게임 플레이가 전혀 영향을 받지 않습니다. | * 최초 곡을 시작하거나 등록할 때 다운로드/변환을 위한 대기 시간이 몇 십초간 발생합니다. | **강력 추천 (PC/스탠드얼론 환경의 업계 표준)** |
| **B. CEF / WebView 브라우저 임베딩** | **GodotCEF** GDExtension 등을 활용해 게임 화면 내부에 보이지 않는 크롬 웹브라우저(Chromium) 창을 임베딩하고 유튜브 플레이어 iframe 주소를 로드합니다. | * 실시간 스트리밍이 가능해 다운로드 대기 시간이 전혀 없습니다. | * **초고부하 렉:** 게임 내부에 웹브라우저를 띄우므로 메모리와 CPU 소모량이 극심하여 치명적인 노트 판정 렉을 유발합니다.<br>* 배포 용량이 크롬 빌드로 인해 수백 MB 증가합니다. | **비추천 (모바일/웹 전용 빌드에서만 제한적 권장)** |
| **C. yt-dlp 실시간 다이렉트 스트리밍** | 게임 시작 시 `yt-dlp`로 유튜브의 진짜 MP4/m3u8 비디오 스트림 주소만 런타임에 즉각 갈무리하고, 이를 스트리밍 가능한 외부 FFmpeg GDExtension 비디오 플레이어에 입력해 실시간 스트리밍합니다. | * 다운로드 대기 시간이 없고 로컬 용량을 차지하지 않습니다. | * 플레이 도중 버퍼링이 생기면 음악과 동영상의 싱크가 심각하게 뒤틀립니다.<br>* 유튜브가 보안 알고리즘을 변경하면 런타임에 주소 파싱 에러가 발생해 영상이 검게 나옵니다. | **부분 추천 (안정적 초고속 인터넷 보장 조건)** |

---

## 🛠️ [실무 구현] 방식 A: 백그라운드 비동기 다운로드 및 인코딩 구현

기존 메인 게임 스레드가 얼어붙지 않도록(Freeze 방지), 고도 4.x의 **`Thread`** 클래스를 사용하여 백그라운드에서 외부 명령어(`yt-dlp`, `ffmpeg`)를 호출하고 안전하게 콜백을 받는 비동기 스레드 다운로더의 풀스택 템플릿입니다.

### 1. 다운로드 전 필수 환경 구성
유저의 컴퓨터 환경 변수(PATH)에 `yt-dlp.exe`와 `ffmpeg.exe`가 설치되어 있거나, 게임 바이너리가 있는 실행 파일 폴더에 두 도구의 실행 파일이 동봉되어 있어야 합니다.
* [yt-dlp 다운로드](https://github.com/yt-dlp/yt-dlp)
* [FFmpeg 다운로드](https://ffmpeg.org/download.html)

---

### 2. GDScript 구현: 비동기 유튜브 수집기 (`YoutubeBgaDownloader.gd`)

```gdscript
# ==============================================================================
# YoutubeBgaDownloader.gd
# 게임 스레드를 멈추지 않고 백그라운드 스레드에서 yt-dlp & FFmpeg를 구동하는 노드
# ==============================================================================
extends Node
class_name YoutubeBgaDownloader

signal download_started
signal download_progress_msg(message: String)
signal download_completed(final_ogv_path: String)
signal download_failed(error_message: String)

var thread: Thread = Thread.new()
var is_running: bool = false

func _exit_tree() -> void:
	# 씬 소멸 시 스레드가 돌고 있다면 안전하게 스레드 종료를 대기
	if thread.is_started():
		thread.wait_to_finish()

## 외부에서 다운로드를 요청하는 진입점 함수
func request_youtube_bga(youtube_url: String, output_directory: String) -> void:
	if is_running:
		emit_signal("download_failed", "이미 다운로드 또는 인코딩 작업이 진행 중입니다.")
		return
		
	is_running = true
	emit_signal("download_started")
	emit_signal("download_progress_msg", "유튜브 다운로드 스레드 시작 중...")
	
	# 백그라운드 비동기 스레드로 다운로드 연산 토스
	var err = thread.start(_bg_thread_task.bind(youtube_url, output_directory))
	if err != OK:
		is_running = false
		emit_signal("download_failed", "백그라운드 스레드 생성에 실패했습니다.")

## 백그라운드 스레드 진입 루프 (Thread-safe 준수)
func _bg_thread_task(youtube_url: String, output_directory: String) -> void:
	# output_directory 경로 검증 및 생성
	if not DirAccess.dir_exists_absolute(output_directory):
		DirAccess.make_dir_recursive_absolute(output_directory)
		
	var temp_mp4_path = ProjectSettings.globalIZE_path(output_directory + "/temp_youtube.mp4")
	var final_ogv_path = ProjectSettings.globalize_path(output_directory + "/bga.ogv")
	
	# --------------------------------------------------------------------------
	# STEP 1: yt-dlp를 이용해 720p급 이하 mp4 영상 다운로드 (용량 최적화)
	# --------------------------------------------------------------------------
	call_deferred("emit_signal", "download_progress_msg", "유튜브 동영상 파일 수집 중 (yt-dlp)...")
	
	var ytdlp_args = [
		"-f", "bestvideo[height<=720]+bestaudio/best", # 최적의 720p 화질 선별
		"--merge-output-format", "mp4",
		"-o", temp_mp4_path,
		youtube_url
	]
	
	var ytdlp_output = []
	# OS.execute의 4번째 인자를 true로 주어야 스레드가 완료를 정상적으로 대기함
	var exit_code = OS.execute("yt-dlp", ytdlp_args, ytdlp_output, true)
	
	if exit_code != 0:
		_cleanup_temp_files(temp_mp4_path)
		call_deferred("_finalize_thread", "failed", "유튜브 수집(yt-dlp) 단계 실패. URL을 확인하거나 yt-dlp를 최신 버전으로 업데이트 해주세요.")
		return

	# --------------------------------------------------------------------------
	# STEP 2: FFmpeg를 사용해 로드율 최적화된 고도 전용 무음 .ogv 인코딩
	# --------------------------------------------------------------------------
	call_deferred("emit_signal", "download_progress_msg", "고도 엔진 최적화 비디오 변환 중 (FFmpeg)...")
	
	var ffmpeg_args = [
		"-y",                           # 덮어쓰기 허용
		"-i", temp_mp4_path,
		"-c:v", "libtheora",            # 고도 네이티브 비디오 디코더용 Theora 코덱
		"-q:v", "6",                    # 화질 지수 (0~10, 6 추천)
		"-an",                          # 오디오 채널 완전 제거 (디코딩 병목 제거 핵심)
		final_ogv_path
	]
	
	var ffmpeg_output = []
	exit_code = OS.execute("ffmpeg", ffmpeg_args, ffmpeg_output, true)
	
	# 변환 성공 유무와 관계없이 대용량 임시 mp4 제거
	_cleanup_temp_files(temp_mp4_path)
	
	if exit_code != 0:
		call_deferred("_finalize_thread", "failed", "고도 최적화 비디오(.ogv) 인코딩 변환 실패.")
	else:
		call_deferred("_finalize_thread", "completed", final_ogv_path)

## 임시 동영상 버퍼 삭제
func _cleanup_temp_files(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

## 스레드 종료 처리 및 메인 스레드 안전 복귀 (Thread-safe)
func _finalize_thread(status: String, data: String) -> void:
	if thread.is_started():
		thread.wait_to_finish() # 스레드 리소스 소거
		
	is_running = false
	
	if status == "completed":
		emit_signal("download_completed", data)
	else:
		emit_signal("download_failed", data)
```

---

### 3. 메인 Gameplay Controller (`game_controller.gd`) 등에서 연동하는 방법

```gdscript
# ==============================================================================
# 유튜브 변환기 컨트롤러 연동 예시
# ==============================================================================
extends Control

@onready var bga_downloader = $YoutubeBgaDownloader
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var status_label: Label = $UI/StatusLabel

var save_dir = "user://bga_cache/song_1"

func _ready() -> void:
	bga_downloader.download_started.connect(_on_bga_download_started)
	bga_downloader.download_progress_msg.connect(_on_bga_progress)
	bga_downloader.download_completed.connect(_on_bga_download_completed)
	bga_downloader.download_failed.connect(_on_bga_download_failed)

func request_song_bga(youtube_link: String) -> void:
	# 다운로드 시작 시 로드
	bga_downloader.request_youtube_bga(youtube_link, save_dir)

func _on_bga_download_started() -> void:
	status_label.text = "BGA 다운로드 준비 중..."

func _on_bga_progress(msg: String) -> void:
	status_label.text = msg

func _on_bga_download_completed(file_path: String) -> void:
	status_label.text = "다운로드 및 최적화 완료!"
	
	# 저장된 비디오를 비디오 스트림에 장착
	var video_stream = VideoStreamTheora.new()
	video_stream.file = file_path
	video_player.stream = video_stream
	
	# 이제 오디오가 출발할 때 함께 플레이 준비가 끝났습니다!
	print("로컬 BGA 셋팅 완료: ", file_path)

func _on_bga_download_failed(err: String) -> void:
	status_label.text = "에러: " + err
	push_error("BGA 수집 에러: " + err)
```

---

## ⚡ 요약 및 리듬 게임 최적화 조언

유튜브 영상을 인게임으로 끌어올 때 가장 주의할 것은 **"오버헤드로 인한 사운드 싱크 파괴 방지"**입니다. 
따라서 `방법 A`를 활용하여 아래처럼 빌드를 구성하는 것이 최고입니다.

1. **설치 경로 동봉:** 스탠드얼론 패키징 배포 시 게임 폴더 아래 `bin/` 디렉터리에 `yt-dlp` 및 `ffmpeg` 바이너리를 동봉하여 배포하십시오. `OS.execute` 시 해당 로컬 실행 파일 경로를 불러와 실행하면 유저가 직접 도구를 설치할 필요가 없어 매우 친절한 UI 구성을 짤 수 있습니다.
2. **사전 다운로드 UI 패턴:** 곡 선택 창 또는 곡 상세 화면에서 **[BGA 사전 다운로드]** 버튼을 만들고 다운로드 바가 가득 찬 뒤에 비디오 재생 상태로 플레이하게 설계하십시오. 
3. **무음 캐싱:** `ffmpeg -an` 플래그는 유튜브 영상 내의 소리를 무조건 날려버립니다. 리듬게임 곡 소스는 원래 동봉되어 있는 고음질의 음악 트랙(`AudioStreamPlayer`)으로 재생하고, 변환된 영상은 비주얼 전용 백그라운드로만 돌리게 되므로 싱크 안정성이 배가됩니다.
