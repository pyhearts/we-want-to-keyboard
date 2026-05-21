extends Control

const MUSIC_BASE_PATH := "res://assets/musics/"
const CHART_EDITOR_SCENE := "res://scenes/menu/chart_editor.tscn"

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

# 오디오
var audio_player: AudioStreamPlayer
var song_duration: float = 0.0

# 선택/호버
var selected_event_index: int = -1
var hover_event_index: int = -1
var drag_offset := Vector2.ZERO
var is_dragging: bool = false

# 테마 색상 (chart_editor와 동일)
const COLOR_BG_CANVAS := Color(1.0, 0.960784, 0.968627, 1.0)        # #FFF5F7
const COLOR_BORDER_CANVAS := Color(1.0, 0.560784, 0.639216, 0.8)    # #FF8FA3
const COLOR_GRID_CANVAS := Color(1.0, 0.815686, 0.854902, 0.4)      # #FFE3E8
const COLOR_TEXT_WINE := Color(0.290196, 0.0823529, 0.129412, 1.0)   # #4A1521
const COLOR_TEXT_WINE_MUTED := Color(0.541176, 0.352941, 0.396078, 1.0) # #8A5A65

# 이펙트 렌더링 색상
const COLOR_EVENT_WINDOW := Color(0.3, 0.6, 0.9, 0.6)
const COLOR_EVENT_IMAGE := Color(0.9, 0.4, 0.6, 0.6)
const COLOR_EVENT_SELECTED := Color(1.0, 0.84, 0.0, 1.0) # Gold Yellow

const COLOR_BG_TIMELINE := Color(1.0, 0.898039, 0.92549, 1.0)       # #FFE5EC
const COLOR_HEADER_TIMELINE := Color(1.0, 0.0, 0.329412, 0.95)     # #FF0054
const COLOR_GRID_TIMELINE_MAIN := Color(0.788235, 0.0941176, 0.290196, 0.6) # #C9184A
const COLOR_GRID_TIMELINE_SUB := Color(1.0, 0.760784, 0.819608, 0.5)  # #FFC2D1

# 이펙트 매핑
const EFFECT_TYPES := [
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
	var path := MUSIC_BASE_PATH + selected_song + "/chart.json"
	if not FileAccess.file_exists(path):
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
		
	_sort_events()

func _sort_events() -> void:
	if chart_data.has("events") and chart_data["events"] is Array:
		chart_data["events"].sort_custom(func(a, b):
			return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
		)

func _save_chart_file() -> void:
	var path := MUSIC_BASE_PATH + selected_song + "/chart.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
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
		
	_update_time_label()

func _update_time_label() -> void:
	var cur_min := int(current_time) / 60
	var cur_sec := int(current_time) % 60
	var cur_ms := int((current_time - int(current_time)) * 1000)
	
	var total_min := int(song_duration) / 60
	var total_sec := int(song_duration) % 60
	var total_ms := int((song_duration - int(song_duration)) * 1000)
	
	time_label.text = "%02d:%02d.%03d / %02d:%02d.%03d" % [cur_min, cur_sec, cur_ms, total_min, total_sec, total_ms]

func get_snapped_time(raw_time: float) -> float:
	if snap_division <= 1:
		return raw_time
	var beat_length := 60.0 / bpm
	var step := beat_length * (4.0 / snap_division)
	var snapped: float = round(raw_time / step) * step
	return clamp(snapped, 0.0, song_duration)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit:
			return
			
		if event.keycode == KEY_SPACE:
			_on_play_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if is_playing:
				audio_player.stop()
			get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DELETE:
			if selected_event_index != -1:
				_delete_event(selected_event_index)
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
			var step := 0.1
			var is_ctrl := Input.is_key_pressed(KEY_CTRL)
			if is_ctrl:
				step = 60.0 / bpm
			if event.keycode == KEY_LEFT:
				_seek_time(current_time - step)
			else:
				_seek_time(current_time + step)
			get_viewport().set_input_as_handled()

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
	var val := float(new_text)
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
	var res_path := MUSIC_BASE_PATH + selected_song + "/Res.tres"
	if FileAccess.file_exists(res_path):
		var music_res = load(res_path)
		if music_res:
			music_res.set("bpm", bpm)
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
	var new_event = {
		"time": snap_time,
		"type": "window",
		"x": 860,
		"y": 440,
		"width": 200,
		"height": 200,
		"duration": 3.0,
		"opacity": 1.0,
		"title": "Event Window",
		"texture_path": ""
	}
	chart_data["events"].append(new_event)
	_sort_events()
	selected_event_index = chart_data["events"].find(new_event)
	_update_ui_from_event()
	_save_chart_file()
	_show_toast("Event added at " + "%0.2f" % snap_time + "s")
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
		var logical_pos := Vector2(local_pos.x / sx, local_pos.y / sy)
		
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_setting_start:
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
					var rect := Rect2(cur_pos, Vector2(ev_w, ev_h))
					if rect.has_point(logical_pos):
						clicked_idx = i
						break
						
			if clicked_idx != -1:
				selected_event_index = clicked_idx
				var ev = events[selected_event_index]
				var cur_pos: Vector2 = _get_event_current_pos(ev, current_time)
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
		var logical_pos := Vector2(local_pos.x / sx, local_pos.y / sy)
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
	var start_pos := Vector2(sx, sy)
	
	if "moving" in etype and ev_dur > 0:
		var tx: float = float(ev.get("target_x", ev.get("to_x", sx)))
		var ty: float = float(ev.get("target_y", ev.get("to_y", sy)))
		var target_pos := Vector2(tx, ty)
		
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
	var font := get_theme_font("font")
	
	for i in range(events.size()):
		var ev = events[i]
		var ev_time: float = float(ev.get("time", 0.0))
		var ev_dur: float = float(ev.get("duration", 3.0))
		
		if current_time >= ev_time and current_time <= ev_time + ev_dur:
			var etype: String = ev.get("type", "window")
			var ev_w: int = int(ev.get("width", 200))
			var ev_h: int = int(ev.get("height", 200))
			var cur_pos: Vector2 = _get_event_current_pos(ev, current_time)
			
			var rect_scaled := Rect2(cur_pos * Vector2(sx, sy), Vector2(ev_w * sx, ev_h * sy))
			var opac: float = float(ev.get("opacity", 1.0))
			
			var fill_color := COLOR_EVENT_WINDOW
			if "image" in etype:
				fill_color = COLOR_EVENT_IMAGE
				
			fill_color.a = opac * 0.5
			preview_canvas.draw_rect(rect_scaled, fill_color)
			
			var border_color := fill_color
			border_color.a = opac
			var is_sel: bool = (i == selected_event_index)
			var border_w: float = 4.0 if is_sel else 2.0
			if is_sel:
				border_color = COLOR_EVENT_SELECTED
				
			preview_canvas.draw_rect(rect_scaled, border_color, false, border_w)
			
			var bar_h: float = 20.0 * sy
			var bar_rect := Rect2(rect_scaled.position, Vector2(rect_scaled.size.x, bar_h))
			var bar_color := COLOR_TEXT_WINE
			bar_color.a = opac * 0.8
			preview_canvas.draw_rect(bar_rect, bar_color)
			
			var display_title: String = ev.get("title", "Window") if "window" in etype else "Image"
			var text_pos := bar_rect.position + Vector2(5.0 * sx, 15.0 * sy)
			preview_canvas.draw_string(font, text_pos, display_title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * sy), COLOR_BG_CANVAS)
			
			if "moving" in etype and is_sel:
				var sp := Vector2(float(ev.get("x", 860)), float(ev.get("y", 440))) * Vector2(sx, sy)
				var tp := Vector2(float(ev.get("target_x", ev.get("to_x", ev.get("x", 860)))), float(ev.get("target_y", ev.get("to_y", ev.get("y", 440))))) * Vector2(sx, sy)
				
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
	var pixels_per_second: float = 150.0
	var beat_length: float = 60.0 / bpm
	
	var view_start_time: float = current_time - (center_x / pixels_per_second)
	var view_end_time: float = current_time + (center_x / pixels_per_second)
	
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
	var font := get_theme_font("font")
	
	for idx in range(first_beat_index, last_beat_index + 1):
		var t: float = idx * beat_length
		var dx: float = (t - current_time) * pixels_per_second
		var lx: float = center_x + dx
		
		timeline.draw_line(Vector2(lx, 15), Vector2(lx, timeline_h), COLOR_GRID_TIMELINE_MAIN, 2.0)
		var beat_str := str(idx)
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
			
		var bar_y: float = timeline_h / 2.0 - 15.0
		var bar_h: float = 30.0
		var rect := Rect2(lx, bar_y, dw, bar_h)
		
		timeline.draw_rect(rect, bar_color)
		timeline.draw_rect(rect, COLOR_TEXT_WINE, false, 1.5)
		
		var info_text = etype.replace("window_moving_", "mv_").replace("image_moving_", "mv_img_")
		if ev.has("title") and ev["title"] != "":
			info_text += " (" + ev["title"] + ")"
		timeline.draw_string(font, Vector2(lx + 5, timeline_h / 2.0 + 4.0), info_text, HORIZONTAL_ALIGNMENT_LEFT, dw - 10, 11, COLOR_TEXT_WINE)
func _on_timeline_gui_input(event: InputEvent) -> void:
	var timeline_w: float = timeline.size.x
	if timeline_w == 0: return
	var center_x: float = timeline_w / 2.0
	var pixels_per_second: float = 150.0
	
	if event is InputEventMouseButton:
		var local_x: float = event.position.x
		var dx: float = local_x - center_x
		var dt: float = dx / pixels_per_second
		var target_time: float = current_time + dt
		
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_idx: int = -1
			var events: Array = chart_data.get("events", [])
			for i in range(events.size()):
				var ev = events[i]
				var ev_time: float = float(ev.get("time", 0.0))
				var ev_dur: float = float(ev.get("duration", 3.0))
				
				var edx: float = (ev_time - current_time) * pixels_per_second
				var elx: float = center_x + edx
				var edw: float = ev_dur * pixels_per_second
				var ey: float = timeline.size.y / 2.0 - 15.0
				var eh: float = 30.0
				
				var rect := Rect2(elx, ey, edw, eh)
				if rect.has_point(event.position):
					clicked_idx = i
					break
					
			if clicked_idx != -1:
				selected_event_index = clicked_idx
				_update_ui_from_event()
				preview_canvas.queue_redraw()
				timeline.queue_redraw()
			else:
				var is_ctrl := Input.is_key_pressed(KEY_CTRL)
				if is_ctrl:
					target_time = get_snapped_time(target_time)
				_seek_time(target_time)
				
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var local_x: float = event.position.x
		var dx: float = local_x - center_x
		var dt: float = dx / pixels_per_second
		var target_time: float = current_time + dt
		_seek_time(target_time)
