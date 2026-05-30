extends Control

const MUSIC_BASE_PATH = "res://assets/musics/"
const MAIN_MENU_SCENE = "res://scenes/menu/main_menu.tscn"

# UI 노드 바인딩
@onready var song_select: OptionButton = %SongSelect
@onready var bpm_input: LineEdit = %BpmInput
@onready var offset_input: LineEdit = %OffsetInput
@onready var snap_select: OptionButton = %SnapSelect
@onready var type_select: OptionButton = %TypeSelect
@onready var hold_settings: VBoxContainer = %HoldSettings
@onready var duration_input: LineEdit = %DurationInput
@onready var division_input: LineEdit = %DivisionInput
@onready var play_button: Button = %PlayButton
@onready var speed_select: OptionButton = %SpeedSelect
@onready var time_label: Label = %TimeLabel
@onready var preview_canvas: Control = %PreviewCanvas
@onready var timeline: Control = %Timeline
@onready var toast: PanelContainer = %Toast
@onready var toast_label: Label = %ToastLabel

# New variables for Moving settings and Top bar
var top_bar: Panel
var to_effect_editor_btn: Button
var moving_settings: VBoxContainer
var start_x_input: LineEdit
var start_y_input: LineEdit
var set_start_btn: Button
var is_setting_start_pos: bool = false

# --- 포물선 드래그 모드 상태 ---
var is_curve_draw_mode: bool = false       # 곡선 드래그 모드 활성화 여부
var is_curve_dragging: bool = false        # 현재 마우스 드래그 중 여부
var curve_drag_start: Vector2 = Vector2.ZERO   # 마우스 누른 시작점 (논리 좌표)
var curve_drag_end: Vector2 = Vector2.ZERO     # 마우스 뗀 끝점 (논리 좌표)
var curve_drag_current: Vector2 = Vector2.ZERO # 실시간 마우스 위치 (논리 좌표)
var curve_drag_max_deviation: float = 0.0  # 드래그 중 최대 이탈 거리
var curve_drag_side: float = 1.0           # 이탈 방향 부호 (+1 또는 -1)

# --- 중력 토글 및 이동 시간 ---
var use_gravity_check: CheckBox = null
var moving_duration_input: LineEdit = null
var draw_curve_btn: Button = null
var moving_duration: float = 1.0

# --- 편의 기능 관련 추가 변수 ---
var bookmarks: Dictionary = {}             # 북마크 (Alt+1~5 저장, 1~5 이동)
var timeline_zoom: float = 1.0             # 타임라인 마우스 휠 줌 배율
var autosave_timer: float = 0.0            # 자동 저장용 누적 타이머

# --- 오토플레이 및 리플 효과 변수 ---
var is_autoplay: bool = false
var autoplay_hit_notes: Dictionary = {}
var autoplay_ripples: Array = []

# --- 구간 재생 및 반복 재생 (Region Selection & Looping) ---
var region_start_time: float = -1.0
var region_end_time: float = -1.0
var is_region_loop: bool = true
var is_playing_region: bool = false
var is_dragging_region: bool = false
var drag_start_time: float = 0.0

var region_settings_box: VBoxContainer = null
var region_lbl_info: Label = null
var region_loop_check: CheckBox = null
var region_play_btn: Button = null

# 에디터 상태 변수
var music_list: Array = []
var selected_song: String = ""
var chart_data: Dictionary = {"notes": [], "events": []}
var bpm: float = 120.0
var offset: float = 0.0
var current_time: float = 0.0
var is_playing: bool = false
var playback_speed: float = 1.0
var snap_division: int = 16 # 4, 8, 16, 32
var selected_type: String = "normal" # normal, moving, hold

# Hold 노트 설정 기본값
var hold_duration: float = 3.0
var hold_division: int = 16

# 오디오 플레이어
var audio_player: AudioStreamPlayer
var song_duration: float = 0.0

# 노트 조작 관련
var hover_note_index: int = -1
var selected_note_index: int = -1
var drag_offset = Vector2.ZERO
var is_dragging_note: bool = false
var undo_stack: Array = []
var redo_stack: Array = []
const MAX_UNDO_DEPTH: int = 50
var copied_note_data: Dictionary = {}

# 핑크 테마 컬러 상수
const COLOR_BG_CANVAS = Color(1.0, 0.960784, 0.968627, 1.0)        # #FFF5F7
const COLOR_BORDER_CANVAS = Color(1.0, 0.560784, 0.639216, 0.8)    # #FF8FA3
const COLOR_GRID_CANVAS = Color(1.0, 0.815686, 0.854902, 0.4)      # #FFE3E8
const COLOR_TEXT_WINE = Color(0.290196, 0.0823529, 0.129412, 1.0)   # #4A1521
const COLOR_TEXT_WINE_MUTED = Color(0.541176, 0.352941, 0.396078, 1.0) # #8A5A65

const COLOR_NOTE_NORMAL = Color(1.0, 0.301961, 0.427451, 1.0)      # #FF4D6D
const COLOR_NOTE_MOVING = Color(1.0, 0.458824, 0.560784, 1.0)      # #FF758F
const COLOR_NOTE_HOLD = Color(0.788235, 0.0941176, 0.290196, 1.0)    # #C9184A
const COLOR_NOTE_SELECTED = Color(1.0, 0.0, 0.329412, 1.0)         # #FF0054

const COLOR_BG_TIMELINE = Color(1.0, 0.898039, 0.92549, 1.0)       # #FFE5EC
const COLOR_HEADER_TIMELINE = Color(1.0, 0.0, 0.329412, 0.95)     # #FF0054 (재생헤드)
const COLOR_GRID_TIMELINE_MAIN = Color(0.788235, 0.0941176, 0.290196, 0.6) # #C9184A (1비트선)
const COLOR_GRID_TIMELINE_SUB = Color(1.0, 0.760784, 0.819608, 0.5)  # #FFC2D1 (스냅선)

func _ready() -> void:
	# AudioStreamPlayer 생성 및 씬 추가
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	# 드롭다운 초기화
	_setup_dropdowns()
	
	# 이벤트 바인딩
	song_select.item_selected.connect(_on_song_selected)
	snap_select.item_selected.connect(_on_snap_selected)
	type_select.item_selected.connect(_on_type_selected)
	speed_select.item_selected.connect(_on_speed_selected)
	
	play_button.pressed.connect(_on_play_pressed)
	
	bpm_input.text_submitted.connect(_on_bpm_submitted)
	offset_input.text_submitted.connect(_on_offset_submitted)
	duration_input.text_submitted.connect(_on_hold_duration_submitted)
	division_input.text_submitted.connect(_on_hold_division_submitted)
	
	# 프리뷰 캔버스 마우스 입력 이벤트
	preview_canvas.gui_input.connect(_on_canvas_gui_input)
	timeline.gui_input.connect(_on_timeline_gui_input)
	
	# 토스트 투명도 초기화
	toast.modulate.a = 0.0
	
	# 곡 목록 로드
	_load_song_list()
	
	# 첫 번째 곡 자동 로드
	if song_select.item_count > 0:
		_on_song_selected(0)
	
	_setup_top_bar()
	_setup_moving_settings_ui()
	_setup_region_settings_ui()
	
	# 에디터 테스트 모드에서 회귀 시 시간 복구 및 정리
	if Global.is_editor_test_mode:
		current_time = Global.editor_test_start_time
		Global.is_editor_test_mode = false
		_seek_time(current_time)

func _setup_dropdowns() -> void:
	# 그리드 스냅 분주 설정
	snap_select.clear()
	snap_select.add_item("No Snap (Free)", 1)
	snap_select.add_item("4 Beats", 4)
	snap_select.add_item("8 Beats", 8)
	snap_select.add_item("16 Beats", 16)
	snap_select.add_item("32 Beats", 32)
	snap_select.selected = 3 # 16 Beats 기본값
	snap_division = 16
	
	# 노트 타입 설정
	type_select.clear()
	type_select.add_item("Normal Note", 0)
	type_select.add_item("Moving Note", 1)
	type_select.add_item("Hold Note", 2)
	type_select.selected = 0
	hold_settings.visible = false
	
	# 재생 배속 설정
	speed_select.clear()
	speed_select.add_item("0.5x Speed", 0)
	speed_select.add_item("0.75x Speed", 1)
	speed_select.add_item("1.0x Speed", 2)
	speed_select.add_item("1.25x Speed", 3)
	speed_select.add_item("1.5x Speed", 4)
	speed_select.selected = 2 # 1.0x

func _load_song_list() -> void:
	song_select.clear()
	music_list = Global.get_folder_list(MUSIC_BASE_PATH)
	for song in music_list:
		song_select.add_item(song)

func _on_song_selected(index: int) -> void:
	if index < 0 or index >= music_list.size():
		return
	
	selected_song = music_list[index]
	Global.selected_music = selected_song
	
	# 음악 파일 및 BPM 리소스 로드
	var res_path = MUSIC_BASE_PATH + selected_song + "/Res.tres"
	var music_res = null
	if FileAccess.file_exists(res_path):
		music_res = load(res_path)
	
	if music_res:
		bpm = float(music_res.get("bpm"))
		offset = float(music_res.get("offset"))
		audio_player.stream = music_res.get("audio_stream")
	else:
		bpm = 120.0
		offset = 0.0
		audio_player.stream = null
		
	# UI 동기화
	bpm_input.text = str(bpm)
	offset_input.text = str(offset)
	
	# 오디오 플레이어 세팅
	if audio_player.stream:
		song_duration = audio_player.stream.get_length()
	else:
		song_duration = 180.0 # 예비 3분
	
	current_time = 0.0
	is_playing = false
	audio_player.stop()
	play_button.text = "Play"
	
	# 채보 로드
	_load_chart()
	
	# 캔버스 갱신
	preview_canvas.queue_redraw()
	timeline.queue_redraw()

func _load_chart() -> void:
	var path = MUSIC_BASE_PATH + selected_song + "/chart.json"
	if not FileAccess.file_exists(path):
		chart_data = {
			"notes": [],
			"events": [],
			"offset_corrected": true
		}
		_save_chart_file()
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary:
			chart_data = parsed
			if not chart_data.has("notes"):
				chart_data["notes"] = []
			if not chart_data.has("events"):
				chart_data["events"] = []
				
			# 구버전 차트 좌표 보정 (offset_corrected 플래그가 없는 경우)
			if not chart_data.get("offset_corrected", false):
				for note in chart_data["notes"]:
					if note is Dictionary:
						if note.has("x"):
							note["x"] = float(note["x"]) - 230.0
						if note.has("y"):
							note["y"] = float(note["y"]) - 90.0
						if note.has("start_x"):
							note["start_x"] = float(note["start_x"]) - 230.0
						if note.has("start_y"):
							note["start_y"] = float(note["start_y"]) - 90.0
				chart_data["offset_corrected"] = true
				_save_chart_file()
		else:
			chart_data = {"notes": [], "events": [], "offset_corrected": true}
	else:
		chart_data = {"notes": [], "events": [], "offset_corrected": true}
		
	_sort_chart()

func _sort_chart() -> void:
	if chart_data.has("notes") and chart_data["notes"] is Array:
		chart_data["notes"].sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))

func _save_chart_file() -> void:
	_sort_chart()
	var path = MUSIC_BASE_PATH + selected_song + "/chart.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(chart_data, "\t")
		file.store_string(json_str)
		file.close()
		_show_toast("Chart Auto-Saved!")

func _save_resources() -> void:
	var res_path = MUSIC_BASE_PATH + selected_song + "/Res.tres"
	if FileAccess.file_exists(res_path):
		var music_res = load(res_path)
		if music_res:
			music_res.set("bpm", int(bpm))
			music_res.set("offset", offset)
			ResourceSaver.save(music_res, res_path)
			_show_toast("BPM & Offset Saved!")

func _show_toast(message: String) -> void:
	toast_label.text = message
	var tween = create_tween()
	toast.modulate.a = 1.0
	tween.tween_interval(1.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.4)

func _process(delta: float) -> void:
	if is_playing:
		if audio_player.playing:
			current_time = audio_player.get_playback_position()
		else:
			# 오디오 스트림이 끝나거나 없는 경우
			current_time += delta * playback_speed
			if current_time >= song_duration:
				current_time = song_duration
				_on_play_pressed() # 정지
	
	# 시간 초과 보정
	if current_time < 0:
		current_time = 0.0
		
	# 시간 표시 갱신
	_update_time_label()
	
	# 구간 재생 루프 및 정지 처리
	if is_playing and is_playing_region and region_end_time > 0.0:
		if current_time >= region_end_time:
			if is_region_loop:
				_seek_time(region_start_time)
			else:
				if is_playing:
					_on_play_pressed()
				is_playing_region = false
				_show_toast("Region Completed")
	
	# 자동 저장 타이머 처리
	autosave_timer += delta
	if autosave_timer >= 60.0:
		autosave_timer = 0.0
		_auto_save_backup()
		
	# 오토플레이 히트 및 이펙트 처리
	if is_playing and is_autoplay:
		var notes = chart_data.get("notes", [])
		for i in range(notes.size()):
			var note = notes[i]
			var note_time = float(note.get("time", 0.0))
			if current_time >= note_time and current_time < note_time + 0.15:
				if not autoplay_hit_notes.has(i):
					autoplay_hit_notes[i] = true
					Global.play_hit_sound()
					_trigger_autoplay_hit_effect(note)
					
	# 오토플레이 리플 수명 갱신
	for i in range(autoplay_ripples.size() - 1, -1, -1):
		autoplay_ripples[i]["life"] -= delta
		if autoplay_ripples[i]["life"] <= 0.0:
			autoplay_ripples.remove_at(i)
	
	# 캔버스 및 타임라인 갱신
	preview_canvas.queue_redraw()
	timeline.queue_redraw()

func _update_time_label() -> void:
	var cur_min = int(current_time) / 60
	var cur_sec = int(current_time) % 60
	var cur_ms = int((current_time - int(current_time)) * 1000)
	
	var total_min = int(song_duration) / 60
	var total_sec = int(song_duration) % 60
	var total_ms = int((song_duration - int(song_duration)) * 1000)
	
	time_label.text = "%02d:%02d.%03d / %02d:%02d.%03d" % [cur_min, cur_sec, cur_ms, total_min, total_sec, total_ms]

# ==========================================
# 스냅 연산
# ==========================================
func get_snapped_time(raw_time: float) -> float:
	if snap_division <= 1:
		return max(0.0, raw_time)
	var beat_length = 60.0 / bpm
	var step = beat_length * (4.0 / snap_division)
	var snapped: float = round(raw_time / step) * step
	return max(0.0, snapped)

# ==========================================
# 입력 콜백 및 이벤트
# ==========================================
func _input(event: InputEvent) -> void:
	# ESC 누르면 메인 메뉴로 나가기
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_playing:
			audio_player.stop()
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return
		
	# Space 누르면 재생 / 정지
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner == null or not (focus_owner is LineEdit):
			get_viewport().set_input_as_handled()
			_on_play_pressed()
			return
			
	# --- 편의 기능 단축키 모음 ---
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner == null or not (focus_owner is LineEdit):
			# A. 북마크 기능 (Alt+1~5 저장, 1~5 이동)
			var code_val = event.keycode
			if code_val >= KEY_1 and code_val <= KEY_5:
				var idx = code_val - KEY_0
				var is_alt = false
				if event is InputEventWithModifiers:
					is_alt = event.alt_pressed
				
				if is_alt:
					get_viewport().set_input_as_handled()
					bookmarks[idx] = current_time
					_show_toast("Bookmark %d set at %.2fs" % [idx, current_time])
					return
				else:
					if bookmarks.has(idx):
						get_viewport().set_input_as_handled()
						_seek_time(bookmarks[idx])
						_show_toast("Jumped to Bookmark %d" % idx)
						return
						
			# B. 노트 미러링 (H: 좌우 반전, V: 상하 반전)
			elif selected_note_index != -1 and code_val == KEY_H:
				get_viewport().set_input_as_handled()
				save_state_for_undo()
				var note = chart_data["notes"][selected_note_index]
				note["x"] = 1920.0 - float(note.get("x", 960.0))
				if note.get("type", "normal") == "moving":
					if note.has("start_x"):
						note["start_x"] = 1920.0 - float(note["start_x"])
					if note.has("curve_control_x"):
						note["curve_control_x"] = 1920.0 - float(note["curve_control_x"])
					if start_x_input: start_x_input.text = "%.1f" % float(note.get("start_x", note["x"]))
				_save_chart_file()
				_show_toast("Mirrored Horizontally")
				preview_canvas.queue_redraw()
				return
				
			elif selected_note_index != -1 and code_val == KEY_V:
				get_viewport().set_input_as_handled()
				save_state_for_undo()
				var note = chart_data["notes"][selected_note_index]
				note["y"] = 1080.0 - float(note.get("y", 540.0))
				if note.get("type", "normal") == "moving":
					if note.has("start_y"):
						note["start_y"] = 1080.0 - float(note["start_y"])
					if note.has("curve_control_y"):
						note["curve_control_y"] = 1080.0 - float(note["curve_control_y"])
					if start_y_input: start_y_input.text = "%.1f" % float(note.get("start_y", note["y"] + 300.0))
				_save_chart_file()
				_show_toast("Mirrored Vertically")
				preview_canvas.queue_redraw()
				return
				
			# C. 선택된 노트 시간 미세 이동 (PageUp: 한 스냅 비트 뒤로, PageDown: 한 스냅 비트 앞으로)
			elif selected_note_index != -1 and code_val == KEY_PAGEUP:
				get_viewport().set_input_as_handled()
				save_state_for_undo()
				var note = chart_data["notes"][selected_note_index]
				var beat_length = 60.0 / bpm
				var step = beat_length * (4.0 / snap_division)
				note["time"] = max(0.0, float(note.get("time", 0.0)) - step)
				_sort_chart()
				selected_note_index = chart_data["notes"].find(note)
				_save_chart_file()
				_show_toast("Shifted Note Backward")
				preview_canvas.queue_redraw()
				timeline.queue_redraw()
				return
				
			elif selected_note_index != -1 and code_val == KEY_PAGEDOWN:
				get_viewport().set_input_as_handled()
				save_state_for_undo()
				var note = chart_data["notes"][selected_note_index]
				var beat_length = 60.0 / bpm
				var step = beat_length * (4.0 / snap_division)
				note["time"] = float(note.get("time", 0.0)) + step
				_sort_chart()
				selected_note_index = chart_data["notes"].find(note)
				_save_chart_file()
				_show_toast("Shifted Note Forward")
				preview_canvas.queue_redraw()
				timeline.queue_redraw()
				return
				
			# D. 재생 배속 단축키 ([ : 감속, ] : 가속)
			elif code_val == KEY_BRACKETLEFT:
				get_viewport().set_input_as_handled()
				var new_sel = max(0, speed_select.selected - 1)
				if new_sel != speed_select.selected:
					speed_select.selected = new_sel
					_on_speed_selected(new_sel)
					_show_toast("Speed: %s" % speed_select.get_item_text(new_sel))
				return
				
			# E. 즉시 테스트 단축키 (F5)
			elif code_val == KEY_F5:
				get_viewport().set_input_as_handled()
				_on_instant_test_pressed()
				return
			
			elif code_val == KEY_BRACKETLEFT:
				get_viewport().set_input_as_handled()
				var new_sel = max(0, speed_select.selected - 1)
				if new_sel != speed_select.selected:
					speed_select.selected = new_sel
					_on_speed_selected(new_sel)
					_show_toast("Speed: %s" % speed_select.get_item_text(new_sel))
				return
				
			elif code_val == KEY_BRACKETRIGHT:
				get_viewport().set_input_as_handled()
				var new_sel = min(speed_select.item_count - 1, speed_select.selected + 1)
				if new_sel != speed_select.selected:
					speed_select.selected = new_sel
					_on_speed_selected(new_sel)
					_show_toast("Speed: %s" % speed_select.get_item_text(new_sel))
				return

	# Ctrl 단축키 처리 (Undo / Redo / Copy / Paste)
	if event is InputEventKey and event.pressed and not event.echo:
		var is_ctrl = false
		if event is InputEventWithModifiers:
			is_ctrl = event.ctrl_pressed
		
		if is_ctrl:
			if event.keycode == KEY_Z:
				get_viewport().set_input_as_handled()
				perform_undo()
				return
			elif event.keycode == KEY_Y:
				get_viewport().set_input_as_handled()
				perform_redo()
				return
			elif event.keycode == KEY_C:
				if selected_note_index != -1:
					get_viewport().set_input_as_handled()
					var note = chart_data["notes"][selected_note_index]
					copied_note_data = note.duplicate(true)
					_show_toast("Note Copied")
					return
			elif event.keycode == KEY_V:
				if not copied_note_data.is_empty():
					get_viewport().set_input_as_handled()
					save_state_for_undo()
					var new_note = copied_note_data.duplicate(true)
					new_note["time"] = get_snapped_time(current_time)
					chart_data["notes"].append(new_note)
					_save_chart_file()
					selected_note_index = chart_data["notes"].find(new_note)
					_show_toast("Note Pasted")
					preview_canvas.queue_redraw()
					return

	# 선택된 노트 미세 이동 (WASD / Shift+WASD)
	if selected_note_index != -1 and event is InputEventKey and event.pressed:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner == null or not (focus_owner is LineEdit):
			var step_size = 1.0
			if event is InputEventWithModifiers and event.shift_pressed:
				step_size = 10.0
				
			var move_vec = Vector2.ZERO
			match event.keycode:
				KEY_W: move_vec.y = -step_size
				KEY_S: move_vec.y = step_size
				KEY_A: move_vec.x = -step_size
				KEY_D: move_vec.x = step_size
				
			if move_vec != Vector2.ZERO:
				get_viewport().set_input_as_handled()
				if not event.echo:
					save_state_for_undo()
				var note = chart_data["notes"][selected_note_index]
				var new_x = float(note.get("x", 960.0)) + move_vec.x
				var new_y = float(note.get("y", 540.0)) + move_vec.y
				
				if note.get("type", "normal") == "moving":
					var dx = new_x - float(note.get("x", 960.0))
					var dy = new_y - float(note.get("y", 540.0))
					if note.has("start_x"):
						note["start_x"] = float(note["start_x"]) + dx
					if note.has("start_y"):
						note["start_y"] = float(note["start_y"]) + dy
					if start_x_input: start_x_input.text = "%.1f" % float(note.get("start_x", new_x))
					if start_y_input: start_y_input.text = "%.1f" % float(note.get("start_y", new_y + 300.0))
					
				note["x"] = new_x
				note["y"] = new_y
				_save_chart_file()
				preview_canvas.queue_redraw()
				return

	# 방향키 좌우 이동 (시간 탐색)
	if event is InputEventKey and event.pressed:
		var step = 0.1
		var is_ctrl = false
		if event is InputEventWithModifiers:
			is_ctrl = event.ctrl_pressed
		
		if is_ctrl:
			var beat_length = 60.0 / bpm
			step = beat_length * (4.0 / snap_division)
			
		if event.keycode == KEY_LEFT:
			get_viewport().set_input_as_handled()
			var target = current_time - step
			if is_ctrl:
				target = get_snapped_time(target - 0.001)
			_seek_time(target)
		elif event.keycode == KEY_RIGHT:
			get_viewport().set_input_as_handled()
			var target = current_time + step
			if is_ctrl:
				target = get_snapped_time(target + 0.001)
			_seek_time(target)
			
	# Delete 키 누르면 선택된 노트 삭제
	if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		if selected_note_index != -1:
			get_viewport().set_input_as_handled()
			save_state_for_undo()
			_delete_note(selected_note_index)

	# 드래그 중인 동안에는 마우스의 위치가 어디든 최우선으로 드래그 이동과 릴리즈를 처리
	if is_dragging_note and selected_note_index != -1 and (event is InputEventMouseMotion or event is InputEventMouseButton):
		var global_pos = event.global_position
		var local_pos = preview_canvas.get_global_transform().affine_inverse() * global_pos
		var canvas_w = preview_canvas.size.x
		var canvas_h = preview_canvas.size.y
		if canvas_w > 0.0 and canvas_h > 0.0:
			var logical_pos := Vector2(
				local_pos.x * (1920.0 / canvas_w),
				local_pos.y * (1080.0 / canvas_h)
			)
			
			if event is InputEventMouseMotion:
				var note = chart_data["notes"][selected_note_index]
				var old_x = float(note.get("x", 960.0))
				var old_y = float(note.get("y", 540.0))
				
				var new_x = logical_pos.x - drag_offset.x
				var new_y = logical_pos.y - drag_offset.y
				
				note["x"] = new_x
				note["y"] = new_y
				
				if note.get("type", "normal") == "moving":
					var dx = new_x - old_x
					var dy = new_y - old_y
					if note.has("start_x"):
						note["start_x"] = float(note["start_x"]) + dx
						if note.has("start_y"):
							note["start_y"] = float(note["start_y"]) + dy
					if start_x_input: start_x_input.text = "%.1f" % float(note.get("start_x", new_x))
					if start_y_input: start_y_input.text = "%.1f" % float(note.get("start_y", new_y + 300.0))
					
				preview_canvas.queue_redraw()
				get_viewport().set_input_as_handled()
				return
				
			elif event is InputEventMouseButton:
				if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					is_dragging_note = false
					_save_chart_file()
					preview_canvas.queue_redraw()
					get_viewport().set_input_as_handled()
					return

	# 캔버스 밖 영역(여백) 마우스 입력 처리 (화면 밖 생성 및 삭제 지원)
	var canvas_container = get_node_or_null("Split/MainArea/CanvasContainer") as Control
	if canvas_container and (event is InputEventMouseButton or event is InputEventMouseMotion):
		var global_pos = event.global_position
		# 마우스가 CanvasContainer 내부이되 PreviewCanvas 외부인 경우
		if canvas_container.get_global_rect().has_point(global_pos) and not preview_canvas.get_global_rect().has_point(global_pos):
			var local_pos = preview_canvas.get_global_transform().affine_inverse() * global_pos
			var canvas_w = preview_canvas.size.x
			var canvas_h = preview_canvas.size.y
			if canvas_w > 0.0 and canvas_h > 0.0:
				var logical_pos = Vector2(
					local_pos.x * (1920.0 / canvas_w),
					local_pos.y * (1080.0 / canvas_h)
				)
				
				if event is InputEventMouseMotion:
					if not is_dragging_note:
						_update_hover_note(logical_pos)
						
				elif event is InputEventMouseButton:
					if event.pressed:
						var snapped_time = get_snapped_time(current_time)
						
						if event.button_index == MOUSE_BUTTON_LEFT:
							if is_setting_start_pos and selected_note_index != -1:
								var note = chart_data["notes"][selected_note_index]
								note["start_x"] = logical_pos.x
								note["start_y"] = logical_pos.y
								if start_x_input: start_x_input.text = "%.1f" % logical_pos.x
								if start_y_input: start_y_input.text = "%.1f" % logical_pos.y
								if set_start_btn: set_start_btn.button_pressed = false
								_save_chart_file()
								preview_canvas.queue_redraw()
							else:
								if hover_note_index != -1:
									selected_note_index = hover_note_index
									_show_toast("Note Selected")
									
									is_dragging_note = true
									var note = chart_data["notes"][selected_note_index]
									drag_offset = logical_pos - Vector2(float(note.get("x", 960.0)), float(note.get("y", 540.0)))
									save_state_for_undo()
									
									var note_type = note.get("type", "normal")
									if note_type == "normal":
										type_select.selected = 0
										selected_type = "normal"
										hold_settings.visible = false
										if moving_settings: moving_settings.visible = false
									elif note_type == "moving":
										type_select.selected = 1
										selected_type = "moving"
										hold_settings.visible = false
										if moving_settings: moving_settings.visible = true
										if start_x_input: start_x_input.text = "%.1f" % float(note.get("start_x", note.get("x", 960.0)))
										if start_y_input: start_y_input.text = "%.1f" % float(note.get("start_y", float(note.get("y", 540.0)) + 300.0))
									elif note_type == "hold":
										type_select.selected = 2
										selected_type = "hold"
										hold_settings.visible = true
										if moving_settings: moving_settings.visible = false
										hold_duration = float(note.get("duration", 3.0))
										hold_division = int(note.get("beat_division", 16))
										duration_input.text = str(hold_duration)
										division_input.text = str(hold_division)
									preview_canvas.queue_redraw()
								else:
									_add_note(snapped_time, logical_pos)
									
						elif event.button_index == MOUSE_BUTTON_RIGHT:
							if hover_note_index != -1:
								_delete_note(hover_note_index)
					else:
						if event.button_index == MOUSE_BUTTON_LEFT and is_dragging_note:
							is_dragging_note = false
							_save_chart_file()
							preview_canvas.queue_redraw()
		elif not canvas_container.get_global_rect().has_point(global_pos) and not preview_canvas.get_global_rect().has_point(global_pos):
			if hover_note_index != -1:
				hover_note_index = -1
				preview_canvas.queue_redraw()
func _seek_time(target: float) -> void:
	current_time = clamp(target, 0.0, song_duration)
	autoplay_hit_notes.clear()
	if audio_player.playing:
		audio_player.seek(current_time)

func _on_play_pressed() -> void:
	is_playing = not is_playing
	if is_playing:
		play_button.text = "Pause"
		audio_player.pitch_scale = playback_speed
		audio_player.play(current_time)
	else:
		play_button.text = "Play"
		audio_player.stop()
		is_playing_region = false # 수동 정지 시 구간 재생 오프

func _on_song_selected_item(index: int) -> void:
	_on_song_selected(index)

func _on_snap_selected(index: int) -> void:
	var metadata = snap_select.get_item_id(index)
	snap_division = metadata
	timeline.queue_redraw()

func _on_type_selected(index: int) -> void:
	match index:
		0:
			selected_type = "normal"
			hold_settings.visible = false
			if moving_settings: moving_settings.visible = false
		1:
			selected_type = "moving"
			hold_settings.visible = false
			if moving_settings: moving_settings.visible = true
		2:
			selected_type = "hold"
			hold_settings.visible = true
			if moving_settings: moving_settings.visible = false
			
	duration_input.text = str(hold_duration)
	division_input.text = str(hold_division)

func _on_speed_selected(index: int) -> void:
	match index:
		0: playback_speed = 0.5
		1: playback_speed = 0.75
		2: playback_speed = 1.0
		3: playback_speed = 1.25
		4: playback_speed = 1.5
	
	if audio_player.playing:
		audio_player.pitch_scale = playback_speed

func _on_bpm_submitted(new_text: String) -> void:
	var val = float(new_text)
	if val > 0.0:
		bpm = val
		_save_resources()
		timeline.queue_redraw()
		bpm_input.release_focus()

func _on_offset_submitted(new_text: String) -> void:
	offset = float(new_text)
	_save_resources()
	offset_input.release_focus()

func _on_hold_duration_submitted(new_text: String) -> void:
	var val = float(new_text)
	if val > 0.0:
		hold_duration = val
		duration_input.release_focus()

func _on_hold_division_submitted(new_text: String) -> void:
	var val = int(new_text)
	if val > 0:
		hold_division = val
		division_input.release_focus()

# ==========================================
# 캔버스 2D 조작
# ==========================================
func _on_canvas_gui_input(event: InputEvent) -> void:
	# --- 구간(Region) 선택 영역 및 경계 렌더링 ---
	if region_start_time >= 0.0 and region_end_time >= 0.0 and region_end_time > region_start_time:
		var dx_start = (region_start_time - current_time) * pixels_per_second
		var dx_end = (region_end_time - current_time) * pixels_per_second
		var lx_start = center_x + dx_start
		var lx_end = center_x + dx_end
		
		var rx_start = clamp(lx_start, 0.0, timeline_w)
		var rx_end = clamp(lx_end, 0.0, timeline_w)
		
		if rx_end > rx_start:
			# 반투명 딥 와인 색상으로 영역을 그림
			var overlay_rect = Rect2(Vector2(rx_start, 0.0), Vector2(rx_end - rx_start, timeline_h))
			timeline.draw_rect(overlay_rect, Color(0.788235, 0.0941176, 0.290196, 0.22), true)
			
			# 경계선 점선/실선 렌더링
			timeline.draw_line(Vector2(lx_start, 0.0), Vector2(lx_start, timeline_h), Color(0.788235, 0.0941176, 0.290196, 0.8), 2.0)
			timeline.draw_line(Vector2(lx_end, 0.0), Vector2(lx_end, timeline_h), Color(0.788235, 0.0941176, 0.290196, 0.8), 2.0)
			
			# 시작/종료 시간 텍스트 표기
			var r_font = get_theme_font("font")
			if lx_start >= 0.0 and lx_start <= timeline_w:
				timeline.draw_string(r_font, Vector2(lx_start + 4, timeline_h - 6), "[Start", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.788235, 0.0941176, 0.290196, 0.8))
			if lx_end >= 0.0 and lx_end <= timeline_w:
				timeline.draw_string(r_font, Vector2(lx_end - 45, timeline_h - 6), "End]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.788235, 0.0941176, 0.290196, 0.8))

	if not chart_data.has("notes"): return
	
	var canvas_w = preview_canvas.size.x
	var canvas_h = preview_canvas.size.y
	if canvas_w == 0 or canvas_h == 0: return
	
	var local_pos: Vector2 = event.position
	var logical_pos = Vector2(
		local_pos.x * (1920.0 / canvas_w),
		local_pos.y * (1080.0 / canvas_h)
	)
	
	if event is InputEventMouseMotion:
		# 곡선 드래그 모드: 실시간 제어점 업데이트
		if is_curve_draw_mode and is_curve_dragging:
			curve_drag_current = logical_pos
			var seg = curve_drag_end - curve_drag_start
			var seg_len = seg.length()
			if seg_len > 0.01:
				var seg_norm = seg / seg_len
				var to_mouse = logical_pos - curve_drag_start
				var proj = to_mouse.dot(seg_norm)
				var closest = curve_drag_start + seg_norm * clamp(proj, 0.0, seg_len)
				var deviation = logical_pos.distance_to(closest)
				var cross = seg.x * to_mouse.y - seg.y * to_mouse.x
				var side_v = sign(cross) if abs(cross) > 0.01 else 1.0
				if deviation > curve_drag_max_deviation:
					curve_drag_max_deviation = deviation
					curve_drag_side = side_v
			preview_canvas.queue_redraw()
			return
		if is_dragging_note and selected_note_index != -1:
			var note = chart_data["notes"][selected_note_index]
			var old_x = float(note.get("x", 960.0))
			var old_y = float(note.get("y", 540.0))
			
			var new_x = logical_pos.x - drag_offset.x
			var new_y = logical_pos.y - drag_offset.y
			
			note["x"] = new_x
			note["y"] = new_y
			
			if note.get("type", "normal") == "moving":
				var dx = new_x - old_x
				var dy = new_y - old_y
				if note.has("start_x"):
					note["start_x"] = float(note["start_x"]) + dx
				if note.has("start_y"):
					note["start_y"] = float(note["start_y"]) + dy
				if start_x_input: start_x_input.text = "%.1f" % float(note.get("start_x", new_x))
				if start_y_input: start_y_input.text = "%.1f" % float(note.get("start_y", new_y + 300.0))
				
			preview_canvas.queue_redraw()
		else:
			_update_hover_note(logical_pos)
		
	if event is InputEventMouseButton:
		if event.pressed:
			var snapped_time = get_snapped_time(current_time)
			
			if event.button_index == MOUSE_BUTTON_LEFT:
				if is_curve_draw_mode and selected_note_index != -1:
					is_curve_dragging = true
					var c_note = chart_data["notes"][selected_note_index]
					curve_drag_start = Vector2(float(c_note.get("start_x", c_note.get("x", 960.0))), float(c_note.get("start_y", float(c_note.get("y", 540.0)) + 300.0)))
					curve_drag_end = Vector2(float(c_note.get("x", 960.0)), float(c_note.get("y", 540.0)))
					curve_drag_current = logical_pos
					curve_drag_max_deviation = 0.0
					curve_drag_side = 1.0
					preview_canvas.queue_redraw()
					return
				if is_setting_start_pos and selected_note_index != -1:
					var note = chart_data["notes"][selected_note_index]
					note["start_x"] = logical_pos.x
					note["start_y"] = logical_pos.y
					if start_x_input: start_x_input.text = "%.1f" % logical_pos.x
					if start_y_input: start_y_input.text = "%.1f" % logical_pos.y
					if set_start_btn: set_start_btn.button_pressed = false
					_save_chart_file()
					preview_canvas.queue_redraw()
					return
					
				if hover_note_index != -1:
					selected_note_index = hover_note_index
					_show_toast("Note Selected")
					
					is_dragging_note = true
					var note = chart_data["notes"][selected_note_index]
					drag_offset = logical_pos - Vector2(float(note.get("x", 960.0)), float(note.get("y", 540.0)))
					save_state_for_undo()
					
					var note_type = note.get("type", "normal")
					if note_type == "normal":
						type_select.selected = 0
						selected_type = "normal"
						hold_settings.visible = false
						if moving_settings: moving_settings.visible = false
					elif note_type == "moving":
						type_select.selected = 1
						selected_type = "moving"
						hold_settings.visible = false
						if moving_settings: moving_settings.visible = true
						if start_x_input: start_x_input.text = "%.1f" % float(note.get("start_x", note.get("x", 960.0)))
						if start_y_input: start_y_input.text = "%.1f" % float(note.get("start_y", float(note.get("y", 540.0)) + 300.0))
						if use_gravity_check: use_gravity_check.button_pressed = note.get("use_gravity", false)
						if moving_duration_input:
							moving_duration = float(note.get("move_duration", 1.0))
							moving_duration_input.text = "%.1f" % moving_duration
					elif note_type == "hold":
						type_select.selected = 2
						selected_type = "hold"
						hold_settings.visible = true
						if moving_settings: moving_settings.visible = false
						hold_duration = float(note.get("duration", 3.0))
						hold_division = int(note.get("beat_division", 16))
						duration_input.text = str(hold_duration)
						division_input.text = str(hold_division)
					preview_canvas.queue_redraw()
				else:
					_add_note(snapped_time, logical_pos)
					
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if hover_note_index != -1:
					_delete_note(hover_note_index)
		else:
			if event.button_index == MOUSE_BUTTON_LEFT and is_curve_dragging:
				is_curve_dragging = false
				if selected_note_index != -1 and curve_drag_max_deviation > 5.0:
					save_state_for_undo()
					var c_note2 = chart_data["notes"][selected_note_index]
					var control = _calculate_bezier_control_from_drag(curve_drag_start, curve_drag_end, curve_drag_max_deviation, curve_drag_side)
					c_note2["curve_control_x"] = control.x
					c_note2["curve_control_y"] = control.y
					_save_chart_file()
					_show_toast("Curve Saved!")
				elif selected_note_index != -1:
					var c_note3 = chart_data["notes"][selected_note_index]
					c_note3.erase("curve_control_x")
					c_note3.erase("curve_control_y")
					_save_chart_file()
					_show_toast("Linear Path Set")
				preview_canvas.queue_redraw()
			elif event.button_index == MOUSE_BUTTON_LEFT and is_dragging_note:
				is_dragging_note = false
				_save_chart_file()
				preview_canvas.queue_redraw()

func _update_hover_note(logical_pos: Vector2) -> void:
	hover_note_index = -1
	# --- 구간(Region) 선택 영역 및 경계 렌더링 ---
	if region_start_time >= 0.0 and region_end_time >= 0.0 and region_end_time > region_start_time:
		var dx_start = (region_start_time - current_time) * pixels_per_second
		var dx_end = (region_end_time - current_time) * pixels_per_second
		var lx_start = center_x + dx_start
		var lx_end = center_x + dx_end
		
		var rx_start = clamp(lx_start, 0.0, timeline_w)
		var rx_end = clamp(lx_end, 0.0, timeline_w)
		
		if rx_end > rx_start:
			# 반투명 딥 와인 색상으로 영역을 그림
			var overlay_rect = Rect2(Vector2(rx_start, 0.0), Vector2(rx_end - rx_start, timeline_h))
			timeline.draw_rect(overlay_rect, Color(0.788235, 0.0941176, 0.290196, 0.22), true)
			
			# 경계선 점선/실선 렌더링
			timeline.draw_line(Vector2(lx_start, 0.0), Vector2(lx_start, timeline_h), Color(0.788235, 0.0941176, 0.290196, 0.8), 2.0)
			timeline.draw_line(Vector2(lx_end, 0.0), Vector2(lx_end, timeline_h), Color(0.788235, 0.0941176, 0.290196, 0.8), 2.0)
			
			# 시작/종료 시간 텍스트 표기
			var r_font = get_theme_font("font")
			if lx_start >= 0.0 and lx_start <= timeline_w:
				timeline.draw_string(r_font, Vector2(lx_start + 4, timeline_h - 6), "[Start", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.788235, 0.0941176, 0.290196, 0.8))
			if lx_end >= 0.0 and lx_end <= timeline_w:
				timeline.draw_string(r_font, Vector2(lx_end - 45, timeline_h - 6), "End]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.788235, 0.0941176, 0.290196, 0.8))

	if not chart_data.has("notes"): return
	
	var threshold = 40.0
	var notes: Array = chart_data["notes"]
	var time_window = 0.4
	
	for i in range(notes.size()):
		var note: Dictionary = notes[i]
		var note_time = float(note.get("time", 0.0))
		var note_type = str(note.get("type", "normal"))
		
		if absf(note_time - current_time) > time_window:
			continue
			
		if note_type == "hold":
			var dist = logical_pos.distance_to(Vector2(960, 540))
			if dist < threshold + 20.0:
				hover_note_index = i
				return
		else:
			var nx = float(note.get("x", 960.0))
			var ny = float(note.get("y", 540.0))
			var nx_clamped = clamp(nx, 0.0, 1920.0)
			var ny_clamped = clamp(ny, 0.0, 1080.0)
			var dist = logical_pos.distance_to(Vector2(nx_clamped, ny_clamped))
			if dist < threshold:
				hover_note_index = i
				return

func _add_note(time_val: float, logical_pos: Vector2) -> void:
	save_state_for_undo()
	var note_node = {}
	note_node["time"] = time_val
	note_node["type"] = selected_type
	
	if selected_type == "hold":
		note_node["duration"] = hold_duration
		note_node["beat_division"] = hold_division
	elif selected_type == "moving":
		note_node["x"] = logical_pos.x
		note_node["y"] = logical_pos.y
		note_node["start_x"] = note_node["x"]
		note_node["start_y"] = note_node["y"] + 300.0
		note_node["move_duration"] = moving_duration
		note_node["use_gravity"] = use_gravity_check.button_pressed if use_gravity_check else false
	else:
		note_node["x"] = logical_pos.x
		note_node["y"] = logical_pos.y
		
	chart_data["notes"].append(note_node)
	_save_chart_file()
	
	selected_note_index = chart_data["notes"].find(note_node)
	if selected_type == "moving":
		if start_x_input: start_x_input.text = "%.1f" % note_node["start_x"]
		if start_y_input: start_y_input.text = "%.1f" % note_node["start_y"]
		if moving_duration_input: moving_duration_input.text = "%.1f" % moving_duration
		if use_gravity_check: use_gravity_check.button_pressed = note_node.get("use_gravity", false)
		if moving_settings: moving_settings.visible = true
		
	_update_hover_note(logical_pos)
	preview_canvas.queue_redraw()

func _delete_note(index: int) -> void:
	if index >= 0 and index < chart_data["notes"].size():
		save_state_for_undo()
		chart_data["notes"].remove_at(index)
		selected_note_index = -1
		hover_note_index = -1
		_save_chart_file()
		preview_canvas.queue_redraw()
		timeline.queue_redraw()

# ==========================================
# 타임라인 조작
# ==========================================
func _on_timeline_gui_input(event: InputEvent) -> void:
	var timeline_w = timeline.size.x
	if timeline_w == 0: return
	
	var pixels_per_second = 150.0 * timeline_zoom
	
	# Shift + 드래그를 이용한 구간 마우스 지정 처리
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed:
			var local_x: float = event.position.x
			var dx = local_x - (timeline_w / 2.0)
			var dt = dx / pixels_per_second
			var target_time = clamp(current_time + dt, 0.0, song_duration)
			
			if event.pressed:
				is_dragging_region = true
				drag_start_time = target_time
				region_start_time = target_time
				region_end_time = target_time
			else:
				is_dragging_region = false
				_save_chart_file()
				_update_region_ui()
			timeline.queue_redraw()
			get_viewport().set_input_as_handled()
			return
			
	if event is InputEventMouseMotion and is_dragging_region:
		var local_x: float = event.position.x
		var dx = local_x - (timeline_w / 2.0)
		var dt = dx / pixels_per_second
		var target_time = clamp(current_time + dt, 0.0, song_duration)
		
		region_start_time = min(drag_start_time, target_time)
		region_end_time = max(drag_start_time, target_time)
		_update_region_ui()
		timeline.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			timeline_zoom = min(4.0, timeline_zoom + 0.1)
			timeline.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			timeline_zoom = max(0.4, timeline_zoom - 0.1)
			timeline.queue_redraw()
			get_viewport().set_input_as_handled()
			return
	
	if event is InputEventMouseButton and event.pressed:
		var local_x: float = event.position.x
		var dx = local_x - (timeline_w / 2.0)
		var dt = dx / pixels_per_second
		var target_time = current_time + dt
		
		var is_ctrl = false
		if event is InputEventWithModifiers:
			is_ctrl = event.ctrl_pressed
		if is_ctrl:
			target_time = get_snapped_time(target_time)
			
		_seek_time(target_time)

# ==========================================
# 핑크 테마 렌더링 (_draw)
# ==========================================
func _draw_preview_canvas() -> void:
	var canvas_w = preview_canvas.size.x
	var canvas_h = preview_canvas.size.y
	if canvas_w == 0 or canvas_h == 0: return
	
	var sx = canvas_w / 1920.0
	var sy = canvas_h / 1080.0
	
	# 캔버스 핑크 배경 및 핑크 에스테틱 테두리
	preview_canvas.draw_rect(Rect2(Vector2.ZERO, preview_canvas.size), COLOR_BG_CANVAS, true)
	preview_canvas.draw_rect(Rect2(Vector2.ZERO, preview_canvas.size), COLOR_BORDER_CANVAS, false, 2.0 * sx)
	
	# 핑크 십자 가선
	preview_canvas.draw_line(Vector2(canvas_w/2, 0), Vector2(canvas_w/2, canvas_h), COLOR_GRID_CANVAS, 1.0)
	preview_canvas.draw_line(Vector2(0, canvas_h/2), Vector2(canvas_w, canvas_h/2), COLOR_GRID_CANVAS, 1.0)
	
	# --- 구간(Region) 선택 영역 및 경계 렌더링 ---
	if region_start_time >= 0.0 and region_end_time >= 0.0 and region_end_time > region_start_time:
		var dx_start = (region_start_time - current_time) * pixels_per_second
		var dx_end = (region_end_time - current_time) * pixels_per_second
		var lx_start = center_x + dx_start
		var lx_end = center_x + dx_end
		
		var rx_start = clamp(lx_start, 0.0, timeline_w)
		var rx_end = clamp(lx_end, 0.0, timeline_w)
		
		if rx_end > rx_start:
			# 반투명 딥 와인 색상으로 영역을 그림
			var overlay_rect = Rect2(Vector2(rx_start, 0.0), Vector2(rx_end - rx_start, timeline_h))
			timeline.draw_rect(overlay_rect, Color(0.788235, 0.0941176, 0.290196, 0.22), true)
			
			# 경계선 점선/실선 렌더링
			timeline.draw_line(Vector2(lx_start, 0.0), Vector2(lx_start, timeline_h), Color(0.788235, 0.0941176, 0.290196, 0.8), 2.0)
			timeline.draw_line(Vector2(lx_end, 0.0), Vector2(lx_end, timeline_h), Color(0.788235, 0.0941176, 0.290196, 0.8), 2.0)
			
			# 시작/종료 시간 텍스트 표기
			var r_font = get_theme_font("font")
			if lx_start >= 0.0 and lx_start <= timeline_w:
				timeline.draw_string(r_font, Vector2(lx_start + 4, timeline_h - 6), "[Start", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.788235, 0.0941176, 0.290196, 0.8))
			if lx_end >= 0.0 and lx_end <= timeline_w:
				timeline.draw_string(r_font, Vector2(lx_end - 45, timeline_h - 6), "End]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.788235, 0.0941176, 0.290196, 0.8))

	if not chart_data.has("notes"): return
	
	var notes: Array = chart_data["notes"]
	var time_window = 0.4
	
	for i in range(notes.size()):
		var note: Dictionary = notes[i]
		var note_time = float(note.get("time", 0.0))
		var note_type = str(note.get("type", "normal"))
		
		var diff = note_time - current_time
		if absf(diff) > time_window:
			continue
			
		var alpha: float = 1.0 - (absf(diff) / time_window)
		var color = COLOR_NOTE_NORMAL
		
		match note_type:
			"normal":
				color = COLOR_NOTE_NORMAL
			"moving":
				color = COLOR_NOTE_MOVING
			"hold":
				color = COLOR_NOTE_HOLD
				
		color.a = alpha
		
		var is_hovered = (i == hover_note_index)
		var is_selected = (i == selected_note_index)
		
		if is_selected:
			color = COLOR_NOTE_SELECTED
			color.a = alpha
		elif is_hovered:
			color = color.lightened(0.2)
			color.a = alpha
			
		if note_type == "hold":
			var center = Vector2(canvas_w / 2.0, canvas_h / 2.0)
			var radius = 80.0 * sx
			if is_hovered or is_selected:
				# 핑크 블렌딩 헤일로 링
				preview_canvas.draw_circle(center, radius + 10.0*sx, Color(1.0, 0.301961, 0.427451, alpha * 0.25))
			
			preview_canvas.draw_arc(center, radius, 0.0, TAU, 64, color, 8.0 * sx, true)
			
			var hold_font = get_theme_font("font")
			var text_str = "HOLD (%.1fs)" % float(note.get("duration", 3.0))
			var hold_text_color = COLOR_TEXT_WINE
			hold_text_color.a = alpha * 0.85
			preview_canvas.draw_string(hold_font, center + Vector2(-60.0*sx, 10.0*sy), text_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, hold_text_color)
		else:
			var nx = float(note.get("x", 960.0))
			var ny = float(note.get("y", 540.0))
			var is_offscreen = (nx < 0.0 or nx > 1920.0 or ny < 0.0 or ny > 1080.0)
			
			var rx = clamp(nx, 0.0, 1920.0) * sx
			var ry = clamp(ny, 0.0, 1080.0) * sy
			var pos = Vector2(rx, ry)
			var radius = 25.0 * sx
			
			if is_offscreen:
				var guide_color = color
				if is_selected:
					guide_color = COLOR_NOTE_SELECTED
				elif is_hovered:
					guide_color = color.lightened(0.2)
				guide_color.a = alpha * 0.4
				
				preview_canvas.draw_circle(pos, radius, guide_color)
				preview_canvas.draw_circle(pos, radius - 4.0 * sx, COLOR_BG_CANVAS)
				
				var real_pos_scaled = Vector2(nx * sx, ny * sy)
				var dir = (real_pos_scaled - pos).normalized()
				if dir != Vector2.ZERO:
					preview_canvas.draw_line(pos, pos + dir * 30.0 * sx, guide_color, 4.0 * sx)
					
				var offscreen_font = get_theme_font("font")
				var offscreen_text_color = COLOR_TEXT_WINE
				offscreen_text_color.a = alpha * 0.7
				preview_canvas.draw_string(offscreen_font, pos + Vector2(-12.0 * sx, 4.0 * sy), "OUT", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, offscreen_text_color)
			else:
				if is_hovered or is_selected:
					preview_canvas.draw_circle(pos, radius + 8.0*sx, Color(1.0, 0.301961, 0.427451, alpha * 0.25))
					
				preview_canvas.draw_circle(pos, radius, color)
			
			# 도넛 형태 내부 (가장자리와 대비되는 어두운 핑크 와인 색상)
			var inner_dark_color = COLOR_TEXT_WINE
			inner_dark_color.a = alpha
			preview_canvas.draw_circle(pos, radius - 5.0*sx, inner_dark_color)
			preview_canvas.draw_circle(pos, radius - 10.0*sx, color)
			
			if note_type == "moving":
				var s_x = float(note.get("start_x", note.get("x", 960.0))) * sx
				var s_y = float(note.get("start_y", float(note.get("y", 540.0)) + 300.0)) * sy
				var start_pos_v = Vector2(s_x, s_y)
				var line_color = Color(1.0, 0.458824, 0.560784, alpha * 0.5)
				var has_curve = note.has("curve_control_x") and note.has("curve_control_y")
				var has_gravity = note.get("use_gravity", false)
				
				if has_curve:
					var ctrl_x = float(note["curve_control_x"]) * sx
					var ctrl_y = float(note["curve_control_y"]) * sy
					var ctrl_pos = Vector2(ctrl_x, ctrl_y)
					var curve_segments = 24
					var curve_points_arr = PackedVector2Array()
					for seg_i in range(curve_segments + 1):
						var t_val = float(seg_i) / float(curve_segments)
						var pt = _quadratic_bezier(start_pos_v, ctrl_pos, pos, t_val)
						curve_points_arr.append(pt)
					preview_canvas.draw_polyline(curve_points_arr, line_color, 2.5 * sx, true)
					for dot_i in range(1, 8):
						var t_dot = float(dot_i) / 8.0
						if has_gravity:
							t_dot = t_dot * t_dot
						var dot_pt = _quadratic_bezier(start_pos_v, ctrl_pos, pos, t_dot)
						preview_canvas.draw_circle(dot_pt, 3.5 * sx, Color(1.0, 1.0, 1.0, alpha * 0.6))
					if is_selected:
						var ctrl_color = Color(1.0, 0.8, 0.2, alpha * 0.7)
						preview_canvas.draw_circle(ctrl_pos, 8.0 * sx, ctrl_color)
						preview_canvas.draw_circle(ctrl_pos, 5.0 * sx, COLOR_BG_CANVAS)
						preview_canvas.draw_dashed_line(start_pos_v, ctrl_pos, Color(1.0, 0.8, 0.2, alpha * 0.3), 1.0 * sx)
						preview_canvas.draw_dashed_line(ctrl_pos, pos, Color(1.0, 0.8, 0.2, alpha * 0.3), 1.0 * sx)
				else:
					preview_canvas.draw_line(start_pos_v, pos, line_color, 2.0 * sx)
				preview_canvas.draw_circle(start_pos_v, 12.0 * sx, line_color)
				preview_canvas.draw_circle(start_pos_v, 8.0 * sx, COLOR_BG_CANVAS)
				if is_selected:
					var sel_font = get_theme_font("font")
					preview_canvas.draw_string(sel_font, start_pos_v + Vector2(-4.0 * sx, 4.0 * sy), "S", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, COLOR_TEXT_WINE)
				if has_gravity:
					var grav_font = get_theme_font("font")
					var grav_color = Color(0.4, 0.7, 1.0, alpha * 0.9)
					preview_canvas.draw_string(grav_font, pos + Vector2(15.0 * sx, 25.0 * sy), "G", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, grav_color)
					
				# --- 불가능한 패턴 자동 검출 및 시각 경고 ---
				var warning = _get_note_warnings(i)
				if warning != "":
					var w_font = get_theme_font("font")
					if warning == "SIMULTANEOUS":
						# 동시치기 불가 경고 (빨강)
						preview_canvas.draw_circle(pos, 35.0 * sx, Color(1.0, 0.0, 0.0, alpha * 0.8), 2.5 * sx)
						preview_canvas.draw_string(w_font, pos + Vector2(-45.0 * sx, -40.0 * sy), "⚠️ Double Key", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.3, 0.3, alpha * 0.9))
					elif warning == "TOO_CLOSE":
						# 초고속 피지컬 경고 (오렌지)
						preview_canvas.draw_circle(pos, 32.0 * sx, Color(1.0, 0.5, 0.0, alpha * 0.8), 2.0 * sx)
						preview_canvas.draw_string(w_font, pos + Vector2(-45.0 * sx, -40.0 * sy), "⚠️ Extreme Speed", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.6, 0.2, alpha * 0.9))
					elif warning == "OVERLAP":
						# 겹침 배치 차폐 경고 (노랑)
						preview_canvas.draw_circle(pos, 30.0 * sx, Color(1.0, 0.8, 0.0, alpha * 0.7), 1.5 * sx)
						preview_canvas.draw_string(w_font, pos + Vector2(-45.0 * sx, -40.0 * sy), "⚠️ Hidden Note", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.85, 0.2, alpha * 0.9))
					elif warning == "TOO_FAR":
						# 칠 수 없는 노트 경고 (자주색)
						preview_canvas.draw_circle(pos, 38.0 * sx, Color(0.7, 0.0, 0.7, alpha * 0.9), 3.0 * sx)
						preview_canvas.draw_string(w_font, pos + Vector2(-55.0 * sx, -40.0 * sy), "⚠️ Too Far (Unhittable)", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.9, 0.2, 0.9, alpha * 0.9))
			
			# 텍스트 라벨 (딥 와인 색상)
			var lbl_font = get_theme_font("font")
			var lbl_text_color = COLOR_TEXT_WINE
			lbl_text_color.a = alpha * 0.8
			preview_canvas.draw_string(lbl_font, pos + Vector2(15.0*sx, -15.0*sy), "%.2fs" % note_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, lbl_text_color)


	# --- 오토플레이 리플 효과 렌더링 ---
	for rip in autoplay_ripples:
		var r_pos = rip["pos"] * Vector2(sx, sy)
		var progress = 1.0 - (rip["life"] / 0.3)
		var radius = lerp(15.0, 65.0, progress) * sx
		var rip_color = Color(1.0, 0.0, 0.329412, lerp(0.8, 0.0, progress))
		preview_canvas.draw_circle(r_pos, radius, rip_color, 2.0 * sx)

	# --- 실시간 곡선 드래그 미리보기 렌더링 ---
	if is_curve_draw_mode and is_curve_dragging and selected_note_index != -1:
		var c_note_p = chart_data["notes"][selected_note_index]
		var d_sx = float(c_note_p.get("start_x", c_note_p.get("x", 960.0))) * sx
		var d_sy = float(c_note_p.get("start_y", float(c_note_p.get("y", 540.0)) + 300.0)) * sy
		var d_ex = float(c_note_p.get("x", 960.0)) * sx
		var d_ey = float(c_note_p.get("y", 540.0)) * sy
		var d_start = Vector2(d_sx, d_sy)
		var d_end = Vector2(d_ex, d_ey)
		var pv_ctrl = _calculate_bezier_control_from_drag(curve_drag_start, curve_drag_end, curve_drag_max_deviation, curve_drag_side)
		var pv_ctrl_s = Vector2(pv_ctrl.x * sx, pv_ctrl.y * sy)
		var pv_segs = 30
		var pv_pts = PackedVector2Array()
		for pv_i in range(pv_segs + 1):
			var t_pv = float(pv_i) / float(pv_segs)
			pv_pts.append(_quadratic_bezier(d_start, pv_ctrl_s, d_end, t_pv))
		preview_canvas.draw_polyline(pv_pts, Color(1.0, 0.3, 0.5, 0.7), 3.0 * sx, true)
		preview_canvas.draw_circle(pv_ctrl_s, 10.0 * sx, Color(1.0, 0.85, 0.2, 0.8))
		preview_canvas.draw_circle(pv_ctrl_s, 6.0 * sx, Color(1.0, 1.0, 1.0, 0.9))
		preview_canvas.draw_dashed_line(d_start, pv_ctrl_s, Color(1.0, 0.85, 0.2, 0.4), 1.5 * sx)
		preview_canvas.draw_dashed_line(pv_ctrl_s, d_end, Color(1.0, 0.85, 0.2, 0.4), 1.5 * sx)

func _draw_timeline() -> void:
	var timeline_w: float = timeline.size.x
	var timeline_h: float = timeline.size.y
	if timeline_w == 0 or timeline_h == 0: return
	
	timeline.draw_rect(Rect2(Vector2.ZERO, timeline.size), COLOR_BG_TIMELINE, true)
	timeline.draw_line(Vector2(0, 0), Vector2(timeline_w, 0), COLOR_BORDER_CANVAS, 1.5)
	
	var center_x: float = timeline_w / 2.0
	timeline.draw_line(Vector2(center_x, 0), Vector2(center_x, timeline_h), COLOR_HEADER_TIMELINE, 2.0)
	
	var pixels_per_second: float = 150.0 * timeline_zoom
	var beat_length: float = 60.0 / bpm
	var view_start_time: float = current_time - (center_x / pixels_per_second)
	var view_end_time: float = current_time + (center_x / pixels_per_second)
	
	var first_beat_index: int = ceili(view_start_time / beat_length)
	var last_beat_index: int = floori(view_end_time / beat_length)
	
	if snap_division > 1:
		var snap_step_time: float = beat_length * (4.0 / snap_division)
		var first_snap_idx: int = ceili(view_start_time / snap_step_time)
		var last_snap_idx: int = floori(view_end_time / snap_step_time)
		
		for idx in range(first_snap_idx, last_snap_idx + 1):
			var t: float = idx * snap_step_time
			var dx: float = (t - current_time) * pixels_per_second
			var lx: float = center_x + dx
			
			if absf(fmod(t, beat_length)) < 0.001:
				continue
				
			timeline.draw_line(Vector2(lx, 20), Vector2(lx, timeline_h - 10), COLOR_GRID_TIMELINE_SUB, 1.0)
			
	var font = get_theme_font("font")
	for idx in range(first_beat_index, last_beat_index + 1):
		var t: float = idx * beat_length
		var dx: float = (t - current_time) * pixels_per_second
		var lx: float = center_x + dx
		
		timeline.draw_line(Vector2(lx, 10), Vector2(lx, timeline_h), COLOR_GRID_TIMELINE_MAIN, 1.5)
		
		timeline.draw_string(font, Vector2(lx + 4, 15), str(idx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_TEXT_WINE_MUTED)
	
	# --- 구간(Region) 선택 영역 및 경계 렌더링 ---
	if region_start_time >= 0.0 and region_end_time >= 0.0 and region_end_time > region_start_time:
		var dx_start = (region_start_time - current_time) * pixels_per_second
		var dx_end = (region_end_time - current_time) * pixels_per_second
		var lx_start = center_x + dx_start
		var lx_end = center_x + dx_end
		
		var rx_start = clamp(lx_start, 0.0, timeline_w)
		var rx_end = clamp(lx_end, 0.0, timeline_w)
		
		if rx_end > rx_start:
			# 반투명 딥 와인 색상으로 영역을 그림
			var overlay_rect = Rect2(Vector2(rx_start, 0.0), Vector2(rx_end - rx_start, timeline_h))
			timeline.draw_rect(overlay_rect, Color(0.788235, 0.0941176, 0.290196, 0.22), true)
			
			# 경계선 점선/실선 렌더링
			timeline.draw_line(Vector2(lx_start, 0.0), Vector2(lx_start, timeline_h), Color(0.788235, 0.0941176, 0.290196, 0.8), 2.0)
			timeline.draw_line(Vector2(lx_end, 0.0), Vector2(lx_end, timeline_h), Color(0.788235, 0.0941176, 0.290196, 0.8), 2.0)
			
			# 시작/종료 시간 텍스트 표기
			var r_font = get_theme_font("font")
			if lx_start >= 0.0 and lx_start <= timeline_w:
				timeline.draw_string(r_font, Vector2(lx_start + 4, timeline_h - 6), "[Start", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.788235, 0.0941176, 0.290196, 0.8))
			if lx_end >= 0.0 and lx_end <= timeline_w:
				timeline.draw_string(r_font, Vector2(lx_end - 45, timeline_h - 6), "End]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.788235, 0.0941176, 0.290196, 0.8))

	if not chart_data.has("notes"): return
	
	var notes: Array = chart_data["notes"]
	for i in range(notes.size()):
		var note: Dictionary = notes[i]
		var note_time: float = float(note.get("time", 0.0))
		var note_type: String = str(note.get("type", "normal"))
		
		var dx: float = (note_time - current_time) * pixels_per_second
		var lx: float = center_x + dx
		
		if lx < 0 or lx > timeline_w:
			continue
			
		var color = COLOR_NOTE_NORMAL
		match note_type:
			"normal": color = COLOR_NOTE_NORMAL
			"moving": color = COLOR_NOTE_MOVING
			"hold":   color = COLOR_NOTE_HOLD
			
		if i == selected_note_index:
			color = COLOR_NOTE_SELECTED
			
		var pts = PackedVector2Array([
			Vector2(lx, timeline_h / 2.0 - 10.0),
			Vector2(lx + 8.0, timeline_h / 2.0),
			Vector2(lx, timeline_h / 2.0 + 10.0),
			Vector2(lx - 8.0, timeline_h / 2.0)
		])
		timeline.draw_colored_polygon(pts, color)
		
		if note_type == "hold":
			var duration: float = float(note.get("duration", 3.0))
			var end_dx: float = ((note_time + duration) - current_time) * pixels_per_second
			var end_lx: float = center_x + end_dx
			
			timeline.draw_line(Vector2(lx, timeline_h/2.0), Vector2(clamp(end_lx, 0.0, timeline_w), timeline_h/2.0), Color(0.788235, 0.0941176, 0.290196, 0.5), 4.0)
func _setup_top_bar() -> void:
	top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.custom_minimum_size = Vector2(0, 50)
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(1.0, 0.890196, 0.909804, 1.0)
	style_box.border_width_bottom = 2
	style_box.border_color = Color(1.0, 0.560784, 0.639216, 0.8)
	top_bar.add_theme_stylebox_override("panel", style_box)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_END
	
	var title = Label.new()
	title.text = "WE WANT TO KEYBOARD - CHART EDITOR"
	title.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	title.add_theme_font_size_override("font_size", 16)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)
	
	to_effect_editor_btn = Button.new()
	to_effect_editor_btn.text = "Go to Effect Editor"
	to_effect_editor_btn.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	to_effect_editor_btn.add_theme_font_size_override("font_size", 14)
	
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(1.0, 0.760784, 0.819608, 0.8)
	btn_style_normal.set_corner_radius_all(5)
	btn_style_normal.set_content_margin_all(8)
	
	var btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(1.0, 0.560784, 0.639216, 0.9)
	btn_style_hover.set_corner_radius_all(5)
	btn_style_hover.set_content_margin_all(8)
	
	var btn_style_pressed = StyleBoxFlat.new()
	btn_style_pressed.bg_color = Color(1.0, 0.301961, 0.427451, 1.0)
	btn_style_pressed.set_corner_radius_all(5)
	btn_style_pressed.set_content_margin_all(8)
	
	to_effect_editor_btn.add_theme_stylebox_override("normal", btn_style_normal)
	to_effect_editor_btn.add_theme_stylebox_override("hover", btn_style_hover)
	to_effect_editor_btn.add_theme_stylebox_override("pressed", btn_style_pressed)
	
	to_effect_editor_btn.pressed.connect(_on_go_to_effect_editor)
	hbox.add_child(to_effect_editor_btn)
	
	# 즉시 테스트 (F5) 버튼 추가
	var test_btn = Button.new()
	test_btn.text = "Instant Test (F5)"
	test_btn.add_theme_color_override("font_color", Color.WHITE)
	test_btn.add_theme_font_size_override("font_size", 13)
	var test_btn_style = StyleBoxFlat.new()
	test_btn_style.bg_color = Color(0.788235, 0.0941176, 0.290196, 1.0)
	test_btn_style.set_corner_radius_all(5)
	test_btn_style.set_content_margin_all(8)
	test_btn.add_theme_stylebox_override("normal", test_btn_style)
	test_btn.add_theme_stylebox_override("hover", btn_style_hover)
	test_btn.add_theme_stylebox_override("pressed", btn_style_pressed)
	test_btn.pressed.connect(_on_instant_test_pressed)
	hbox.add_child(test_btn)
	
	# 오토 플레이 버튼 추가
	var autoplay_btn = Button.new()
	autoplay_btn.text = "Auto-Play: OFF"
	autoplay_btn.toggle_mode = true
	autoplay_btn.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	autoplay_btn.add_theme_font_size_override("font_size", 13)
	autoplay_btn.add_theme_stylebox_override("normal", btn_style_normal)
	var play_pressed_style = StyleBoxFlat.new()
	play_pressed_style.bg_color = Color(1.0, 0.7, 0.8, 1.0)
	play_pressed_style.set_corner_radius_all(5)
	play_pressed_style.set_content_margin_all(8)
	autoplay_btn.add_theme_stylebox_override("pressed", play_pressed_style)
	autoplay_btn.toggled.connect(_on_autoplay_toggled)
	hbox.add_child(autoplay_btn)
	
	margin.add_child(hbox)
	top_bar.add_child(margin)
	
	add_child(top_bar)
	
	var split = get_node("Split") as Control
	split.anchor_top = 0.0
	split.offset_top = 50.0

func _on_go_to_effect_editor() -> void:
	if is_playing:
		audio_player.stop()
	get_tree().change_scene_to_file("res://scenes/menu/effect_editor.tscn")

func _setup_moving_settings_ui() -> void:
	moving_settings = VBoxContainer.new()
	moving_settings.name = "MovingSettings"
	moving_settings.visible = false
	
	var label = Label.new()
	label.text = "Moving Note Settings"
	label.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	label.add_theme_font_size_override("font_size", 14)
	moving_settings.add_child(label)
	
	var hbox_x = HBoxContainer.new()
	var lbl_x = Label.new()
	lbl_x.text = "Start X:"
	lbl_x.custom_minimum_size = Vector2(50, 0)
	lbl_x.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	lbl_x.add_theme_font_size_override("font_size", 12)
	hbox_x.add_child(lbl_x)
	start_x_input = LineEdit.new()
	start_x_input.text = "960"
	start_x_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_x_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_x_input.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	start_x_input.text_submitted.connect(_on_start_x_submitted)
	hbox_x.add_child(start_x_input)
	moving_settings.add_child(hbox_x)
	
	var hbox_y = HBoxContainer.new()
	var lbl_y = Label.new()
	lbl_y.text = "Start Y:"
	lbl_y.custom_minimum_size = Vector2(50, 0)
	lbl_y.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	lbl_y.add_theme_font_size_override("font_size", 12)
	hbox_y.add_child(lbl_y)
	start_y_input = LineEdit.new()
	start_y_input.text = "1380"
	start_y_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_y_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_y_input.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	start_y_input.text_submitted.connect(_on_start_y_submitted)
	hbox_y.add_child(start_y_input)
	moving_settings.add_child(hbox_y)
	
	set_start_btn = Button.new()
	set_start_btn.text = "Click Canvas to Set Start"
	set_start_btn.toggle_mode = true
	set_start_btn.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	set_start_btn.add_theme_font_size_override("font_size", 12)
	set_start_btn.toggled.connect(_on_set_start_toggled)
	moving_settings.add_child(set_start_btn)
	
	var sep1 = HSeparator.new()
	moving_settings.add_child(sep1)
	
	var hbox_dur = HBoxContainer.new()
	var lbl_dur = Label.new()
	lbl_dur.text = "Duration:"
	lbl_dur.custom_minimum_size = Vector2(60, 0)
	lbl_dur.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	lbl_dur.add_theme_font_size_override("font_size", 12)
	hbox_dur.add_child(lbl_dur)
	moving_duration_input = LineEdit.new()
	moving_duration_input.text = "1.0"
	moving_duration_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	moving_duration_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moving_duration_input.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	moving_duration_input.text_submitted.connect(_on_moving_duration_submitted)
	hbox_dur.add_child(moving_duration_input)
	var lbl_dur_unit = Label.new()
	lbl_dur_unit.text = "s"
	lbl_dur_unit.add_theme_color_override("font_color", COLOR_TEXT_WINE_MUTED)
	lbl_dur_unit.add_theme_font_size_override("font_size", 12)
	hbox_dur.add_child(lbl_dur_unit)
	moving_settings.add_child(hbox_dur)
	
	use_gravity_check = CheckBox.new()
	use_gravity_check.text = "Use Gravity"
	use_gravity_check.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	use_gravity_check.add_theme_font_size_override("font_size", 12)
	use_gravity_check.toggled.connect(_on_use_gravity_toggled)
	moving_settings.add_child(use_gravity_check)
	
	var sep2 = HSeparator.new()
	moving_settings.add_child(sep2)
	
	draw_curve_btn = Button.new()
	draw_curve_btn.text = "Draw Curve (Drag on Canvas)"
	draw_curve_btn.toggle_mode = true
	draw_curve_btn.add_theme_color_override("font_color", Color.WHITE)
	draw_curve_btn.add_theme_font_size_override("font_size", 12)
	var curve_btn_style = StyleBoxFlat.new()
	curve_btn_style.bg_color = Color(0.788235, 0.0941176, 0.290196, 0.9)
	curve_btn_style.set_corner_radius_all(5)
	curve_btn_style.set_content_margin_all(8)
	draw_curve_btn.add_theme_stylebox_override("normal", curve_btn_style)
	var curve_btn_pressed = StyleBoxFlat.new()
	curve_btn_pressed.bg_color = Color(1.0, 0.0, 0.329412, 1.0)
	curve_btn_pressed.set_corner_radius_all(5)
	curve_btn_pressed.set_content_margin_all(8)
	draw_curve_btn.add_theme_stylebox_override("pressed", curve_btn_pressed)
	var curve_btn_hover = StyleBoxFlat.new()
	curve_btn_hover.bg_color = Color(1.0, 0.301961, 0.427451, 1.0)
	curve_btn_hover.set_corner_radius_all(5)
	curve_btn_hover.set_content_margin_all(8)
	draw_curve_btn.add_theme_stylebox_override("hover", curve_btn_hover)
	draw_curve_btn.toggled.connect(_on_draw_curve_toggled)
	moving_settings.add_child(draw_curve_btn)
	
	var controls_parent = hold_settings.get_parent()
	controls_parent.add_child(moving_settings)
	var hold_idx = hold_settings.get_index()
	controls_parent.move_child(moving_settings, hold_idx + 1)

func _on_start_x_submitted(new_text: String) -> void:
	if selected_note_index != -1:
		var note = chart_data["notes"][selected_note_index]
		note["start_x"] = float(new_text)
		_save_chart_file()
		preview_canvas.queue_redraw()
	if start_x_input: start_x_input.release_focus()

func _on_start_y_submitted(new_text: String) -> void:
	if selected_note_index != -1:
		var note = chart_data["notes"][selected_note_index]
		note["start_y"] = float(new_text)
		_save_chart_file()
		preview_canvas.queue_redraw()
	if start_y_input: start_y_input.release_focus()

func _on_set_start_toggled(is_toggled: bool) -> void:
	is_setting_start_pos = is_toggled
	if is_toggled:
		if set_start_btn: set_start_btn.text = "Click to set start coordinate"
		if is_curve_draw_mode:
			is_curve_draw_mode = false
			if draw_curve_btn: draw_curve_btn.button_pressed = false
	else:
		if set_start_btn: set_start_btn.text = "Click Canvas to Set Start"

func _on_draw_curve_toggled(is_toggled: bool) -> void:
	is_curve_draw_mode = is_toggled
	is_curve_dragging = false
	if is_toggled:
		if draw_curve_btn: draw_curve_btn.text = "Drag on Canvas to Draw Curve..."
		if is_setting_start_pos:
			is_setting_start_pos = false
			if set_start_btn: set_start_btn.button_pressed = false
	else:
		if draw_curve_btn: draw_curve_btn.text = "Draw Curve (Drag on Canvas)"
	preview_canvas.queue_redraw()

func _on_use_gravity_toggled(is_toggled: bool) -> void:
	if selected_note_index != -1:
		var note = chart_data["notes"][selected_note_index]
		note["use_gravity"] = is_toggled
		_save_chart_file()
		preview_canvas.queue_redraw()

func _on_moving_duration_submitted(new_text: String) -> void:
	moving_duration = max(0.1, float(new_text))
	if selected_note_index != -1:
		var note = chart_data["notes"][selected_note_index]
		note["move_duration"] = moving_duration
		_save_chart_file()
		preview_canvas.queue_redraw()
	if moving_duration_input: moving_duration_input.release_focus()

func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

func _calculate_bezier_control_from_drag(start: Vector2, end_pt: Vector2, max_dev: float, side: float) -> Vector2:
	var midpoint = (start + end_pt) / 2.0
	var direction = end_pt - start
	var perpendicular = Vector2(-direction.y, direction.x).normalized()
	return midpoint + perpendicular * max_dev * side

# ==========================================
# 실행 취소 / 다시 실행 및 복사 붙여넣기 헬퍼
# ==========================================
func save_state_for_undo() -> void:
	undo_stack.append(chart_data.duplicate(true))
	if undo_stack.size() > MAX_UNDO_DEPTH:
		undo_stack.pop_front()
	redo_stack.clear()

func perform_undo() -> void:
	if undo_stack.is_empty():
		_show_toast("Nothing to Undo")
		return
	redo_stack.append(chart_data.duplicate(true))
	chart_data = undo_stack.pop_back()
	selected_note_index = -1
	hover_note_index = -1
	_save_chart_file()
	preview_canvas.queue_redraw()
	_show_toast("Undo")

func perform_redo() -> void:
	if redo_stack.is_empty():
		_show_toast("Nothing to Redo")
		return
	undo_stack.append(chart_data.duplicate(true))
	chart_data = redo_stack.pop_back()
	selected_note_index = -1
	hover_note_index = -1
	_save_chart_file()
	preview_canvas.queue_redraw()
	_show_toast("Redo")


# --- 자동 저장 백업 기능 ---
func _auto_save_backup() -> void:
	if selected_song == "" or not chart_data.has("notes") or chart_data["notes"].is_empty():
		return
	var song_path = MUSIC_BASE_PATH + selected_song + "/chart_backup.json"
	var file = FileAccess.open(song_path, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(chart_data, "\t")
		file.store_string(json_str)
		_show_toast("Auto-backup saved!")


# --- 오토플레이 및 불가능한 패턴 검출 도우미 함수 ---
func _on_autoplay_toggled(is_toggled: bool) -> void:
	is_autoplay = is_toggled
	autoplay_hit_notes.clear()
	var btn = get_viewport().gui_get_focus_owner() as Button
	# 버튼 텍스트 동적 업데이트
	for child in top_bar.get_child(0).get_child(0).get_children():
		if child is Button and "Auto-Play:" in child.text:
			child.text = "Auto-Play: ON" if is_toggled else "Auto-Play: OFF"
	if is_toggled:
		_show_toast("Auto-Play Enabled")
	else:
		_show_toast("Auto-Play Disabled")

func _on_instant_test_pressed() -> void:
	if is_playing:
		audio_player.stop()
	Global.is_editor_test_mode = true
	Global.editor_test_start_time = current_time
	_save_chart_file()
	_show_toast("Launching Instant Test...")
	# 씬 페이드 트랜지션을 이용해 자연스럽게 전환
	SceneTransition.transition_to_scene("res://scenes/game/game.tscn")

func _trigger_autoplay_hit_effect(note: Dictionary) -> void:
	var pos = Vector2(float(note.get("x", 960.0)), float(note.get("y", 540.0)))
	autoplay_ripples.append({"pos": pos, "life": 0.3})

func _get_note_warnings(idx: int) -> String:
	var notes = chart_data.get("notes", [])
	if idx >= notes.size(): return ""
	var note = notes[idx]
	var t = float(note.get("time", 0.0))
	var pos = Vector2(float(note.get("x", 960.0)), float(note.get("y", 540.0)))
	
	for i in range(notes.size()):
		if i == idx: continue
		var other = notes[i]
		var other_t = float(other.get("time", 0.0))
		var other_pos = Vector2(float(other.get("x", 960.0)), float(other.get("y", 540.0)))
		
		# 1. 동시 치기 불가 경고 (0.01초 이내 동일 시간대 타격 요구)
		if abs(t - other_t) < 0.01:
			return "SIMULTANEOUS"
		# 2. 초고속 피지컬 경고 (0.07초 이내 타격 요구 - 80ms 미만)
		elif abs(t - other_t) < 0.07:
			return "TOO_CLOSE"
		# 3. 위치 및 시간 겹침 차폐 경고 (반경 65px 이내 및 시간차 0.4초 이내)
		elif pos.distance_to(other_pos) < 65.0 and abs(t - other_t) < 0.4:
			return "OVERLAP"
			
	# 4. 시간 대비 거리가 너무 먼 노트 (칠 수 없는 노트 경고)
	var prev_note = null
	for i in range(idx - 1, -1, -1):
		var potential = notes[i]
		prev_note = potential
		break
		
	if prev_note != null:
		var t1 = float(prev_note.get("time", 0.0))
		var dt = t - t1
		var p1 = Vector2(float(prev_note.get("x", 960.0)), float(prev_note.get("y", 540.0)))
		var dist = pos.distance_to(p1)
		var speed = dist / dt if dt > 0.001 else 999999.0
		if speed > Global.max_note_speed:
			return "TOO_FAR"
			
	return ""


# --- 구간 재생 및 반복 재생 UI 바인딩 및 헬퍼 ---
func _setup_region_settings_ui() -> void:
	region_settings_box = VBoxContainer.new()
	region_settings_box.name = "RegionSettings"
	
	var label = Label.new()
	label.text = "Region Loop Settings"
	label.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	label.add_theme_font_size_override("font_size", 14)
	region_settings_box.add_child(label)
	
	region_lbl_info = Label.new()
	region_lbl_info.text = "Start: -- / End: --"
	region_lbl_info.add_theme_color_override("font_color", COLOR_TEXT_WINE_MUTED)
	region_lbl_info.add_theme_font_size_override("font_size", 12)
	region_settings_box.add_child(region_lbl_info)
	
	region_loop_check = CheckBox.new()
	region_loop_check.text = "Loop Region"
	region_loop_check.button_pressed = is_region_loop
	region_loop_check.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	region_loop_check.add_theme_font_size_override("font_size", 12)
	region_loop_check.toggled.connect(func(is_toggled):
		is_region_loop = is_toggled
		_show_toast("Region Loop: ON" if is_toggled else "Region Loop: OFF")
	)
	region_settings_box.add_child(region_loop_check)
	
	var hbox_btns = HBoxContainer.new()
	
	region_play_btn = Button.new()
	region_play_btn.text = "Play Region (Shift+Space)"
	region_play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region_play_btn.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	region_play_btn.add_theme_font_size_override("font_size", 12)
	region_play_btn.pressed.connect(_on_play_region_pressed)
	hbox_btns.add_child(region_play_btn)
	
	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	clear_btn.add_theme_font_size_override("font_size", 12)
	clear_btn.pressed.connect(func():
		region_start_time = -1.0
		region_end_time = -1.0
		is_playing_region = false
		_update_region_ui()
		timeline.queue_redraw()
		_show_toast("Region Cleared")
	)
	hbox_btns.add_child(clear_btn)
	
	region_settings_box.add_child(hbox_btns)
	
	var sep = HSeparator.new()
	region_settings_box.add_child(sep)
	
	# 사이드바 컨트롤즈 자식 목록에 RegionSettings 삽입 (MovingSettings 아래에 배치)
	var controls_parent = hold_settings.get_parent()
	controls_parent.add_child(region_settings_box)
	var moving_idx = moving_settings.get_index() if moving_settings else hold_settings.get_index()
	controls_parent.move_child(region_settings_box, moving_idx + 1)

func _update_region_ui() -> void:
	if region_lbl_info == null:
		return
	if region_start_time >= 0.0 and region_end_time >= 0.0:
		region_lbl_info.text = "Start: %.2fs / End: %.2fs" % [region_start_time, region_end_time]
	elif region_start_time >= 0.0:
		region_lbl_info.text = "Start: %.2fs / End: --" % region_start_time
	elif region_end_time >= 0.0:
		region_lbl_info.text = "Start: -- / End: %.2fs" % region_end_time
	else:
		region_lbl_info.text = "Start: -- / End: --"

func _on_play_region_pressed() -> void:
	if region_start_time < 0.0 or region_end_time < 0.0 or region_end_time <= region_start_time:
		_show_toast("Set Start & End first!")
		return
	is_playing_region = true
	_seek_time(region_start_time)
	if not is_playing:
		_on_play_pressed()
	_show_toast("Playing Region...")
