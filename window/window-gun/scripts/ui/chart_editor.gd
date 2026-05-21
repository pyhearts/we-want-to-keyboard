extends Control

const MUSIC_BASE_PATH := "res://assets/musics/"
const MAIN_MENU_SCENE := "res://scenes/menu/main_menu.tscn"

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
var drag_offset := Vector2.ZERO

# 핑크 테마 컬러 상수
const COLOR_BG_CANVAS := Color(1.0, 0.960784, 0.968627, 1.0)        # #FFF5F7
const COLOR_BORDER_CANVAS := Color(1.0, 0.560784, 0.639216, 0.8)    # #FF8FA3
const COLOR_GRID_CANVAS := Color(1.0, 0.815686, 0.854902, 0.4)      # #FFE3E8
const COLOR_TEXT_WINE := Color(0.290196, 0.0823529, 0.129412, 1.0)   # #4A1521
const COLOR_TEXT_WINE_MUTED := Color(0.541176, 0.352941, 0.396078, 1.0) # #8A5A65

const COLOR_NOTE_NORMAL := Color(1.0, 0.301961, 0.427451, 1.0)      # #FF4D6D
const COLOR_NOTE_MOVING := Color(1.0, 0.458824, 0.560784, 1.0)      # #FF758F
const COLOR_NOTE_HOLD := Color(0.788235, 0.0941176, 0.290196, 1.0)    # #C9184A
const COLOR_NOTE_SELECTED := Color(1.0, 0.0, 0.329412, 1.0)         # #FF0054

const COLOR_BG_TIMELINE := Color(1.0, 0.898039, 0.92549, 1.0)       # #FFE5EC
const COLOR_HEADER_TIMELINE := Color(1.0, 0.0, 0.329412, 0.95)     # #FF0054 (재생헤드)
const COLOR_GRID_TIMELINE_MAIN := Color(0.788235, 0.0941176, 0.290196, 0.6) # #C9184A (1비트선)
const COLOR_GRID_TIMELINE_SUB := Color(1.0, 0.760784, 0.819608, 0.5)  # #FFC2D1 (스냅선)

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
	var res_path := MUSIC_BASE_PATH + selected_song + "/Res.tres"
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
	var path := MUSIC_BASE_PATH + selected_song + "/chart.json"
	if not FileAccess.file_exists(path):
		# 없을 시 빈 구조 생성
		chart_data = {
			"notes": [],
			"events": []
		}
		_save_chart_file()
		return
		
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary:
			chart_data = parsed
			if not chart_data.has("notes"):
				chart_data["notes"] = []
			if not chart_data.has("events"):
				chart_data["events"] = []
		else:
			chart_data = {"notes": [], "events": []}
	else:
		chart_data = {"notes": [], "events": []}
		
	# 정렬
	_sort_chart()

func _sort_chart() -> void:
	if chart_data.has("notes") and chart_data["notes"] is Array:
		chart_data["notes"].sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))

func _save_chart_file() -> void:
	_sort_chart()
	var path := MUSIC_BASE_PATH + selected_song + "/chart.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(chart_data, "\t")
		file.store_string(json_str)
		file.close()
		_show_toast("Chart Auto-Saved!")

func _save_resources() -> void:
	var res_path := MUSIC_BASE_PATH + selected_song + "/Res.tres"
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
	
	# 캔버스 및 타임라인 갱신
	preview_canvas.queue_redraw()
	timeline.queue_redraw()

func _update_time_label() -> void:
	var cur_min := int(current_time) / 60
	var cur_sec := int(current_time) % 60
	var cur_ms := int((current_time - int(current_time)) * 1000)
	
	var total_min := int(song_duration) / 60
	var total_sec := int(song_duration) % 60
	var total_ms := int((song_duration - int(song_duration)) * 1000)
	
	time_label.text = "%02d:%02d.%03d / %02d:%02d.%03d" % [cur_min, cur_sec, cur_ms, total_min, total_sec, total_ms]

# ==========================================
# 스냅 연산
# ==========================================
func get_snapped_time(raw_time: float) -> float:
	if snap_division <= 1:
		return max(0.0, raw_time)
	var beat_length := 60.0 / bpm
	var step := beat_length * (4.0 / snap_division)
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
			
	# 방향키 좌/우 이동 (시간 탐색)
	if event is InputEventKey and event.pressed:
		var step := 0.1
		var is_ctrl := false
		if event is InputEventWithModifiers:
			is_ctrl = event.ctrl_pressed
		
		if is_ctrl:
			var beat_length := 60.0 / bpm
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
			_delete_note(selected_note_index)

func _seek_time(target: float) -> void:
	current_time = clamp(target, 0.0, song_duration)
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
	var val := float(new_text)
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
	var val := float(new_text)
	if val > 0.0:
		hold_duration = val
		duration_input.release_focus()

func _on_hold_division_submitted(new_text: String) -> void:
	var val := int(new_text)
	if val > 0:
		hold_division = val
		division_input.release_focus()

# ==========================================
# 캔버스 2D 조작
# ==========================================
func _on_canvas_gui_input(event: InputEvent) -> void:
	if not chart_data.has("notes"): return
	
	var canvas_w := preview_canvas.size.x
	var canvas_h := preview_canvas.size.y
	if canvas_w == 0 or canvas_h == 0: return
	
	var local_pos: Vector2 = event.position
	var logical_pos := Vector2(
		local_pos.x * (1920.0 / canvas_w),
		local_pos.y * (1080.0 / canvas_h)
	)
	
	if event is InputEventMouseMotion:
		_update_hover_note(logical_pos)
		
	if event is InputEventMouseButton and event.pressed:
		var snapped_time := get_snapped_time(current_time)
		
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
				return
				
			if hover_note_index != -1:
				selected_note_index = hover_note_index
				_show_toast("Note Selected")
				
				var note = chart_data["notes"][hover_note_index]
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
			else:
				_add_note(snapped_time, logical_pos)
				
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if hover_note_index != -1:
				_delete_note(hover_note_index)

func _update_hover_note(logical_pos: Vector2) -> void:
	hover_note_index = -1
	if not chart_data.has("notes"): return
	
	var threshold := 40.0
	var notes: Array = chart_data["notes"]
	var time_window := 0.4
	
	for i in range(notes.size()):
		var note: Dictionary = notes[i]
		var note_time := float(note.get("time", 0.0))
		var note_type := str(note.get("type", "normal"))
		
		if absf(note_time - current_time) > time_window:
			continue
			
		if note_type == "hold":
			var dist := logical_pos.distance_to(Vector2(960, 540))
			if dist < threshold + 20.0:
				hover_note_index = i
				return
		else:
			var nx := float(note.get("x", 960.0))
			var ny := float(note.get("y", 540.0))
			var dist := logical_pos.distance_to(Vector2(nx, ny))
			if dist < threshold:
				hover_note_index = i
				return

func _add_note(time_val: float, logical_pos: Vector2) -> void:
	var note_node := {}
	note_node["time"] = time_val
	note_node["type"] = selected_type
	
	if selected_type == "hold":
		note_node["duration"] = hold_duration
		note_node["beat_division"] = hold_division
	elif selected_type == "moving":
		note_node["x"] = clamp(logical_pos.x, 100.0, 1820.0)
		note_node["y"] = clamp(logical_pos.y, 100.0, 980.0)
		note_node["start_x"] = note_node["x"]
		note_node["start_y"] = note_node["y"] + 300.0
	else:
		note_node["x"] = clamp(logical_pos.x, 100.0, 1820.0)
		note_node["y"] = clamp(logical_pos.y, 100.0, 980.0)
		
	chart_data["notes"].append(note_node)
	_save_chart_file()
	
	selected_note_index = chart_data["notes"].find(note_node)
	if selected_type == "moving":
		if start_x_input: start_x_input.text = "%.1f" % note_node["start_x"]
		if start_y_input: start_y_input.text = "%.1f" % note_node["start_y"]
		
	_update_hover_note(logical_pos)
	preview_canvas.queue_redraw()

func _delete_note(index: int) -> void:
	if index >= 0 and index < chart_data["notes"].size():
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
	var timeline_w := timeline.size.x
	if timeline_w == 0: return
	
	var pixels_per_second := 150.0
	
	if event is InputEventMouseButton and event.pressed:
		var local_x: float = event.position.x
		var dx := local_x - (timeline_w / 2.0)
		var dt := dx / pixels_per_second
		var target_time := current_time + dt
		
		var is_ctrl := false
		if event is InputEventWithModifiers:
			is_ctrl = event.ctrl_pressed
		if is_ctrl:
			target_time = get_snapped_time(target_time)
			
		_seek_time(target_time)

# ==========================================
# 핑크 테마 렌더링 (_draw)
# ==========================================
func _draw_preview_canvas() -> void:
	var canvas_w := preview_canvas.size.x
	var canvas_h := preview_canvas.size.y
	if canvas_w == 0 or canvas_h == 0: return
	
	var sx := canvas_w / 1920.0
	var sy := canvas_h / 1080.0
	
	# 캔버스 핑크 배경 및 핑크 에스테틱 테두리
	preview_canvas.draw_rect(Rect2(Vector2.ZERO, preview_canvas.size), COLOR_BG_CANVAS, true)
	preview_canvas.draw_rect(Rect2(Vector2.ZERO, preview_canvas.size), COLOR_BORDER_CANVAS, false, 2.0 * sx)
	
	# 핑크 십자 가선
	preview_canvas.draw_line(Vector2(canvas_w/2, 0), Vector2(canvas_w/2, canvas_h), COLOR_GRID_CANVAS, 1.0)
	preview_canvas.draw_line(Vector2(0, canvas_h/2), Vector2(canvas_w, canvas_h/2), COLOR_GRID_CANVAS, 1.0)
	
	if not chart_data.has("notes"): return
	
	var notes: Array = chart_data["notes"]
	var time_window := 0.4
	
	for i in range(notes.size()):
		var note: Dictionary = notes[i]
		var note_time := float(note.get("time", 0.0))
		var note_type := str(note.get("type", "normal"))
		
		var diff := note_time - current_time
		if absf(diff) > time_window:
			continue
			
		var alpha: float = 1.0 - (absf(diff) / time_window)
		var color := COLOR_NOTE_NORMAL
		
		match note_type:
			"normal":
				color = COLOR_NOTE_NORMAL
			"moving":
				color = COLOR_NOTE_MOVING
			"hold":
				color = COLOR_NOTE_HOLD
				
		color.a = alpha
		
		var is_hovered := (i == hover_note_index)
		var is_selected := (i == selected_note_index)
		
		if is_selected:
			color = COLOR_NOTE_SELECTED
			color.a = alpha
		elif is_hovered:
			color = color.lightened(0.2)
			color.a = alpha
			
		if note_type == "hold":
			var center := Vector2(canvas_w / 2.0, canvas_h / 2.0)
			var radius := 80.0 * sx
			if is_hovered or is_selected:
				# 핑크 블렌딩 헤일로 링
				preview_canvas.draw_circle(center, radius + 10.0*sx, Color(1.0, 0.301961, 0.427451, alpha * 0.25))
			
			preview_canvas.draw_arc(center, radius, 0.0, TAU, 64, color, 8.0 * sx, true)
			
			var font := get_theme_font("font")
			var text_str := "HOLD (%.1fs)" % float(note.get("duration", 3.0))
			var text_color = COLOR_TEXT_WINE
			text_color.a = alpha * 0.85
			preview_canvas.draw_string(font, center + Vector2(-60.0*sx, 10.0*sy), text_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, text_color)
		else:
			var nx := float(note.get("x", 960.0)) * sx
			var ny := float(note.get("y", 540.0)) * sy
			var pos := Vector2(nx, ny)
			var radius := 25.0 * sx
			
			if is_hovered or is_selected:
				preview_canvas.draw_circle(pos, radius + 8.0*sx, Color(1.0, 0.301961, 0.427451, alpha * 0.25))
				
			preview_canvas.draw_circle(pos, radius, color)
			
			# 도넛 형태 내부 (가장자리와 대비되는 어두운 핑크 와인 색상)
			var inner_dark_color = COLOR_TEXT_WINE
			inner_dark_color.a = alpha
			preview_canvas.draw_circle(pos, radius - 5.0*sx, inner_dark_color)
			preview_canvas.draw_circle(pos, radius - 10.0*sx, color)
			
			if note_type == "moving":
				var start_x := float(note.get("start_x", note.get("x", 960.0))) * sx
				var start_y := float(note.get("start_y", float(note.get("y", 540.0)) + 300.0)) * sy
				var start_pos := Vector2(start_x, start_y)
				
				var line_color := Color(1.0, 0.458824, 0.560784, alpha * 0.5)
				preview_canvas.draw_line(start_pos, pos, line_color, 2.0 * sx)
				preview_canvas.draw_circle(start_pos, 12.0 * sx, line_color)
				preview_canvas.draw_circle(start_pos, 8.0 * sx, COLOR_BG_CANVAS)
				
				if is_selected:
					var font := get_theme_font("font")
					preview_canvas.draw_string(font, start_pos + Vector2(-4.0 * sx, 4.0 * sy), "S", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, COLOR_TEXT_WINE)
			
			# 텍스트 라벨 (딥 와인 색상)
			var font := get_theme_font("font")
			var text_color = COLOR_TEXT_WINE
			text_color.a = alpha * 0.8
			preview_canvas.draw_string(font, pos + Vector2(15.0*sx, -15.0*sy), "%.2fs" % note_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)

func _draw_timeline() -> void:
	var timeline_w: float = timeline.size.x
	var timeline_h: float = timeline.size.y
	if timeline_w == 0 or timeline_h == 0: return
	
	timeline.draw_rect(Rect2(Vector2.ZERO, timeline.size), COLOR_BG_TIMELINE, true)
	timeline.draw_line(Vector2(0, 0), Vector2(timeline_w, 0), COLOR_BORDER_CANVAS, 1.5)
	
	var center_x: float = timeline_w / 2.0
	timeline.draw_line(Vector2(center_x, 0), Vector2(center_x, timeline_h), COLOR_HEADER_TIMELINE, 2.0)
	
	var pixels_per_second: float = 150.0
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
			
	var font := get_theme_font("font")
	for idx in range(first_beat_index, last_beat_index + 1):
		var t: float = idx * beat_length
		var dx: float = (t - current_time) * pixels_per_second
		var lx: float = center_x + dx
		
		timeline.draw_line(Vector2(lx, 10), Vector2(lx, timeline_h), COLOR_GRID_TIMELINE_MAIN, 1.5)
		
		timeline.draw_string(font, Vector2(lx + 4, 15), str(idx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_TEXT_WINE_MUTED)
	
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
			
		var color := COLOR_NOTE_NORMAL
		match note_type:
			"normal": color = COLOR_NOTE_NORMAL
			"moving": color = COLOR_NOTE_MOVING
			"hold":   color = COLOR_NOTE_HOLD
			
		if i == selected_note_index:
			color = COLOR_NOTE_SELECTED
			
		var pts := PackedVector2Array([
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
	else:
		if set_start_btn: set_start_btn.text = "Click Canvas to Set Start"
