# We Want To Keyboard

Godot 4 기반 리듬/타겟 게임과 Arduino 키보드 컨트롤러 스케치를 함께 담은 프로젝트입니다.

플레이어는 곡을 선택한 뒤 음악에 맞춰 화면에 나타나는 과녁 노트를 `Space` 또는 마우스 클릭으로 맞힙니다. 일반 노트, 이동 노트, 길게 누르는 HOLD 노트가 있으며, 판정과 콤보를 기반으로 최종 점수가 계산됩니다.

## 프로젝트 구성

```text
.
├─ window/window-gun/        Godot 게임 프로젝트
│  ├─ project.godot          Godot 프로젝트 설정
│  ├─ scenes/                메뉴, 게임, 결과, 편집기 씬
│  ├─ scripts/               게임 로직, UI, 이펙트, 전역 상태
│  └─ assets/                이미지, 폰트, 음악, 차트, BGA
└─ arduino/controller.ino    4버튼 키보드 컨트롤러 스케치
```

## 게임 개요

- 장르: 리듬 게임 / 타겟 클릭 게임
- 엔진: Godot 4
- 기본 입력: `Space`, 마우스 왼쪽 클릭
- Arduino 입력: 버튼 4개를 `D`, `F`, `J`, `K` 키로 매핑
- 곡 데이터 위치: `window/window-gun/assets/musics/<곡 이름>/`
- 메인 메뉴 씬: `res://scenes/menu/main_menu.tscn`
- 게임 씬: `res://scenes/game/game.tscn`
- 결과 씬: `res://scenes/menu/result_scene.tscn`

## 플레이 흐름

1. 메인 메뉴에서 입력을 받으면 곡 선택 화면으로 이동합니다.
2. 곡 선택 화면에서 `assets/musics` 폴더의 곡 목록을 표시합니다.
3. 선택한 곡 이름은 `Global.selected_music`에 저장됩니다.
4. 게임 씬에 진입하면 선택한 곡의 `chart.json`을 읽습니다.
5. 차트 시간에 맞춰 노트와 이벤트를 생성합니다.
6. 노트를 순서대로 맞히면 점수와 콤보가 올라갑니다.
7. 곡이 끝나고 활성 노트가 사라지면 결과 화면으로 이동합니다.

## 주요 스크립트

### 전역 상태

`window/window-gun/scripts/autoload/global.gd`

- 점수, 콤보, 최대 콤보 관리
- 판정 수(`perfect`, `great`, `good`, `miss`) 관리
- 선택 곡과 곡 경로 헬퍼 관리
- 설정 저장/불러오기
- 히트 효과음 생성 및 재생
- 카메라 흔들림 시그널 제공

### 게임 진행

`window/window-gun/scripts/gameplay/game_controller.gd`

- `chart.json` 로드
- 노트와 이벤트 시간순 정렬
- 일반 노트, 이동 노트, HOLD 노트 생성
- 차트 이벤트로 OS Window 또는 게임 내부 이미지를 표시
- 음악 재생 위치를 기준으로 현재 시간을 보정
- 곡 종료 후 결과 화면 전환

### 일반/이동 노트

`window/window-gun/scripts/gameplay/target_note.gd`

- 고정 노트와 이동 노트 생성
- 순서 기반 입력 판정
- `perfect`, `great`, `good`, `miss` 판정 계산
- 점수, 콤보, 판정 수 갱신
- 파티클, 판정 텍스트, 히트 리플, 카메라 흔들림 연출

### HOLD 노트

`window/window-gun/scripts/gameplay/hold_note.gd`

- 화면 전체 HOLD 상태 표시
- `Space` 또는 마우스 왼쪽 버튼을 누르고 있는지 확인
- BPM과 beat division에 맞춰 주기적으로 점수와 콤보 증가
- 입력을 놓치면 tolerance gauge가 줄고, 0이 되면 miss 페널티 적용

### 음악 재생

`window/window-gun/scripts/effects/audio_stream_player.gd`

- 선택한 곡의 MP3 파일 로드
- `Res.tres`의 offset을 반영해 재생 시작
- `Global.audio_player`에 자기 자신을 등록

### BGA

`window/window-gun/scripts/gameplay/bga_manager.gd`

- 곡 폴더의 `bga.ogv`를 동적으로 로드
- BGA 오디오는 사용하지 않고, 실제 음악은 `AudioStreamPlayer`가 재생
- 오디오 재생 시작 시점에 맞춰 BGA를 시작

### 결과 화면

`window/window-gun/scripts/ui/result_scene.gd`

- 최종 점수와 최대 콤보 표시
- 판정 수 표시
- 1,000,000점 만점 기준 점수를 랭크로 변환
- 랭크는 점수 구간별 확률표를 사용해 룰렛처럼 결정
- 1,000,000점이면 ALL PERFECT 연출 활성화

## 곡 폴더 구조

각 곡은 `window/window-gun/assets/musics/<곡 이름>/` 아래에 둡니다.

```text
assets/musics/<곡 이름>/
├─ <곡 이름>.mp3
├─ Res.tres
├─ chart.json
├─ img.png
└─ bga.ogv              선택 사항
```

### `Res.tres`

곡 메타데이터를 담는 Godot 리소스입니다.

- `title`: 표시용 곡 제목
- `composer`: 작곡가
- `bpm`: BPM
- `offset`: 음악/차트 오프셋
- `audio_stream`: 오디오 스트림
- `jacket_image`: 자켓 이미지

### `chart.json`

게임에 사용할 노트와 이벤트를 담습니다.

```json
{
  "offset_corrected": true,
  "notes": [
    {
      "time": 1.5,
      "x": 960,
      "y": 540,
      "type": "normal"
    }
  ],
  "events": []
}
```

## 노트 타입

### 일반 노트

```json
{
  "time": 1.5,
  "x": 960,
  "y": 540,
  "type": "normal"
}
```

### 이동 노트

```json
{
  "time": 2.0,
  "type": "moving",
  "start_x": 200,
  "start_y": 800,
  "x": 960,
  "y": 540,
  "move_duration": 0.7
}
```

선택 필드:

- `curve_control_x`, `curve_control_y`: 베지어 곡선 제어점
- `use_gravity`: 곡선 이동에 가속감 적용
- `move_duration`: 이동 시간

### HOLD 노트

```json
{
  "time": 10.0,
  "type": "hold",
  "duration": 3.0,
  "beat_division": 4
}
```

## 이벤트 타입

차트 이벤트는 화면에 이미지나 별도 OS Window를 띄우는 연출입니다.

지원 타입:

- `window`
- `window_moving_linear`
- `window_moving_smooth`
- `image`
- `image_moving_linear`
- `image_moving_smooth`

예시:

```json
{
  "time": 5.0,
  "type": "image_moving_smooth",
  "x": 100,
  "y": 200,
  "target_x": 800,
  "target_y": 200,
  "width": 300,
  "height": 200,
  "duration": 2.0,
  "texture_path": "res://assets/image/ingame/과녁.png",
  "opacity": 0.8
}
```

## 점수와 판정

일반 노트 판정:

- `perfect`: 100점
- `great`: 80점
- `good`: 50점
- `miss`: 0점 또는 페널티

HOLD 노트:

- 누르고 있는 동안 BPM과 `beat_division`에 맞춰 10점씩 증가
- 놓친 시간이 tolerance gauge를 초과하면 miss 페널티 적용

최종 점수는 `Global.max_base_score` 대비 현재 base score를 기준으로 1,000,000점 만점으로 환산됩니다.

## BGA 가이드

Godot 기본 `VideoStreamPlayer`는 `.ogv` 사용이 가장 안정적입니다. 이 프로젝트도 곡 폴더의 `bga.ogv`를 읽는 구조입니다.

권장 변환:

```bash
ffmpeg -i input_bga.mp4 -c:v libtheora -q:v 6 -an bga.ogv
```

권장 사항:

- BGA 파일은 각 곡 폴더에 `bga.ogv` 이름으로 저장합니다.
- BGA에는 오디오 트랙을 넣지 않는 것을 권장합니다.
- 실제 음악은 곡 MP3를 `AudioStreamPlayer`로 별도 재생합니다.
- 고해상도 BGA가 성능에 부담되면 720p 또는 540p로 낮춥니다.

## MP4와 YouTube BGA에 대한 메모

Godot 기본 기능만으로는 MP4/H.264 재생이 안정적으로 지원되지 않습니다. MP4를 직접 쓰려면 FFmpeg 기반 GDExtension 같은 추가 플러그인이 필요합니다.

YouTube 영상을 BGA로 쓰는 방식은 실시간 스트리밍보다 다운로드 후 `.ogv`로 변환해 로컬 캐시하는 방식이 리듬 게임에는 더 안전합니다. 실시간 스트리밍은 네트워크 버퍼링 때문에 음악과 영상 싱크가 흔들릴 수 있습니다.

## Arduino 컨트롤러

`arduino/controller.ino`는 4개의 물리 버튼을 키보드 입력으로 변환합니다.

- 버튼 핀: `2`, `3`, `4`, `5`
- 키 매핑: `D`, `F`, `J`, `K`
- 입력 방식: `INPUT_PULLUP`
- 디바운스: 10ms

현재 Godot 게임의 기본 노트 입력은 `Space`와 마우스 클릭 중심입니다. Arduino 키 입력을 실제 게임 입력으로 쓰려면 Godot 입력 액션 또는 노트 입력 로직에 `D/F/J/K`를 연결해야 합니다.

## 개발 메모

- 스크립트 주석 일부는 인코딩이 깨져 있습니다. 코드 자체는 대부분 읽을 수 있습니다.
- 문서와 실제 코드가 달랐던 오래된 메모는 README에 반영하면서 현재 코드 기준으로 정리했습니다.
- BGA 관련 오래된 별도 가이드는 핵심만 이 README에 통합했습니다.
- `rules.md`의 AI 작업 규칙은 프로젝트 문서 성격과 달라 README에는 짧게만 반영했습니다.

## 작업 시 주의

- `arduino/` 폴더는 컨트롤러 스케치이므로 게임 로직 수정과 분리해서 다룹니다.
- Godot 프로젝트는 `window/window-gun/` 아래가 기준입니다.
- 곡 추가 시 폴더 이름, MP3 파일명, `Res.tres`, `chart.json` 경로가 서로 맞아야 합니다.
- 리듬 게임 특성상 변경 후에는 Godot에서 직접 실행해 타이밍과 판정을 확인하는 것이 좋습니다.
