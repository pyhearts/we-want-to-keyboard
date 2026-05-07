# window-gun 코드 요약과 개선점

작성일: 2026-05-07

이 문서는 `window/window-gun` Godot 프로젝트를 읽고 정리한 기록이다. `arduino` 폴더는 건드리지 않았다.

## 프로젝트 개요

- 엔진: Godot 4.6 계열 프로젝트
- 메인 씬: `res://scenes/menu/main_menu.tscn`
- 자동 로드: `Global` (`res://scripts/autoload/global.gd`)
- 핵심 흐름:
  1. 메인 메뉴에서 아무 키나 누르면 음악 선택 화면으로 이동한다.
  2. 음악 선택 화면에서 위/아래 버튼으로 `assets/musics` 폴더 목록을 순환한다.
  3. 가운데 선택된 곡 이름이 `Global.selected_music`에 저장된다.
  4. 곡 버튼을 누르면 게임 씬으로 이동한다.
  5. 게임 씬은 선택된 곡의 `chart.json`을 읽고, 시간에 맞춰 노트와 이벤트를 생성한다.
  6. 노트를 순서대로 누르면 점수와 콤보가 올라가고, 놓치면 점수와 콤보가 깎인다.

## 주요 폴더

- `window/window-gun/project.godot`: 프로젝트 설정, 입력 액션, 메인 씬, 오토로드 설정
- `window/window-gun/scenes/menu`: 메인 메뉴와 음악 선택 씬
- `window/window-gun/scenes/game`: 게임 씬과 타겟 노트 씬
- `window/window-gun/scripts/autoload`: 전역 상태
- `window/window-gun/scripts/gameplay`: 게임 진행, 노트 생성과 판정
- `window/window-gun/scripts/ui`: 점수, 콤보, 음악 선택 UI
- `window/window-gun/scripts/effects`: 음악 재생, 배경 기울기, 판정 링 효과
- `window/window-gun/assets/musics`: 곡별 오디오, `Res.tres`, `chart.json`

## 주요 스크립트 요약

### `scripts/autoload/global.gd`

전역 상태를 관리한다.

- `score`, `combo`, `time`
- `music_titles`: `res://assets/musics/` 안의 폴더 목록
- `selected_music`: 현재 선택된 곡 폴더명
- 점수/콤보 초기화와 증가 함수

주의점: `time`은 전역에서도 증가하지만, 실제 게임 차트 진행은 `game_controller.gd`의 `current_time`을 따로 사용한다. 시간 기준이 둘로 나뉘어 있다.

### `scripts/ui/start_on_any_input.gd`

메인 메뉴 배경에 붙어 있으며, 키보드나 마우스 입력을 받으면 `next_scene`으로 이동한다.

### `scripts/ui/VBoxContainerMove.gd`

음악 선택 화면의 곡 리스트를 관리한다.

- `Global.music_titles`를 기반으로 5개 버튼을 채운다.
- 위/아래 버튼을 누르면 현재 인덱스를 바꾸고 UI를 갱신한다.
- 가운데 버튼의 곡명을 `Global.selected_music`에 저장한다.
- 선택을 바꿀 때 해당 곡 mp3를 미리 재생한다.

### `scripts/ui/music_select_button.gd`

곡 선택 버튼이다. 누르면 게임 씬으로 이동한다.

현재 구조에서는 실제로 어떤 곡을 선택할지는 이 버튼이 아니라 `VBoxContainerMove.gd`가 `Global.selected_music`에 저장한 값에 의존한다.

### `scripts/gameplay/game_controller.gd`

게임 씬의 중심 컨트롤러다.

- `_ready()`에서 `Global.reset_run()` 후 `start_chart()` 실행
- `load_chart()`로 `assets/musics/<selected_music>/chart.json` 로드
- 차트의 `notes`, `events`를 시간순 정렬
- `_process(delta)`에서 `current_time`을 증가시키며 노트와 이벤트 처리
- `1`, `2`, `3` 키로 수동 노트 스폰 테스트
- `4`, `5`, `6` 키로 별도 OS 윈도우 생성 테스트
- `Window` 오브젝트 풀과 텍스처 캐시를 사용하려는 구조가 있다.

주의점: 이벤트 처리 코드는 `event_info["type"] == "window"`만 처리한다. 그런데 `MEGALOVANIA/chart.json`의 이벤트 타입은 `window_moving_linear`, `window_moving_smooth`라서 현재는 실행되지 않는다.

주의점: `_animate_window_movement_smooth()`는 마지막에 `window.queue_free()`를 호출한다. 그런데 윈도우 풀링 구조는 숨긴 뒤 재사용하는 의도다. `queue_free()`는 풀에 들어 있는 객체를 삭제하므로 풀링 의도와 충돌한다. 같은 파일의 linear 이동은 `window.hide()`를 사용한다.

### `scripts/gameplay/target_note.gd`

타겟 노트의 생성, 이동, 판정, 이펙트를 담당한다.

- 원본 노드는 숨겨지고, `spawn_node()`가 자기 자신을 `duplicate()`해서 실제 노트 clone을 만든다.
- `normal` 노트는 지정 위치 또는 랜덤 위치에 생성된다.
- `moving` 노트는 아래쪽 시작 위치에서 목표 위치로 포물선처럼 이동한다.
- `active_notes` 정적 배열로 현재 살아 있는 노트 순서를 관리한다.
- 첫 번째 노트를 맞추면 콤보 증가와 시간 기반 점수 계산이 적용된다.
- 순서가 아닌 노트를 누르면 콤보가 초기화되고 기본 50점만 얻는다.
- 시간이 지나면 `penalty_score`만큼 감점되고 콤보가 초기화된다.
- 히트/미스 시 `CPUParticles2D`를 즉석 생성해서 파티클을 표시한다.
- 다음 노트와 연결선을 그리는 기능이 있다.

점수 규칙:

- 기본 히트 점수: 50
- 순서대로 누른 경우: 생존 시간에 따라 50점에서 100점까지 증가
- `judgment_time` 이후 누르면 100점
- 제한 시간 초과: 기본 `-70`

### `scripts/effects/audio_stream_player.gd`

선택된 곡을 재생한다.

- `Global.selected_music`이 비어 있으면 아무것도 하지 않는다.
- `assets/musics/<selected_music>/Res.tres`에서 `offset`을 읽는다.
- 실제 대기 시간은 `music_res.offset + 0.7`이다.
- 대기 후 `assets/musics/<selected_music>/<selected_music>.mp3`를 로드해서 재생한다.

주의점: 차트 진행 시간은 `game_controller.gd`가 즉시 시작하고, 음악은 `offset + 0.7`초 후 시작한다. 의도적으로 노트 판정 시간과 맞추려는 것일 수 있지만, 차트 시간과 오디오 재생 시간이 서로 직접 동기화되어 있지는 않다.

### `scripts/effects/judgment_ring.gd`

판정 링을 크게 시작해서 `duration` 동안 원래 크기로 줄이는 Tween 효과다.

### `scripts/effects/background_tilt.gd`

마우스 위치에 따라 배경 이미지를 좌우로 살짝 기울인다.

## 차트 데이터

곡 폴더 구조는 대체로 다음과 같다.

```text
assets/musics/<곡 이름>/
  <곡 이름>.mp3
  <곡 이름>.mp3.import
  Res.tres
  chart.json
```

현재 확인한 차트:

- `R/chart.json`: notes/events 비어 있음
- `Flower Rocket/chart.json`: notes/events 비어 있음
- `MEGALOVANIA/chart.json`: 노트 2개, 이벤트 2개

`MEGALOVANIA/chart.json` 예시는 `notes`와 `events`를 가진다.

- 노트 필드: `time`, `x`, `y`, `type`
- 이벤트 필드: `time`, `x`, `y`, `width`, `height`, `type`, `texture_path`

현재 코드와 차트 사이의 불일치:

- 코드의 이벤트 처리: `type == "window"`만 처리
- 실제 차트 이벤트: `window_moving_linear`, `window_moving_smooth`
- 결과: MEGALOVANIA의 이벤트는 현재 게임에서 무시될 가능성이 높다.

## 발견한 개선점

### 1. 차트 시간과 음악 시간을 동기화하기

현재 `game_controller.gd`는 `_process(delta)`로 자체 시간을 증가시키고, `audio_stream_player.gd`는 offset 대기 후 음악을 재생한다. 리듬 게임에서는 오디오 재생 위치가 기준이 되는 편이 안정적이다.

개선 방향:

- 게임 컨트롤러가 `AudioStreamPlayer.get_playback_position()` 또는 `AudioServer.get_time_since_last_mix()` 보정값을 기준으로 차트를 처리한다.
- `Global.time`, `current_time`, 오디오 offset의 역할을 명확히 나눈다.
- `+ 0.7` 같은 보정값은 상수나 곡 데이터로 옮긴다.

### 2. 이벤트 타입 처리 확장

현재 `_process_event()`는 `"window"` 타입만 처리한다. 차트에는 `window_moving_linear`, `window_moving_smooth`가 들어 있다.

개선 방향:

- `window`: 정적 창
- `window_moving_linear`: 선형 이동 창
- `window_moving_smooth`: 부드러운 이동 창
- `duration`, `target_x`, `target_y`, `texture_path` 같은 필드를 차트 스키마에 명확히 정의한다.

### 3. 윈도우 풀링 버그 수정

`game_controller.gd`는 `window_pool`로 창을 재사용하려고 하지만, smooth 이동 완료 시 `queue_free()`를 호출한다.

개선 방향:

- 이동 완료 후에는 `hide()`로 통일한다.
- 풀에서 가져올 때 `is_instance_valid(w)` 체크를 추가한다.
- 창이 닫힌 경우에도 삭제하지 않고 숨기는 정책을 유지한다.

### 4. 파일명과 인코딩 정리

콘솔에서 읽었을 때 일부 한글 파일명과 주석이 깨져 보인다. Godot 씬 파일 안의 리소스 경로도 깨진 문자열처럼 표시되는 부분이 있었다.

개선 방향:

- 스크립트와 씬 파일을 UTF-8로 저장했는지 확인한다.
- 가능하면 리소스 파일명은 ASCII 또는 일관된 한글 UTF-8 이름으로 정리한다.
- 깨진 경로가 실제 Godot 에디터에서 정상 로드되는지 확인한다.

### 5. `Global.selected_music`이 비어 있을 때의 방어 코드

게임 씬을 직접 실행하거나 곡 선택 없이 진입하면 `assets/musics//chart.json`을 찾게 된다.

개선 방향:

- 선택된 곡이 없으면 기본 곡을 선택하거나 음악 선택 화면으로 되돌린다.
- `load_chart()`에서 더 친절한 에러와 fallback을 제공한다.

### 6. `chart_data["events"]` 존재 여부 체크

`start_chart()`는 `notes`만 확인한 뒤 `chart_data["events"]`를 바로 정렬한다. `events`가 없는 차트면 오류가 날 수 있다.

개선 방향:

- `notes`와 `events` 모두 기본 빈 배열로 보정한다.
- 차트 스키마 검증 함수를 따로 둔다.

### 7. 노트 스폰 방식 최적화

노트는 매번 `duplicate()`로 생성되고, 파티클도 매번 새로 생성된다. 지금 규모에서는 괜찮지만 노트 수가 많아지면 부담이 커질 수 있다.

개선 방향:

- 노트도 윈도우처럼 풀링할 수 있다.
- 파티클은 PackedScene으로 만들어 재사용하거나, 최소한 생성 책임을 별도 이펙트 매니저로 분리한다.

### 8. 정적 배열 상태 초기화 명확화

`target_note.gd`의 `recent_positions`, `active_notes`는 static 배열이다. 원본 노드 `_ready()`에서 초기화되지만, 씬 전환이나 테스트 실행이 복잡해지면 남은 상태가 문제를 만들 수 있다.

개선 방향:

- 게임 시작 시 컨트롤러에서 명시적으로 노트 상태를 reset하는 함수 호출
- `TargetNote.reset_state()` 같은 static reset 함수 추가

### 9. 테스트 입력과 실제 입력 분리

`game_controller.gd`의 `1`~`6` 키는 개발용 테스트 스폰으로 보인다. 프로젝트 설정에도 숫자 키 입력 액션이 등록되어 있다.

개선 방향:

- 디버그 빌드에서만 동작하도록 플래그를 둔다.
- 실제 게임 입력과 개발 테스트 입력을 분리한다.

### 10. UI 라벨 갱신 방식 개선

점수와 콤보 라벨은 매 프레임 `Global` 값을 읽어 텍스트를 바꾼다.

개선 방향:

- 점수/콤보가 바뀔 때 시그널로 UI를 갱신한다.
- 당장은 문제 없지만, UI가 많아지면 시그널 방식이 더 깔끔하다.

### 11. 음악 선택 데이터 개선

곡 리스트는 폴더명만 사용하고, `Res.tres`의 `title`, `composer`, `bpm`, `jacket_image` 정보는 거의 UI에 쓰이지 않는다.

개선 방향:

- 버튼에는 폴더명 대신 `MusicData.title` 표시
- 작곡가, BPM, 자켓 이미지 표시
- 실제 로드용 id/folder와 표시용 title을 분리

### 12. `.gitignore` 보강

현재 `window/window-gun/.gitignore`는 `*.tmp`만 무시한다. Godot 프로젝트에서는 `.godot/` 캐시가 보통 버전 관리에서 제외된다.

개선 방향:

- `.godot/`
- 수출 결과물
- OS별 임시 파일

등을 `.gitignore`에 추가하는 것을 고려한다.

## 우선순위 추천

1. 이벤트 타입 불일치 수정
2. 차트 시간과 오디오 시간 동기화
3. 윈도우 풀링의 `queue_free()`/`hide()` 불일치 수정
4. 선택 곡 없음, `events` 없음 같은 방어 코드 추가
5. 인코딩과 리소스 경로 정상 여부 확인
6. 음악 선택 UI가 `Res.tres`의 곡 메타데이터를 사용하도록 개선

## 읽을 때 참고할 핵심 파일

- `window/window-gun/project.godot`
- `window/window-gun/scripts/autoload/global.gd`
- `window/window-gun/scripts/gameplay/game_controller.gd`
- `window/window-gun/scripts/gameplay/target_note.gd`
- `window/window-gun/scripts/ui/VBoxContainerMove.gd`
- `window/window-gun/scripts/effects/audio_stream_player.gd`
- `window/window-gun/assets/musics/*/chart.json`
- `window/window-gun/assets/musics/*/Res.tres`

## 2026-05-07 개선 적용 기록

`scripts/gameplay/game_controller.gd`를 정리하고 다음 개선을 적용했다.

- 선택된 곡이 없는 상태에서 게임 씬을 직접 실행해도 `assets/musics`의 첫 곡으로 fallback되도록 했다.
- `chart.json`에 `notes` 또는 `events`가 없거나 배열이 아니어도 빈 배열로 보정하도록 했다.
- 노트/이벤트 필수 필드가 빠진 경우 크래시 대신 warning 후 건너뛰도록 했다.
- 차트 이벤트 타입 `window`, `window_moving_linear`, `window_moving_smooth`를 처리하도록 했다.
- 이벤트의 `duration`, `title`, `texture_path`, `target_x`, `target_y`, `to_x`, `to_y` 필드를 선택적으로 사용할 수 있게 했다.
- 움직이는 OS 창이 끝난 뒤 `queue_free()`로 삭제되지 않고 `hide()`로 숨겨져 풀링 의도와 맞게 재사용되도록 했다.
- 풀에 들어 있는 창이 이미 삭제된 경우 `is_instance_valid()`로 제거하도록 했다.
- 깨진 주석이 많던 `game_controller.gd`를 ASCII 중심의 읽기 쉬운 주석/구조로 정리했다.

검증:

- Godot headless 프로젝트 로드 성공
- `res://scenes/game/game.tscn` 3초 실행 성공
- `res://scenes/menu/music_select.tscn` 3초 실행 성공

참고: 음악 선택 씬은 `--quit-after`로 강제 종료할 때 `ObjectDB instances leaked`와 리소스 사용 경고가 출력됐다. 음악 offset 대기 타이머 중 강제로 종료되며 생긴 경고로 보이며, 씬 로딩 자체는 성공했다.
