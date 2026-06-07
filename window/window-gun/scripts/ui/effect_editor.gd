extends Control

const MUSIC_BASE_PATH = "res://assets/musics/"
const CHART_EDITOR_SCENE = "res://scenes/menu/chart_editor.tscn"

# UI 바인딩
@onready var song_select: OptionButton = %SongSelect
@onready var bpm_input: LineEdit = %BpmInput
@onready var offset_input: LineEdit = %OffsetInput
@onready var snap_select: OptionButton = %SnapSelect
@onready var type_select: OptionButton = %TypeSelect
@onready var hold_settings: VBoxContainer = %HoldSettings
@onready var play_button: Button = %PlayButton
@onready var speed_select: OptionButton = %SpeedSelect
@onready var time_label: Label = %TimeLabel
@onready var preview_canvas: Control = %PreviewCanvas
@onready var timeline: Control = %Timeline
@onready var toast: PanelContainer = %Toast
@onready var toast_label: Label = %ToastLabel

# 동적 UI 컨트롤들
var top_bar: Panel
var to_chart_editor_btn: Button
var effect_settings_container: VBoxContainer

# 이펙트 속성 입력 노드들
var add_event_btn: Button
var delete_event_btn: Button

var edit_x: LineEdit
var edit_y: LineEdit
var edit_target_x: LineEdit
var edit_target_y: LineEdit
var edit_width: LineEdit
var edit_height: LineEdit
var edit_duration: LineEdit
var edit_opacity: LineEdit
var edit_title: LineEdit
var edit_texture: LineEdit

var btn_set_start: Button
var btn_set_target: Button

var is_setting_start: bool = false
var is_setting_target: bool = false

# 데이터
var music_list: Array = []
var selected_song: String = ""
var chart_data: Dictionary = {"notes": [], "events": []}
var bpm: float = 120.0
var offset: float = 0.0
var current_time: float = 0.0
var is_playing: bool = false
var playback_speed: float = 1.0
var snap_division: int = 16

# 에디터
var audio_player: AudioStreamPlayer
var song_duration: float = 0.0
var pixels_per_second: float = 150.0  # 기본값 150.0

# 선택/오버 및 드래그 제어
var selected_event_index: int = -1
var hover_event_index: int = -1
var drag_offset = Vector2.ZERO
var is_dragging: bool = false

enum DragMode { DRAG_NONE, DRAG_PLAYHEAD, DRAG_EVENT_MOVE, DRAG_EVENT_RESIZE_START, DRAG_EVENT_RESIZE_END }
var drag_mode: DragMode = DragMode.DRAG_NONE
var drag_start_mouse_x: float = 0.0
var drag_start_event_time: float = 0.0
var drag_start_event_duration: float = 0.0
var mouse_hover_mode: DragMode = DragMode.DRAG_NONE

# Undo / Redo
var undo_stack: Array = []
var redo_stack: Array = []
const MAX_UNDO_STEPS = 50
var bookmarks: Dictionary = {}
var copied_event_data: Dictionary = {}

# 테마 색상 (chart_editor와 동일)
const COLOR_BG_CANVAS = Color(1.0, 0.960784, 0.968627, 1.0)        # #FFF5F7
const COLOR_BORDER_CANVAS = Color(1.0, 0.560784, 0.639216, 0.8)    # #FF8FA3
const COLOR_GRID_CANVAS = Color(1.0, 0.815686, 0.854902, 0.4)      # #FFE3E8
const COLOR_TEXT_WINE = Color(0.290196, 0.0823529, 0.129412, 1.0)   # #4A1521
const COLOR_TEXT_WINE_MUTED = Color(0.541176, 0.352941, 0.396078, 1.0) # #8A5A65

# 이펙트 렌더링 색상
const COLOR_EVENT_WINDOW = Color(0.3, 0.6, 0.9, 0.6)
const COLOR_EVENT_IMAGE = Color(0.9, 0.4, 0.6, 0.6)
const COLOR_EVENT_SELECTED = Color(1.0, 0.84, 0.0, 1.0) # Gold Yellow

const COLOR_BG_TIMELINE = Color(1.0, 0.898039, 0.92549, 1.0)       # #FFE5EC
const COLOR_HEADER_TIMELINE = Color(1.0, 0.0, 0.329412, 0.95)     # #FF0054
const COLOR_GRID_TIMELINE_MAIN = Color(0.788235, 0.0941176, 0.290196, 0.6) # #C9184A
const COLOR_GRID_TIMELINE_SUB = Color(1.0, 0.760784, 0.819608, 0.5)  # #FFC2D1

# 이펙트 매핑
const EFFECT_TYPES = [
	{"name": "Window (Static)", "code": "window"},
	{"name": "Window (Linear)", "code": "window_moving_linear"},
	{"name": "Window (Smooth)", "code": "window_moving_smooth"},
	{"name": "Image (Static)", "code": "image"},
	{"name": "Image (Linear)", "code": "image_moving_linear"},
	{"name": "Image (Smooth)", "code": "image_moving_smooth"}
]

func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	_setup_dropdowns()
	
	song_select.item_selected.connect(_on_song_selected)
	snap_select.item_selected.connect(_on_snap_selected)
	type_select.item_selected.connect(_on_type_selected)
	speed_select.item_selected.connect(_on_speed_selected)
	
	play_button.pressed.connect(_on_play_pressed)
	
	bpm_input.text_submitted.connect(_on_bpm_submitted)
	offset_input.text_submitted.connect(_on_offset_submitted)
	
	preview_canvas.gui_input.connect(_on_canvas_gui_input)
	timeline.gui_input.connect(_on_timeline_gui_input)
	
	toast.modulate.a = 0.0
	
	_load_song_list()
	
	if song_select.item_count > 0:
		_on_song_selected(0)
		
	_setup_top_bar()
	_setup_effect_settings_ui()
	


func _setup_dropdowns() -> void:
	snap_select.clear()
	snap_select.add_item("No Snap (Free)", 1)
	snap_select.add_item("4 Beats", 4)
	snap_select.add_item("8 Beats", 8)
	snap_select.add_item("16 Beats", 16)
	snap_select.add_item("32 Beats", 32)
	snap_select.selected = 3 # 16 Beats
	
	type_select.clear()
	for i in range(EFFECT_TYPES.size()):
		type_select.add_item(EFFECT_TYPES[i]["name"], i)
	type_select.selected = 0

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
	title.text = "WE WANT TO KEYBOARD - EFFECT EDITOR"
	title.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	title.add_theme_font_size_override("font_size", 16)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)
	
	to_chart_editor_btn = Button.new()
	to_chart_editor_btn.text = "Go to Chart Editor"
	to_chart_editor_btn.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	to_chart_editor_btn.add_theme_font_size_override("font_size", 14)
	
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
	
	to_chart_editor_btn.add_theme_stylebox_override("normal", btn_style_normal)
	to_chart_editor_btn.add_theme_stylebox_override("hover", btn_style_hover)
	to_chart_editor_btn.add_theme_stylebox_override("pressed", btn_style_pressed)
	
	to_chart_editor_btn.pressed.connect(_on_go_to_chart_editor)
	hbox.add_child(to_chart_editor_btn)
	
	margin.add_child(hbox)
	top_bar.add_child(margin)
	
	add_child(top_bar)
	
	var split = get_node("Split") as Control
	split.anchor_top = 0.0
	split.offset_top = 50.0

func _on_go_to_chart_editor() -> void:
	if is_playing:
		audio_player.stop()
	get_tree().change_scene_to_file(CHART_EDITOR_SCENE)

func _setup_effect_settings_ui() -> void:
	hold_settings.visible = false
	
	effect_settings_container = VBoxContainer.new()
	effect_settings_container.name = "EffectSettings"
	
	# 타이틀
	var lbl_sec = Label.new()
	lbl_sec.text = "Effect Properties"
	lbl_sec.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	lbl_sec.add_theme_font_size_override("font_size", 14)
	effect_settings_container.add_child(lbl_sec)
	
	# Add / Delete 버튼
	var hbox_btns = HBoxContainer.new()
	add_event_btn = Button.new()
	add_event_btn.text = "Add Event"
	add_event_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_event_btn.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	add_event_btn.pressed.connect(func(): _add_event(current_time))
	hbox_btns.add_child(add_event_btn)
	
	delete_event_btn = Button.new()
	delete_event_btn.text = "Delete Event"
	delete_event_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_event_btn.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	delete_event_btn.pressed.connect(func(): if selected_event_index != -1: _delete_event(selected_event_index))
	hbox_btns.add_child(delete_event_btn)
	effect_settings_container.add_child(hbox_btns)
	
	# 가로 구분선
	effect_settings_container.add_child(HSeparator.new())
	
	# X / Y
	var hbox_xy = HBoxContainer.new()
	var lbl_x = Label.new()
	lbl_x.text = "X:"
	lbl_x.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	hbox_xy.add_child(lbl_x)
	edit_x = LineEdit.new()
	edit_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_x.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	edit_x.text_submitted.connect(func(t): _on_field_submitted(t, "x"))
	hbox_xy.add_child(edit_x)
	
	var lbl_y = Label.new()
	lbl_y.text = "Y:"
	lbl_y.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	hbox_xy.add_child(lbl_y)
	edit_y = LineEdit.new()
	edit_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_y.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	edit_y.text_submitted.connect(func(t): _on_field_submitted(t, "y"))
	hbox_xy.add_child(edit_y)
	effect_settings_container.add_child(hbox_xy)
	
	btn_set_start = Button.new()
	btn_set_start.text = "Click Canvas for Start"
	btn_set_start.toggle_mode = true
	btn_set_start.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	btn_set_start.toggled.connect(func(toggled):
		is_setting_start = toggled
		if toggled:
			is_setting_target = false
			if btn_set_target: btn_set_target.button_pressed = false
			btn_set_start.text = "Click canvas..."
		else:
			btn_set_start.text = "Click Canvas for Start"
	)
	effect_settings_container.add_child(btn_set_start)
	
	# Target X / Y
	var hbox_txy = HBoxContainer.new()
	var lbl_tx = Label.new()
	lbl_tx.text = "To X:"
	lbl_tx.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	hbox_txy.add_child(lbl_tx)
	edit_target_x = LineEdit.new()
	edit_target_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_target_x.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	edit_target_x.text_submitted.connect(func(t): _on_field_submitted(t, "target_x"))
	hbox_txy.add_child(edit_target_x)
	
	var lbl_ty = Label.new()
	lbl_ty.text = "To Y:"
	lbl_ty.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	hbox_txy.add_child(lbl_ty)
	edit_target_y = LineEdit.new()
	edit_target_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_target_y.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	edit_target_y.text_submitted.connect(func(t): _on_field_submitted(t, "target_y"))
	hbox_txy.add_child(edit_target_y)
	effect_settings_container.add_child(hbox_txy)
	
	btn_set_target = Button.new()
	btn_set_target.text = "Click Canvas for Target"
	btn_set_target.toggle_mode = true
	btn_set_target.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	btn_set_target.toggled.connect(func(toggled):
		is_setting_target = toggled
		if toggled:
			is_setting_start = false
			if btn_set_start: btn_set_start.button_pressed = false
			btn_set_target.text = "Click canvas..."
		else:
			btn_set_target.text = "Click Canvas for Target"
	)
	effect_settings_container.add_child(btn_set_target)
	
	# Width / Height
	var hbox_wh = HBoxContainer.new()
	var lbl_w = Label.new()
	lbl_w.text = "W:"
	lbl_w.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	hbox_wh.add_child(lbl_w)
	edit_width = LineEdit.new()
	edit_width.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_width.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	edit_width.text_submitted.connect(func(t): _on_field_submitted(t, "width"))
	hbox_wh.add_child(edit_width)
	
	var lbl_h = Label.new()
	lbl_h.text = "H:"
	lbl_h.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	hbox_wh.add_child(lbl_h)
	edit_height = LineEdit.new()
	edit_height.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_height.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	edit_height.text_submitted.connect(func(t): _on_field_submitted(t, "height"))
	hbox_wh.add_child(edit_height)
	effect_settings_container.add_child(hbox_wh)
	
	# Duration / Opacity
	var hbox_do = HBoxContainer.new()
	var lbl_dur = Label.new()
	lbl_dur.text = "Dur:"
	lbl_dur.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	hbox_do.add_child(lbl_dur)
	edit_duration = LineEdit.new()
	edit_duration.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_duration.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	edit_duration.text_submitted.connect(func(t): _on_field_submitted(t, "duration"))
	hbox_do.add_child(edit_duration)
	
	var lbl_op = Label.new()
	lbl_op.text = "Opac:"
	lbl_op.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	hbox_do.add_child(lbl_op)
	edit_opacity = LineEdit.new()
	edit_opacity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_opacity.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	edit_opacity.text_submitted.connect(func(t): _on_field_submitted(t, "opacity"))
	hbox_do.add_child(edit_opacity)
	effect_settings_container.add_child(hbox_do)
	
	# Title
	var hbox_title = HBoxContainer.new()
	var lbl_title = Label.new()
	lbl_title.text = "Title:"
	lbl_title.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	hbox_title.add_child(lbl_title)
	edit_title = LineEdit.new()
	edit_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_title.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	edit_title.text_submitted.connect(func(t): _on_field_submitted(t, "title"))
	hbox_title.add_child(edit_title)
	effect_settings_container.add_child(hbox_title)
	
	# Texture Path
	var hbox_tex = HBoxContainer.new()
	var lbl_tex = Label.new()
	lbl_tex.text = "Tex:"
	lbl_tex.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	hbox_tex.add_child(lbl_tex)
	edit_texture = LineEdit.new()
	edit_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_texture.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	edit_texture.placeholder_text = "res://assets/images/..."
	edit_texture.text_submitted.connect(func(t): _on_field_submitted(t, "texture_path"))
	hbox_tex.add_child(edit_texture)
	
	var btn_browse = Button.new()
	btn_browse.text = "Browse"
	btn_browse.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	btn_browse.pressed.connect(_on_browse_texture_pressed)
	hbox_tex.add_child(btn_browse)
	effect_settings_container.add_child(hbox_tex)
	
	var controls_parent = hold_settings.get_parent()
	controls_parent.add_child(effect_settings_container)
	var hold_idx = hold_settings.get_index()
	controls_parent.move_child(effect_settings_container, hold_idx + 1)
	
	_update_ui_from_event()

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
		
	bpm_input.text = str(bpm)
	offset_input.text = str(offset)
	
	if audio_player.stream:
		song_duration = audio_player.stream.get_length()
	else:
		song_duration = 180.0
	
	current_time = 0.0
	is_playing = false
	audio_player.stop()
	play_button.text = "Play"
	
	selected_event_index = -1
	_load_chart()
	
	preview_canvas.queue_redraw()
	timeline.queue_redraw()

func _load_chart() -> void:
	var path = MUSIC_BASE_PATH + selected_song + "/chart.json"
	if not FileAccess.file_exists(path):
		chart_data = {
			"notes": [],
			"events": []
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
		else:
			chart_data = {"notes": [], "events": []}
	else:
		chart_data = {"notes": [], "events": []}
		
	_initialize_missing_event_tracks()
	_sort_events()
func _sort_events() -> void:
	if chart_data.has("events") and chart_data["events"] is Array:
		chart_data["events"].sort_custom(func(a, b):
			return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
		)

func _save_chart_file() -> void:
	var path = MUSIC_BASE_PATH + selected_song + "/chart.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(chart_data, "\t")
		file.store_string(json_str)
		file.close()

func _show_toast(message: String) -> void:
	toast_label.text = message
	toast.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(toast, "modulate:a", 0.0, 1.5).set_delay(1.0)

func _process(delta: float) -> void:
	if is_playing:
		if audio_player.playing:
			current_time = audio_player.get_playback_position()
		else:
			current_time += delta * playback_speed
			
		if current_time >= song_duration:
			current_time = song_duration
			is_playing = false
			audio_player.stop()
			play_button.text = "Play"
			
		preview_canvas.queue_redraw()
		timeline.queue_redraw()
		
	# 마우스 커서 호버 상태 및 모양 업데이트 (재생 중이 아닐 때)
	if not is_playing and Rect2(Vector2.ZERO, timeline.size).has_point(timeline.get_local_mouse_position()):
		var hit = _get_timeline_hit_test(timeline.get_local_mouse_position())
		hover_event_index = hit["index"]
		if hit["mode"] == DragMode.DRAG_EVENT_RESIZE_START or hit["mode"] == DragMode.DRAG_EVENT_RESIZE_END:
			timeline.mouse_default_cursor_shape = Control.CURSOR_HSIZE
		elif hit["mode"] == DragMode.DRAG_EVENT_MOVE:
			timeline.mouse_default_cursor_shape = Control.CURSOR_MOVE
		else:
			timeline.mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		hover_event_index = -1
		timeline.mouse_default_cursor_shape = Control.CURSOR_ARROW
		
	_update_time_label()
func _update_time_label() -> void:
	var cur_min = int(current_time) / 60
	var cur_sec = int(current_time) % 60
	var cur_ms = int((current_time - int(current_time)) * 1000)
	
	var total_min = int(song_duration) / 60
	var total_sec = int(song_duration) % 60
	var total_ms = int((song_duration - int(song_duration)) * 1000)
	
	time_label.text = "%02d:%02d.%03d / %02d:%02d.%03d" % [cur_min, cur_sec, cur_ms, total_min, total_sec, total_ms]

func get_snapped_time(raw_time: float) -> float:
	if snap_division <= 1:
		return raw_time
	var beat_length = 60.0 / bpm
	var step = beat_length * (4.0 / snap_division)
	var snapped: float = round(raw_time / step) * step
	return clamp(snapped, 0.0, song_duration)

func _input(event: InputEvent) -> void:
	var vp = get_viewport()
	if not vp:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner = vp.gui_get_focus_owner()
		if focus_owner is LineEdit:
			return
			
		var is_ctrl = Input.is_key_pressed(KEY_CTRL)
		var is_alt = Input.is_key_pressed(KEY_ALT)
		
		# 클립보드 복사 (Ctrl + C)
		if is_ctrl and event.keycode == KEY_C:
			if selected_event_index != -1:
				copied_event_data = chart_data["events"][selected_event_index].duplicate(true)
				_show_toast("Event copied to clipboard (복사 완료)")
				vp.set_input_as_handled()
				return
				
		# 클립보드 붙여넣기 (Ctrl + V)
		if is_ctrl and event.keycode == KEY_V:
			if not copied_event_data.is_empty():
				_push_undo()
				var copy = copied_event_data.duplicate(true)
				copy["time"] = current_time
				
				# 해당 시간에 겹치지 않는 빈 트랙 찾아 자동 할당
				var used_tracks = {}
				var snap_time = current_time
				var duration_val = float(copy.get("duration", 3.0))
				
				for ev in chart_data.get("events", []):
					var ev_start = float(ev.get("time", 0.0))
					var ev_end = ev_start + float(ev.get("duration", 3.0))
					if snap_time < ev_end and (snap_time + duration_val) > ev_start:
						used_tracks[ev.get("track", 0)] = true
						
				var new_track = 0
				while used_tracks.has(new_track):
					new_track += 1
				copy["track"] = new_track
				
				chart_data["events"].append(copy)
				_sort_events()
				selected_event_index = chart_data["events"].find(copy)
				
				_save_chart_file()
				_update_ui_from_event()
				preview_canvas.queue_redraw()
				timeline.queue_redraw()
				_show_toast("Event pasted (Track %d)" % (new_track + 1))
				vp.set_input_as_handled()
				return
				
		var code_val = event.keycode
		
		# A. 북마크 기능 (Alt+1~5 등록, 그냥 1~5 이동)
		if code_val >= KEY_1 and code_val <= KEY_5:
			var idx = code_val - KEY_0
			if is_alt:
				vp.set_input_as_handled()
				bookmarks[idx] = current_time
				_show_toast("Bookmark %d set at %.2fs" % [idx, current_time])
				return
			else:
				if bookmarks.has(idx):
					vp.set_input_as_handled()
					_seek_time(bookmarks[idx])
					_show_toast("Jumped to Bookmark %d" % idx)
					return
					
		# B. 이펙트 미러링 (H: 좌우 반전, V: 상하 반전)
		elif selected_event_index != -1 and code_val == KEY_H:
			vp.set_input_as_handled()
			_push_undo()
			var ev = chart_data["events"][selected_event_index]
			ev["x"] = 1920 - int(ev.get("x", 860))
			if "moving" in ev.get("type", ""):
				var tx = ev.get("target_x", ev.get("to_x", ev.get("x", 860)))
				ev["target_x"] = 1920 - int(tx)
				ev["to_x"] = ev["target_x"]
			_save_chart_file()
			_update_ui_from_event()
			_show_toast("Mirrored Horizontally")
			preview_canvas.queue_redraw()
			return
			
		elif selected_event_index != -1 and code_val == KEY_V:
			vp.set_input_as_handled()
			_push_undo()
			var ev = chart_data["events"][selected_event_index]
			ev["y"] = 1080 - int(ev.get("y", 440))
			if "moving" in ev.get("type", ""):
				var ty = ev.get("target_y", ev.get("to_y", ev.get("y", 440)))
				ev["target_y"] = 1080 - int(ty)
				ev["to_y"] = ev["target_y"]
			_save_chart_file()
			_update_ui_from_event()
			_show_toast("Mirrored Vertically")
			preview_canvas.queue_redraw()
			return
			
		# C. 이펙트 시간 미세 이동 (PageUp: 1스냅 뒤로, PageDown: 1스냅 앞으로)
		elif selected_event_index != -1 and code_val == KEY_PAGEUP:
			vp.set_input_as_handled()
			_push_undo()
			var ev = chart_data["events"][selected_event_index]
			var beat_length = 60.0 / bpm
			var step = beat_length * (4.0 / snap_division)
			ev["time"] = max(0.0, float(ev.get("time", 0.0)) - step)
			_sort_events()
			selected_event_index = chart_data["events"].find(ev)
			_save_chart_file()
			_update_ui_from_event()
			_show_toast("Shifted Event Backward")
			preview_canvas.queue_redraw()
			timeline.queue_redraw()
			return
			
		elif selected_event_index != -1 and code_val == KEY_PAGEDOWN:
			vp.set_input_as_handled()
			_push_undo()
			var ev = chart_data["events"][selected_event_index]
			var beat_length = 60.0 / bpm
			var step = beat_length * (4.0 / snap_division)
			ev["time"] = min(song_duration, float(ev.get("time", 0.0)) + step)
			_sort_events()
			selected_event_index = chart_data["events"].find(ev)
			_save_chart_file()
			_update_ui_from_event()
			_show_toast("Shifted Event Forward")
			preview_canvas.queue_redraw()
			timeline.queue_redraw()
			return
			
		# D. 재생 배속 단축키 ([ : 감속, ] : 가속)
		elif code_val == KEY_BRACKETLEFT:
			vp.set_input_as_handled()
			var new_sel = max(0, speed_select.selected - 1)
			if new_sel != speed_select.selected:
				speed_select.selected = new_sel
				_on_speed_selected(new_sel)
				_show_toast("Speed: %s" % speed_select.get_item_text(new_sel))
			return
		elif code_val == KEY_BRACKETRIGHT:
			vp.set_input_as_handled()
			var new_sel = min(speed_select.item_count - 1, speed_select.selected + 1)
			if new_sel != speed_select.selected:
				speed_select.selected = new_sel
				_on_speed_selected(new_sel)
				_show_toast("Speed: %s" % speed_select.get_item_text(new_sel))
			return
			
		# E. 즉시 테스트 단축키 (F5)
		elif code_val == KEY_F5:
			vp.set_input_as_handled()
			_on_instant_test_pressed()
			return
		
		# 단축키: 복제 (Ctrl + D)
		if is_ctrl and event.keycode == KEY_D:
			if selected_event_index != -1:
				_push_undo()
				var orig = chart_data["events"][selected_event_index]
				var copy = orig.duplicate(true)
				copy["time"] = current_time
				chart_data["events"].append(copy)
				_sort_events()
				selected_event_index = chart_data["events"].find(copy)
				_save_chart_file()
				_update_ui_from_event()
				preview_canvas.queue_redraw()
				timeline.queue_redraw()
				_show_toast("Event Duplicated")
				vp.set_input_as_handled()
				return
				
		# 단축키: Undo (Ctrl + Z), Redo (Ctrl + Shift + Z / Ctrl + Y)
		if is_ctrl and event.keycode == KEY_Z:
			if Input.is_key_pressed(KEY_SHIFT):
				_redo()
			else:
				_undo()
			vp.set_input_as_handled()
			return
		elif is_ctrl and event.keycode == KEY_Y:
			_redo()
			vp.set_input_as_handled()
			return
			
		if event.keycode == KEY_SPACE:
			_on_play_pressed()
			vp.set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if is_playing:
				audio_player.stop()
			get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
			vp.set_input_as_handled()
		elif event.keycode == KEY_DELETE:
			if selected_event_index != -1:
				_push_undo()
				_delete_event(selected_event_index)
				vp.set_input_as_handled()
		elif event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
			var step = 0.1
			if is_ctrl:
				step = 60.0 / bpm
			if event.keycode == KEY_LEFT:
				_seek_time(current_time - step)
			else:
				_seek_time(current_time + step)
			vp.set_input_as_handled()
func _seek_time(target: float) -> void:
	current_time = clamp(target, 0.0, song_duration)
	if is_playing and audio_player.stream:
		audio_player.seek(current_time)
	preview_canvas.queue_redraw()
	timeline.queue_redraw()

func _on_play_pressed() -> void:
	if is_playing:
		is_playing = false
		audio_player.stop()
		play_button.text = "Play"
	else:
		is_playing = true
		play_button.text = "Pause"
		if audio_player.stream:
			audio_player.pitch_scale = playback_speed
			audio_player.play(current_time)

func _on_song_selected_item(index: int) -> void:
	pass

func _on_snap_selected(index: int) -> void:
	var metadata = snap_select.get_item_id(index)
	snap_division = metadata
	timeline.queue_redraw()

func _on_type_selected(index: int) -> void:
	_push_undo()
	if selected_event_index != -1:
		var event = chart_data["events"][selected_event_index]
		event["type"] = EFFECT_TYPES[index]["code"]
		_update_ui_from_event()
		_save_chart_file()
		preview_canvas.queue_redraw()
		timeline.queue_redraw()

func _on_speed_selected(index: int) -> void:
	var val_str = speed_select.get_item_text(index).replace("x", "")
	playback_speed = float(val_str)
	if is_playing and audio_player.stream:
		audio_player.pitch_scale = playback_speed

func _on_bpm_submitted(new_text: String) -> void:
	var val = float(new_text)
	if val > 0:
		bpm = val
		_save_resources()
		_show_toast("BPM updated: " + str(bpm))
		timeline.queue_redraw()
	bpm_input.release_focus()

func _on_offset_submitted(new_text: String) -> void:
	offset = float(new_text)
	_save_resources()
	_show_toast("Offset updated: " + str(offset))
	timeline.queue_redraw()
	offset_input.release_focus()

func _save_resources() -> void:
	var res_path = MUSIC_BASE_PATH + selected_song + "/Res.tres"
	if FileAccess.file_exists(res_path):
		var music_res = load(res_path)
		if music_res:
			music_res.set("bpm", int(bpm))
			music_res.set("offset", offset)
			ResourceSaver.save(music_res, res_path)

func _update_ui_from_event() -> void:
	if selected_event_index == -1 or selected_event_index >= chart_data["events"].size():
		edit_x.text = ""
		edit_y.text = ""
		edit_target_x.text = ""
		edit_target_y.text = ""
		edit_width.text = ""
		edit_height.text = ""
		edit_duration.text = ""
		edit_opacity.text = ""
		edit_title.text = ""
		edit_texture.text = ""
		edit_target_x.editable = false
		edit_target_y.editable = false
		btn_set_target.disabled = true
		return
		
	var event = chart_data["events"][selected_event_index]
	var etype = event.get("type", "window")
	
	edit_x.text = str(event.get("x", 860))
	edit_y.text = str(event.get("y", 440))
	edit_width.text = str(event.get("width", 200))
	edit_height.text = str(event.get("height", 200))
	edit_duration.text = str(event.get("duration", 3.0))
	edit_opacity.text = str(event.get("opacity", 1.0))
	edit_title.text = str(event.get("title", "Event Window"))
	edit_texture.text = str(event.get("texture_path", ""))
	
	var is_moving = "moving" in etype
	edit_target_x.editable = is_moving
	edit_target_y.editable = is_moving
	btn_set_target.disabled = not is_moving
	
	if is_moving:
		edit_target_x.text = str(event.get("target_x", event.get("to_x", event.get("x", 860))))
		edit_target_y.text = str(event.get("target_y", event.get("to_y", event.get("y", 440))))
	else:
		edit_target_x.text = ""
		edit_target_y.text = ""
		
	for i in range(EFFECT_TYPES.size()):
		if EFFECT_TYPES[i]["code"] == etype:
			type_select.selected = i
			break

func _on_field_submitted(new_text: String, field_name: String) -> void:
	_push_undo()
	if selected_event_index == -1:
		return
	var event = chart_data["events"][selected_event_index]
	match field_name:
		"x", "y", "width", "height":
			event[field_name] = int(new_text)
		"target_x", "target_y":
			event[field_name] = int(new_text)
			event["to_" + field_name.split("_")[1]] = int(new_text)
		"duration", "opacity":
			event[field_name] = float(new_text)
		"title", "texture_path":
			event[field_name] = new_text
			
	_save_chart_file()
	_update_ui_from_event()
	preview_canvas.queue_redraw()
	timeline.queue_redraw()
	
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()

func _add_event(time_val: float) -> void:
	var snap_time = get_snapped_time(time_val)
	var duration_val = 3.0
	
	# 신규 추가 시 해당 시간대에서 겹치지 않는 가장 낮은 빈 트랙 찾기
	var used_tracks = {}
	for ev in chart_data.get("events", []):
		var ev_start = float(ev.get("time", 0.0))
		var ev_end = ev_start + float(ev.get("duration", 3.0))
		if snap_time < ev_end and (snap_time + duration_val) > ev_start:
			used_tracks[ev.get("track", 0)] = true
			
	var new_track = 0
	while used_tracks.has(new_track):
		new_track += 1
		
	var new_event = {
		"time": snap_time,
		"track": new_track,
		"type": "window",
		"x": 860,
		"y": 440,
		"width": 200,
		"height": 200,
		"duration": duration_val,
		"opacity": 1.0,
		"title": "Event Window",
		"texture_path": ""
	}
	chart_data["events"].append(new_event)
	_sort_events()
	selected_event_index = chart_data["events"].find(new_event)
	_update_ui_from_event()
	_save_chart_file()
	_show_toast("Event added at " + "%0.2f" % snap_time + "s (Track %d)" % (new_track + 1))
	preview_canvas.queue_redraw()
	timeline.queue_redraw()
func _delete_event(index: int) -> void:
	if index >= 0 and index < chart_data["events"].size():
		chart_data["events"].remove_at(index)
		selected_event_index = -1
		_update_ui_from_event()
		_save_chart_file()
		_show_toast("Event deleted")
		preview_canvas.queue_redraw()
		timeline.queue_redraw()

func _on_canvas_gui_input(event: InputEvent) -> void:
	var canvas_w: float = preview_canvas.size.x
	var canvas_h: float = preview_canvas.size.y
	if canvas_w == 0 or canvas_h == 0: return
	
	var sx: float = canvas_w / 1920.0
	var sy: float = canvas_h / 1080.0
	
	if event is InputEventMouseButton:
		var local_pos: Vector2 = event.position
		var logical_pos = Vector2(local_pos.x / sx, local_pos.y / sy)
		
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_setting_start:
				_push_undo()
				if selected_event_index != -1:
					var ev: Dictionary = chart_data["events"][selected_event_index]
					ev["x"] = int(logical_pos.x)
					ev["y"] = int(logical_pos.y)
					_save_chart_file()
					_update_ui_from_event()
					_show_toast("Set Start: " + str(ev["x"]) + ", " + str(ev["y"]))
				is_setting_start = false
				btn_set_start.button_pressed = false
				preview_canvas.queue_redraw()
				return
				
			if is_setting_target:
				_push_undo()
				if selected_event_index != -1:
					var ev: Dictionary = chart_data["events"][selected_event_index]
					ev["target_x"] = int(logical_pos.x)
					ev["target_y"] = int(logical_pos.y)
					ev["to_x"] = int(logical_pos.x)
					ev["to_y"] = int(logical_pos.y)
					_save_chart_file()
					_update_ui_from_event()
					_show_toast("Set Target: " + str(ev["target_x"]) + ", " + str(ev["target_y"]))
				is_setting_target = false
				btn_set_target.button_pressed = false
				preview_canvas.queue_redraw()
				return
				
			var clicked_idx: int = -1
			var events: Array = chart_data["events"]
			
			for i in range(events.size()):
				var ev = events[i]
				var ev_time: float = float(ev.get("time", 0.0))
				var ev_dur: float = float(ev.get("duration", 3.0))
				if current_time >= ev_time and current_time <= ev_time + ev_dur:
					var cur_pos: Vector2 = _get_event_current_pos(ev, current_time)
					var ev_w: int = int(ev.get("width", 200))
					var ev_h: int = int(ev.get("height", 200))
					var rect = Rect2(cur_pos, Vector2(ev_w, ev_h))
					if rect.has_point(logical_pos):
						clicked_idx = i
						break
						
			if clicked_idx != -1:
				selected_event_index = clicked_idx
				var ev = events[selected_event_index]
				var cur_pos: Vector2 = _get_event_current_pos(ev, current_time)
				_push_undo()
				drag_offset = logical_pos - cur_pos
				is_dragging = true
				_update_ui_from_event()
				preview_canvas.queue_redraw()
				timeline.queue_redraw()
				
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_dragging:
				is_dragging = false
				_save_chart_file()
				preview_canvas.queue_redraw()
				timeline.queue_redraw()
				
	elif event is InputEventMouseMotion and is_dragging:
		var local_pos: Vector2 = event.position
		var logical_pos = Vector2(local_pos.x / sx, local_pos.y / sy)
		if selected_event_index != -1:
			var ev: Dictionary = chart_data["events"][selected_event_index]
			var etype: String = ev.get("type", "window")
			var new_cur_pos: Vector2 = logical_pos - drag_offset
			
			if "moving" in etype:
				var dx: int = int(new_cur_pos.x) - int(ev.get("x", 860))
				var dy: int = int(new_cur_pos.y) - int(ev.get("y", 440))
				ev["x"] = int(new_cur_pos.x)
				ev["y"] = int(new_cur_pos.y)
				ev["target_x"] = int(ev.get("target_x", ev["x"])) + dx
				ev["target_y"] = int(ev.get("target_y", ev["y"])) + dy
				ev["to_x"] = ev["target_x"]
				ev["to_y"] = ev["target_y"]
			else:
				ev["x"] = int(new_cur_pos.x)
				ev["y"] = int(new_cur_pos.y)
				
			_update_ui_from_event()
			preview_canvas.queue_redraw()
func _get_event_current_pos(ev: Dictionary, time_val: float) -> Vector2:
	var ev_time: float = float(ev.get("time", 0.0))
	var ev_dur: float = float(ev.get("duration", 3.0))
	var etype: String = ev.get("type", "window")
	
	var sx: float = float(ev.get("x", 860))
	var sy: float = float(ev.get("y", 440))
	var start_pos = Vector2(sx, sy)
	
	if "moving" in etype and ev_dur > 0:
		var tx: float = float(ev.get("target_x", ev.get("to_x", sx)))
		var ty: float = float(ev.get("target_y", ev.get("to_y", sy)))
		var target_pos = Vector2(tx, ty)
		
		var t: float = (time_val - ev_time) / ev_dur
		t = clamp(t, 0.0, 1.0)
		
		if "smooth" in etype:
			t = t * t * (3.0 - 2.0 * t)
		return start_pos.lerp(target_pos, t)
	return start_pos
func _draw_preview_canvas() -> void:
	var canvas_w: float = preview_canvas.size.x
	var canvas_h: float = preview_canvas.size.y
	if canvas_w == 0 or canvas_h == 0: return
	
	var sx: float = canvas_w / 1920.0
	var sy: float = canvas_h / 1080.0
	
	preview_canvas.draw_rect(Rect2(Vector2.ZERO, preview_canvas.size), COLOR_BG_CANVAS)
	preview_canvas.draw_rect(Rect2(Vector2.ZERO, preview_canvas.size), COLOR_BORDER_CANVAS, false, 2.0)
	
	for col in range(1, 4):
		var gx: float = canvas_w * col / 4.0
		preview_canvas.draw_line(Vector2(gx, 0), Vector2(gx, canvas_h), COLOR_GRID_CANVAS, 1.0)
	for row in range(1, 4):
		var gy: float = canvas_h * row / 4.0
		preview_canvas.draw_line(Vector2(0, gy), Vector2(canvas_w, gy), COLOR_GRID_CANVAS, 1.0)
		
	var events: Array = chart_data.get("events", [])
	var font = get_theme_font("font")
	
	for i in range(events.size()):
		var ev = events[i]
		var ev_time: float = float(ev.get("time", 0.0))
		var ev_dur: float = float(ev.get("duration", 3.0))
		
		if current_time >= ev_time and current_time <= ev_time + ev_dur:
			var etype: String = ev.get("type", "window")
			var ev_w: int = int(ev.get("width", 200))
			var ev_h: int = int(ev.get("height", 200))
			var cur_pos: Vector2 = _get_event_current_pos(ev, current_time)
			
			var rect_scaled = Rect2(cur_pos * Vector2(sx, sy), Vector2(ev_w * sx, ev_h * sy))
			var opac: float = float(ev.get("opacity", 1.0))
			
			var fill_color = COLOR_EVENT_WINDOW
			var has_rendered_texture: bool = false
			if "image" in etype:
				fill_color = COLOR_EVENT_IMAGE
				var tex_path = ev.get("texture_path", "")
				if tex_path != "" and FileAccess.file_exists(tex_path):
					var tex = load(tex_path)
					if tex is Texture2D:
						preview_canvas.draw_texture_rect(tex, rect_scaled, false, Color(1.0, 1.0, 1.0, opac))
						has_rendered_texture = true
						
			if not has_rendered_texture:
				fill_color.a = opac * 0.5
				preview_canvas.draw_rect(rect_scaled, fill_color)
			
			var border_color = fill_color
			border_color.a = opac
			var is_sel: bool = (i == selected_event_index)
			var border_w: float = 4.0 if is_sel else 2.0
			if is_sel:
				border_color = COLOR_EVENT_SELECTED
				
			preview_canvas.draw_rect(rect_scaled, border_color, false, border_w)
			
			var bar_h: float = 20.0 * sy
			var bar_rect = Rect2(rect_scaled.position, Vector2(rect_scaled.size.x, bar_h))
			var bar_color = COLOR_TEXT_WINE
			bar_color.a = opac * 0.8
			preview_canvas.draw_rect(bar_rect, bar_color)
			
			var display_title: String = ev.get("title", "Window") if "window" in etype else "Image"
			var text_pos = bar_rect.position + Vector2(5.0 * sx, 15.0 * sy)
			preview_canvas.draw_string(font, text_pos, display_title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * sy), COLOR_BG_CANVAS)
			
			if "moving" in etype and is_sel:
				var sp = Vector2(float(ev.get("x", 860)), float(ev.get("y", 440))) * Vector2(sx, sy)
				var tp = Vector2(float(ev.get("target_x", ev.get("to_x", ev.get("x", 860)))), float(ev.get("target_y", ev.get("to_y", ev.get("y", 440))))) * Vector2(sx, sy)
				
				preview_canvas.draw_line(sp, tp, COLOR_TEXT_WINE, 2.0)
				preview_canvas.draw_circle(sp, 6.0 * sx, Color(0, 1, 0, 0.8))
				preview_canvas.draw_circle(tp, 6.0 * sx, Color(1, 0, 0, 0.8))
				preview_canvas.draw_string(font, sp + Vector2(10.0 * sx, -5.0 * sy), "Start", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * sy), COLOR_TEXT_WINE)
				preview_canvas.draw_string(font, tp + Vector2(10.0 * sx, -5.0 * sy), "Target", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * sy), COLOR_TEXT_WINE)
func _draw_timeline() -> void:
	var timeline_w: float = timeline.size.x
	var timeline_h: float = timeline.size.y
	if timeline_w == 0 or timeline_h == 0: return
	
	timeline.draw_rect(Rect2(Vector2.ZERO, timeline.size), COLOR_BG_TIMELINE)
	
	var center_x: float = timeline_w / 2.0
	var beat_length: float = 60.0 / bpm
	
	var view_start_time: float = current_time - (center_x / pixels_per_second)
	var view_end_time: float = current_time + (center_x / pixels_per_second)
	
	# 등록된 최대 트랙 계산
	var max_track_idx = 0
	for ev in chart_data.get("events", []):
		var t = ev.get("track", 0)
		if t > max_track_idx:
			max_track_idx = t
	var total_tracks = max(3, max_track_idx + 1)
	
	# 트랙 구분 배경 및 가로 구분선 그리기 (동적 렌더링)
	for i in range(total_tracks):
		var ty = 42.0 + i * 22.0
		var bg_color = Color(1.0, 0.92, 0.94, 0.5) if i % 2 == 0 else Color(1.0, 0.88, 0.91, 0.5)
		timeline.draw_rect(Rect2(0, ty, timeline_w, 22.0), bg_color)
		timeline.draw_line(Vector2(0, ty), Vector2(timeline_w, ty), COLOR_GRID_TIMELINE_SUB, 1.0)
		
	timeline.draw_line(Vector2(0, 42.0 + total_tracks * 22.0), Vector2(timeline_w, 42.0 + total_tracks * 22.0), COLOR_GRID_TIMELINE_SUB, 1.0)
	
	var snap_step_time: float = beat_length * (4.0 / snap_division)
	var first_snap_idx: int = ceili(view_start_time / snap_step_time)
	var last_snap_idx: int = floori(view_end_time / snap_step_time)
	
	for idx in range(first_snap_idx, last_snap_idx + 1):
		var t: float = idx * snap_step_time
		var dx: float = (t - current_time) * pixels_per_second
		var lx: float = center_x + dx
		timeline.draw_line(Vector2(lx, 25), Vector2(lx, timeline_h), COLOR_GRID_TIMELINE_SUB, 1.0)
		
	var first_beat_index: int = ceili(view_start_time / beat_length)
	var last_beat_index: int = floori(view_end_time / beat_length)
	var font = get_theme_font("font")
	
	for idx in range(first_beat_index, last_beat_index + 1):
		var t: float = idx * beat_length
		var dx: float = (t - current_time) * pixels_per_second
		var lx: float = center_x + dx
		
		timeline.draw_line(Vector2(lx, 15), Vector2(lx, timeline_h), COLOR_GRID_TIMELINE_MAIN, 2.0)
		var beat_str = str(idx)
		timeline.draw_string(font, Vector2(lx + 4, 15), beat_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_TEXT_WINE_MUTED)
		
	var sec_step: float = 1.0
	if pixels_per_second < 50.0: sec_step = 5.0
	var first_sec: float = ceili(view_start_time / sec_step) * sec_step
	var last_sec: float = floori(view_end_time / sec_step) * sec_step
	
	var sec: float = first_sec
	while sec <= last_sec:
		var dx: float = (sec - current_time) * pixels_per_second
		var lx: float = center_x + dx
		timeline.draw_string(font, Vector2(lx - 15, 30), "%.1fs" % sec, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_TEXT_WINE)
		sec += sec_step
		
	var events: Array = chart_data.get("events", [])
	for i in range(events.size()):
		var ev = events[i]
		var ev_time: float = float(ev.get("time", 0.0))
		var ev_dur: float = float(ev.get("duration", 3.0))
		
		var dx: float = (ev_time - current_time) * pixels_per_second
		var lx: float = center_x + dx
		var dw: float = ev_dur * pixels_per_second
		
		if lx + dw < 0 or lx > timeline_w:
			continue
			
		var etype = ev.get("type", "window")
		var bar_color = COLOR_EVENT_WINDOW
		if "image" in etype:
			bar_color = COLOR_EVENT_IMAGE
			
		bar_color.a = 0.7
		var is_sel = (i == selected_event_index)
		if is_sel:
			bar_color = COLOR_EVENT_SELECTED
			
		# 개별 고정/수동 지정 track 좌표 렌더링
		var track_idx = ev.get("track", 0)
		var bar_y: float = 45.0 + track_idx * 22.0
		var bar_h: float = 16.0
		var rect = Rect2(lx, bar_y, dw, bar_h)
		
		timeline.draw_rect(rect, bar_color)
		
		var border_color = COLOR_TEXT_WINE
		var border_w = 1.5
		if is_sel:
			border_color = Color(1.0, 0.3, 0.3, 1.0)
			border_w = 2.5
		elif i == hover_event_index:
			border_color = Color(0.9, 0.6, 0.1, 1.0)
			border_w = 2.0
			
		timeline.draw_rect(rect, border_color, false, border_w)
		
		var info_text = etype.replace("window_moving_", "mv_").replace("image_moving_", "mv_img_")
		if ev.has("title") and ev["title"] != "":
			info_text += " (" + ev["title"] + ")"
		timeline.draw_string(font, Vector2(lx + 5, bar_y + 12.0), info_text, HORIZONTAL_ALIGNMENT_LEFT, dw - 10, 9, COLOR_TEXT_WINE)
		
	# 좌측 고정 트랙 헤더 라벨 표시 (동적 트랙 수에 따라)
	timeline.draw_rect(Rect2(0, 0, 60, timeline_h), Color(1.0, 0.898039, 0.92549, 0.9))
	timeline.draw_line(Vector2(60, 0), Vector2(60, timeline_h), COLOR_GRID_TIMELINE_MAIN, 1.5)
	
	for i in range(total_tracks):
		var ty = 45.0 + i * 22.0
		timeline.draw_string(font, Vector2(5, ty + 12.0), "Track %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_TEXT_WINE)
	
	# 플레이헤드 그리기
	var ph_color = Color(0.85, 0.09, 0.29, 0.95)
	timeline.draw_line(Vector2(center_x, 0), Vector2(center_x, timeline_h), ph_color, 2.0)
	var ph_points = PackedVector2Array([
		Vector2(center_x - 7, 0),
		Vector2(center_x + 7, 0),
		Vector2(center_x + 7, 10),
		Vector2(center_x, 17),
		Vector2(center_x - 7, 10)
	])
	timeline.draw_polygon(ph_points, PackedColorArray([ph_color]))
func _on_timeline_gui_input(event: InputEvent) -> void:
	var timeline_w: float = timeline.size.x
	if timeline_w == 0: return
	var center_x: float = timeline_w / 2.0
	
	if event is InputEventMouseButton:
		var local_x: float = event.position.x
		var dx: float = local_x - center_x
		var dt: float = dx / pixels_per_second
		var target_time: float = current_time + dt
		var is_ctrl = Input.is_key_pressed(KEY_CTRL)
		
		# 마우스 휠 확대/축소 및 시간 스크롤
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if is_ctrl:
				pixels_per_second = clamp(pixels_per_second * 1.15, 30.0, 1000.0)
			else:
				_seek_time(current_time - (30.0 / pixels_per_second))
			timeline.queue_redraw()
			accept_event()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if is_ctrl:
				pixels_per_second = clamp(pixels_per_second / 1.15, 30.0, 1000.0)
			else:
				_seek_time(current_time + (30.0 / pixels_per_second))
			timeline.queue_redraw()
			accept_event()
			return
			
		# 마우스 좌클릭 이벤트 처리
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var hit = _get_timeline_hit_test(event.position)
				if hit["index"] != -1 and event.position.x > 60:
					selected_event_index = hit["index"]
					drag_mode = hit["mode"]
					drag_start_mouse_x = event.position.x
					var ev = chart_data["events"][selected_event_index]
					drag_start_event_time = float(ev.get("time", 0.0))
					drag_start_event_duration = float(ev.get("duration", 3.0))
					
					_push_undo()
					
					_update_ui_from_event()
					preview_canvas.queue_redraw()
					timeline.queue_redraw()
				else:
					drag_mode = DragMode.DRAG_PLAYHEAD
					if is_ctrl:
						target_time = get_snapped_time(target_time)
					_seek_time(target_time)
			else:
				if drag_mode != DragMode.DRAG_NONE:
					drag_mode = DragMode.DRAG_NONE
					_save_chart_file()
					preview_canvas.queue_redraw()
					timeline.queue_redraw()
					
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				drag_mode = DragMode.DRAG_PLAYHEAD
				drag_start_mouse_x = event.position.x
			else:
				drag_mode = DragMode.DRAG_NONE
				
	elif event is InputEventMouseMotion:
		var is_ctrl = Input.is_key_pressed(KEY_CTRL)
		
		match drag_mode:
			DragMode.DRAG_PLAYHEAD:
				var local_x: float = event.position.x
				var dx: float = local_x - center_x
				var dt: float = dx / pixels_per_second
				var target_time: float = current_time + dt
				if is_ctrl:
					target_time = get_snapped_time(target_time)
				_seek_time(target_time)
				
			DragMode.DRAG_EVENT_MOVE:
				if selected_event_index != -1:
					var ev = chart_data["events"][selected_event_index]
					
					# X축 이동 (배치 시간 조절)
					var delta_px = event.position.x - drag_start_mouse_x
					var delta_time = delta_px / pixels_per_second
					var new_time = drag_start_event_time + delta_time
					if is_ctrl or snap_division > 1:
						new_time = get_snapped_time(new_time)
					new_time = clamp(new_time, 0.0, song_duration - drag_start_event_duration)
					ev["time"] = new_time
					
					# Y축 이동 (트랙 위치 변경)
					# 트랙 Y = 45.0, 각 간격 22.0 픽셀
					var my = event.position.y
					var calculated_track = int(floori((my - 45.0) / 22.0))
					calculated_track = clamp(calculated_track, 0, 15) # 최대 16개 트랙
					ev["track"] = calculated_track
					
					_update_ui_from_event()
					preview_canvas.queue_redraw()
					timeline.queue_redraw()
					
			DragMode.DRAG_EVENT_RESIZE_START:
				if selected_event_index != -1:
					var ev = chart_data["events"][selected_event_index]
					var delta_px = event.position.x - drag_start_mouse_x
					var delta_time = delta_px / pixels_per_second
					var new_start_time = drag_start_event_time + delta_time
					
					if is_ctrl or snap_division > 1:
						new_start_time = get_snapped_time(new_start_time)
						
					var orig_end_time = drag_start_event_time + drag_start_event_duration
					new_start_time = clamp(new_start_time, 0.0, orig_end_time - 0.05)
					
					ev["time"] = new_start_time
					ev["duration"] = orig_end_time - new_start_time
					
					_update_ui_from_event()
					preview_canvas.queue_redraw()
					timeline.queue_redraw()
					
			DragMode.DRAG_EVENT_RESIZE_END:
				if selected_event_index != -1:
					var ev = chart_data["events"][selected_event_index]
					var delta_px = event.position.x - drag_start_mouse_x
					var delta_time = delta_px / pixels_per_second
					var new_duration = drag_start_event_duration + delta_time
					
					if is_ctrl or snap_division > 1:
						var new_end_time = get_snapped_time(drag_start_event_time + new_duration)
						new_duration = new_end_time - drag_start_event_time
						
					new_duration = max(0.05, new_duration)
					if drag_start_event_time + new_duration > song_duration:
						new_duration = song_duration - drag_start_event_time
						
					ev["duration"] = new_duration
					
					_update_ui_from_event()
					preview_canvas.queue_redraw()
					timeline.queue_redraw()
func _get_timeline_hit_test(mouse_pos: Vector2) -> Dictionary:
	var res = {"index": -1, "mode": DragMode.DRAG_NONE}
	var timeline_w = timeline.size.x
	var center_x = timeline_w / 2.0
	
	var events: Array = chart_data.get("events", [])
	for i in range(events.size() - 1, -1, -1):
		var ev = events[i]
		var ev_time: float = float(ev.get("time", 0.0))
		var ev_dur: float = float(ev.get("duration", 3.0))
		
		var dx: float = (ev_time - current_time) * pixels_per_second
		var lx: float = center_x + dx
		var dw: float = ev_dur * pixels_per_second
		
		# 개별 트랙 Y축 적용
		var track_idx = ev.get("track", 0)
		var bar_y: float = 45.0 + track_idx * 22.0
		var bar_h: float = 16.0
		
		var rect = Rect2(lx, bar_y, dw, bar_h)
		if rect.has_point(mouse_pos):
			res["index"] = i
			var edge_w = min(8.0, dw / 3.0)
			if mouse_pos.x <= lx + edge_w:
				res["mode"] = DragMode.DRAG_EVENT_RESIZE_START
			elif mouse_pos.x >= lx + dw - edge_w:
				res["mode"] = DragMode.DRAG_EVENT_RESIZE_END
			else:
				res["mode"] = DragMode.DRAG_EVENT_MOVE
			break
	return res

func _initialize_missing_event_tracks() -> void:
	var events: Array = chart_data.get("events", [])
	var tracks = []
	tracks.resize(events.size())
	
	for i in range(events.size()):
		var ev = events[i]
		if ev.has("track"):
			tracks[i] = ev["track"]
			continue
			
		var ev_start: float = float(ev.get("time", 0.0))
		var ev_end: float = ev_start + float(ev.get("duration", 3.0))
		
		var used_tracks = {}
		for j in range(i):
			var prev_ev = events[j]
			var prev_start: float = float(prev_ev.get("time", 0.0))
			var prev_end: float = prev_start + float(prev_ev.get("duration", 3.0))
			
			if ev_start < prev_end and ev_end > prev_start:
				used_tracks[tracks[j]] = true
				
		var assigned_track = 0
		while used_tracks.has(assigned_track):
			assigned_track += 1
		ev["track"] = assigned_track
		tracks[i] = assigned_track
		
	# 트랙이 생성되었으므로 자동 저장
	_save_chart_file()
func _push_undo() -> void:
	var snapshot = chart_data.duplicate(true)
	undo_stack.append(snapshot)
	if undo_stack.size() > MAX_UNDO_STEPS:
		undo_stack.remove_at(0)
	redo_stack.clear()

func _undo() -> void:
	if undo_stack.size() > 0:
		var snapshot = undo_stack.pop_back()
		redo_stack.append(chart_data.duplicate(true))
		chart_data = snapshot
		_sort_events()
		_save_chart_file()
		_update_ui_from_event()
		preview_canvas.queue_redraw()
		timeline.queue_redraw()
		_show_toast("Undo (실행 취소)")

func _redo() -> void:
	if redo_stack.size() > 0:
		var snapshot = redo_stack.pop_back()
		undo_stack.append(chart_data.duplicate(true))
		chart_data = snapshot
		_sort_events()
		_save_chart_file()
		_update_ui_from_event()
		preview_canvas.queue_redraw()
		timeline.queue_redraw()
		_show_toast("Redo (다시 실행)")


func _on_instant_test_pressed() -> void:
	if is_playing:
		audio_player.stop()
	Global.is_editor_test_mode = true
	Global.editor_test_start_time = current_time
	_save_chart_file()
	_show_toast("Launching Instant Test...")
	SceneTransition.transition_to_scene("res://scenes/game/game.tscn")


func _on_browse_texture_pressed() -> void:
	if selected_event_index == -1:
		_show_toast("Select an event first!")
		return
		
	var filters = PackedStringArray(["*.png ; PNG Images", "*.jpg,*.jpeg ; JPEG Images", "*.webp ; WebP Images"])
	var user_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	
	DisplayServer.file_dialog_show(
		"Select Image File",
		user_dir,
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		filters,
		_on_native_file_selected
	)

func _on_native_file_selected(status: bool, selected_paths: PackedStringArray, selected_filter_index: int) -> void:
	if not status or selected_paths.is_empty():
		return
	_on_texture_file_selected(selected_paths[0])

func _on_texture_file_selected(path: String) -> void:
	if selected_event_index == -1: return
	
	var file_name = path.get_file()
	var dest_dir = MUSIC_BASE_PATH + selected_song + "/img/"
	var dest_path = dest_dir + file_name
	
	# img 폴더 자동 생성
	if not DirAccess.dir_exists_absolute(dest_dir):
		var err = DirAccess.make_dir_recursive_absolute(dest_dir)
		if err != OK:
			_show_toast("Failed to create img folder!")
			return
			
	# 파일 복제
	var err = DirAccess.copy_absolute(path, dest_path)
	if err != OK and err != ERR_ALREADY_EXISTS:
		_show_toast("Failed to copy image!")
		return
		
	# Undo 히스토리 보관 및 차트 경로 업데이트
	_push_undo()
	var ev = chart_data["events"][selected_event_index]
	ev["texture_path"] = dest_path
	
	_save_chart_file()
	_update_ui_from_event()
	preview_canvas.queue_redraw()
	_show_toast("Image imported to: " + file_name)
