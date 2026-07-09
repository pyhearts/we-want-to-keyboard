extends Control

const MUSIC_BASE_PATH = "res://assets/musics/"
const GLOBAL_TIMING_OFFSET = 0.7
const MAIN_MENU_SCENE = "res://scenes/menu/main_menu.tscn"


func _chart_time_to_audio_pos(chart_time: float) -> float:
	return chart_time - GLOBAL_TIMING_OFFSET + offset


func _audio_pos_to_chart_time(audio_pos: float) -> float:
	return audio_pos + GLOBAL_TIMING_OFFSET - offset


func _get_timeline_display_time(note: Dictionary) -> float:
	var note_time = float(note.get("time", 0.0))
	var note_type = str(note.get("type", "normal"))
	if note_type == "normal" or note_type == "moving":
		return note_time + GLOBAL_TIMING_OFFSET
	return note_time


func _editor_time_to_note_time(note_type: String, editor_time: float) -> float:
	if note_type == "normal" or note_type == "moving":
		return max(0.0, editor_time - GLOBAL_TIMING_OFFSET)
	return max(0.0, editor_time)


func _is_hard_chart_title(title: String) -> bool:
	return title.strip_edges().ends_with("Hard")


func _uses_difficulty_filter() -> bool:
	return not _is_hard_chart_title(selected_song)
# UI ?몃뱶 諛붿씤??
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
var note_count_label: Label
var _prev_note_count_over_limit: bool = false
var moving_settings: VBoxContainer
var start_x_input: LineEdit
var start_y_input: LineEdit
var set_start_btn: Button
var is_setting_start_pos: bool = false

# --- ?щЪ???쒕옒洹?紐⑤뱶 ?곹깭 ---
var is_curve_draw_mode: bool = false       # 怨≪꽑 ?쒕옒洹?紐⑤뱶 ?쒖꽦???щ?
var is_curve_dragging: bool = false        # ?꾩옱 留덉슦???쒕옒洹?以??щ?
var curve_drag_start: Vector2 = Vector2.ZERO   # 留덉슦???꾨Ⅸ ?쒖옉??(?쇰━ 醫뚰몴)
var curve_drag_end: Vector2 = Vector2.ZERO     # 留덉슦??? ?앹젏 (?쇰━ 醫뚰몴)
var curve_drag_current: Vector2 = Vector2.ZERO # ?ㅼ떆媛?留덉슦???꾩튂 (?쇰━ 醫뚰몴)
var curve_drag_max_deviation: float = 0.0  # ?쒕옒洹?以?理쒕? ?댄깉 嫄곕━
var curve_drag_side: float = 1.0           # ?댄깉 諛⑺뼢 遺??(+1 ?먮뒗 -1)

# --- 以묐젰 ?좉? 諛??대룞 ?쒓컙 ---
var use_gravity_check: CheckBox = null
var moving_duration_input: LineEdit = null
var draw_curve_btn: Button = null
var moving_duration: float = 1.0

# --- ?몄쓽 湲곕뒫 愿??異붽? 蹂??---
var bookmarks: Dictionary = {}             # 遺곷쭏??(Alt+1~5 ??? 1~5 ?대룞)
var timeline_zoom: float = 1.0             # ??꾨씪??留덉슦????以?諛곗쑉
var autosave_timer: float = 0.0            # ?먮룞 ??μ슜 ?꾩쟻 ??대㉧

# --- ?ㅽ넗?뚮젅??諛?由ы뵆 ?④낵 蹂??---
var is_autoplay: bool = false
var autoplay_hit_notes: Dictionary = {}
var autoplay_ripples: Array = []

# --- 援ш컙 ?ъ깮 諛?諛섎났 ?ъ깮 (Region Selection & Looping) ---
var region_start_time: float = -1.0
var region_end_time: float = -1.0
var is_region_loop: bool = true
var is_view_region_only: bool = false
var regions: Array = []
var selected_region_index: int = -1

# --- ?뚰삎 怨좏빐?곷룄 ?쒓컖??蹂??---
var waveform_data: Dictionary = {}
var is_waveform_loaded: bool = false
var is_playing_region: bool = false
var is_dragging_region: bool = false
var drag_start_time: float = 0.0

var region_settings_box: VBoxContainer = null
var region_lbl_info: Label = null
var region_list_label: Label = null
var region_loop_check: CheckBox = null
var region_view_check: CheckBox = null
var region_play_btn: Button = null

# ?먮뵒???곹깭 蹂??
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

# Hold ?명듃 ?ㅼ젙 湲곕낯媛?
var hold_duration: float = 3.0
var hold_division: int = 16

# ?ㅻ뵒???뚮젅?댁뼱
var audio_player: AudioStreamPlayer
var song_duration: float = 0.0

# ?명듃 議곗옉 愿??
var hover_note_index: int = -1
var selected_note_index: int = -1
var drag_offset = Vector2.ZERO
var is_dragging_note: bool = false
var undo_stack: Array = []
var redo_stack: Array = []
const MAX_UNDO_DEPTH: int = 50
var copied_note_data: Dictionary = {}

# ?묓겕 ?뚮쭏 而щ윭 ?곸닔
# New variables for mouse hover tracking and allowed distance guide
var mouse_logical_pos: Vector2 = Vector2.ZERO
var is_mouse_hovering_canvas: bool = false

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
const COLOR_HEADER_TIMELINE = Color(1.0, 0.0, 0.329412, 0.95)     # #FF0054 (?ъ깮?ㅻ뱶)
const COLOR_GRID_TIMELINE_MAIN = Color(0.788235, 0.0941176, 0.290196, 0.6) # #C9184A (1鍮꾪듃??
const COLOR_GRID_TIMELINE_SUB = Color(1.0, 0.760784, 0.819608, 0.5)  # #FFC2D1 (?ㅻ깄??
const MIN_REGION_DURATION = 0.05

func _ready() -> void:
	# AudioStreamPlayer ?앹꽦 諛???異붽?
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

	# ?쒕∼?ㅼ슫 珥덇린??
	_setup_dropdowns()

	# ?대깽??諛붿씤??
	song_select.item_selected.connect(_on_song_selected)
	snap_select.item_selected.connect(_on_snap_selected)
	type_select.item_selected.connect(_on_type_selected)
	speed_select.item_selected.connect(_on_speed_selected)

	play_button.pressed.connect(_on_play_pressed)

	bpm_input.text_submitted.connect(_on_bpm_submitted)
	offset_input.text_submitted.connect(_on_offset_submitted)
	duration_input.text_submitted.connect(_on_hold_duration_submitted)
	division_input.text_submitted.connect(_on_hold_division_submitted)

	# ?꾨━酉?罹붾쾭??留덉슦???낅젰 ?대깽??
	preview_canvas.gui_input.connect(_on_canvas_gui_input)
	preview_canvas.mouse_exited.connect(_on_preview_canvas_mouse_exited)
	timeline.gui_input.connect(_on_timeline_gui_input)

	# ?좎뒪???щ챸??珥덇린??
	toast.modulate.a = 0.0

	# 怨?紐⑸줉 濡쒕뱶
	_load_song_list()

	# 泥?踰덉㎏ 怨??먮룞 濡쒕뱶
	if song_select.item_count > 0:
		_on_song_selected(0)

	_setup_top_bar()
	_setup_moving_settings_ui()
	_setup_region_settings_ui()
	_setup_note_count_ui()

	# ?먮뵒???뚯뒪??紐⑤뱶?먯꽌 ?뚭? ???쒓컙 蹂듦뎄 諛??뺣━
	if Global.is_editor_test_mode:
		current_time = Global.editor_test_start_time
		Global.is_editor_test_mode = false
		_seek_time(current_time)

func _setup_dropdowns() -> void:
	# 洹몃━???ㅻ깄 遺꾩＜ ?ㅼ젙
	snap_select.clear()
	snap_select.add_item("No Snap (Free)", 1)
	snap_select.add_item("4 Beats", 4)
	snap_select.add_item("8 Beats", 8)
	snap_select.add_item("16 Beats", 16)
	snap_select.add_item("32 Beats", 32)
	snap_select.selected = 3 # 16 Beats 湲곕낯媛?
	snap_division = 16

	# ?명듃 ????ㅼ젙
	type_select.clear()
	type_select.add_item("Normal Note", 0)
	type_select.add_item("Moving Note", 1)
	type_select.add_item("Hold Note", 2)
	type_select.selected = 0
	hold_settings.visible = false

	# ?ъ깮 諛곗냽 ?ㅼ젙
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

	# ?뚯븙 ?뚯씪 諛?BPM 由ъ냼??濡쒕뱶
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

	# UI ?숆린??
	bpm_input.text = str(bpm)
	offset_input.text = str(offset)

	# ?ㅻ뵒???뚮젅?댁뼱 ?명똿
	if audio_player.stream:
		song_duration = audio_player.stream.get_length()
	else:
		song_duration = 180.0 # ?덈퉬 3遺?

	# 怨좏빐?곷룄 二쇳뙆?섎퀎 ?뚰삎 濡쒕뵫 ?쒖옉
	_load_waveform_data()

	current_time = 0.0
	is_playing = false
	audio_player.stop()
	play_button.text = "Play"

	# 梨꾨낫 濡쒕뱶
	_load_chart()

	# 罹붾쾭??媛깆떊
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
		_load_editor_region_from_chart()
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

			# 援щ쾭??李⑦듃 醫뚰몴 蹂댁젙 (offset_corrected ?뚮옒洹멸? ?녿뒗 寃쎌슦)
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

	_load_editor_region_from_chart()
	_sort_chart()

func _sort_chart() -> void:
	if chart_data.has("notes") and chart_data["notes"] is Array:
		chart_data["notes"].sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))

func _load_editor_region_from_chart() -> void:
	region_start_time = -1.0
	region_end_time = -1.0
	is_region_loop = true
	is_view_region_only = false
	regions = []
	selected_region_index = -1

	var editor_data = chart_data.get("editor", {})
	if not editor_data is Dictionary:
		return
	var regions_data = editor_data.get("regions", [])
	if regions_data is Array:
		for region in regions_data:
			if region is Dictionary:
				var start_time = clamp(float(region.get("start", -1.0)), -1.0, song_duration)
				var end_time = clamp(float(region.get("end", -1.0)), -1.0, song_duration)
				if start_time >= 0.0 and end_time > start_time:
					regions.append({
						"start": start_time,
						"end": end_time,
						"name": str(region.get("name", "Region %d" % (regions.size() + 1))),
						"enabled": bool(region.get("enabled", true))
					})
		_sort_regions()
		if regions.size() > 0:
			selected_region_index = 0
			region_start_time = float(regions[0]["start"])
			region_end_time = float(regions[0]["end"])

	var region_data = editor_data.get("region", {})
	if region_data is Dictionary:
		is_region_loop = bool(region_data.get("loop", true))
		is_view_region_only = bool(region_data.get("view_only", false))
		if regions.is_empty():
			region_start_time = clamp(float(region_data.get("start", -1.0)), -1.0, song_duration)
			region_end_time = clamp(float(region_data.get("end", -1.0)), -1.0, song_duration)
			if _has_valid_region():
				regions.append({
					"start": region_start_time,
					"end": region_end_time,
					"name": "Region 1",
					"enabled": true
				})
				selected_region_index = 0

	if not _has_valid_region():
		region_start_time = -1.0
		region_end_time = -1.0
		is_view_region_only = false
	_update_region_ui()

func _save_editor_region_to_chart() -> void:
	if not chart_data.has("editor") or not chart_data["editor"] is Dictionary:
		chart_data["editor"] = {}
	_sort_regions()
	chart_data["editor"]["regions"] = regions.duplicate(true)
	chart_data["editor"]["region"] = {
		"start": region_start_time,
		"end": region_end_time,
		"loop": is_region_loop,
		"view_only": is_view_region_only
	}
	_save_chart_file()

func _has_valid_region() -> bool:
	return region_start_time >= 0.0 and region_end_time > region_start_time

func _has_enabled_regions() -> bool:
	for region in regions:
		if region is Dictionary and bool(region.get("enabled", true)):
			return true
	return false

func _sort_regions() -> void:
	regions.sort_custom(func(a, b): return float(a.get("start", 0.0)) < float(b.get("start", 0.0)))
	_merge_overlapping_regions()

func _merge_overlapping_regions() -> void:
	if regions.size() <= 1:
		return
	var merged: Array = []
	for region in regions:
		if not region is Dictionary:
			continue
		var start_time = float(region.get("start", -1.0))
		var end_time = float(region.get("end", -1.0))
		if start_time < 0.0 or end_time <= start_time:
			continue
		if merged.is_empty():
			merged.append(region.duplicate(true))
			continue
		var last_region = merged[merged.size() - 1]
		var last_end = float(last_region.get("end", -1.0))
		if start_time <= last_end + 0.001:
			last_region["end"] = max(last_end, end_time)
			last_region["enabled"] = bool(last_region.get("enabled", true)) or bool(region.get("enabled", true))
		else:
			merged.append(region.duplicate(true))
	regions = merged

func _sync_selected_region_from_current() -> void:
	if selected_region_index >= 0 and selected_region_index < regions.size() and _has_valid_region():
		var old_start = region_start_time
		regions[selected_region_index]["start"] = region_start_time
		regions[selected_region_index]["end"] = region_end_time
		_sort_regions()
		selected_region_index = _find_region_containing_time(old_start)
		if selected_region_index >= 0:
			region_start_time = float(regions[selected_region_index].get("start", region_start_time))
			region_end_time = float(regions[selected_region_index].get("end", region_end_time))

func _find_region_index(start_time: float, end_time: float) -> int:
	for i in range(regions.size()):
		var region = regions[i]
		if region is Dictionary and absf(float(region.get("start", -1.0)) - start_time) < 0.001 and absf(float(region.get("end", -1.0)) - end_time) < 0.001:
			return i
	return -1

func _add_current_region_to_list() -> void:
	if not _has_valid_region():
		_show_toast("Set Start & End first!")
		return
	if region_end_time - region_start_time < MIN_REGION_DURATION:
		_show_toast("Region too short")
		return
	var existing_idx = _find_region_index(region_start_time, region_end_time)
	if existing_idx != -1:
		selected_region_index = existing_idx
		_update_region_ui()
		return
	regions.append({
		"start": region_start_time,
		"end": region_end_time,
		"name": "Region %d" % (regions.size() + 1),
		"enabled": true
	})
	_sort_regions()
	selected_region_index = _find_region_containing_time(region_start_time)
	if selected_region_index >= 0:
		region_start_time = float(regions[selected_region_index].get("start", region_start_time))
		region_end_time = float(regions[selected_region_index].get("end", region_end_time))
	_save_editor_region_to_chart()
	_update_region_ui()
	timeline.queue_redraw()

func _find_region_containing_time(time_val: float) -> int:
	for i in range(regions.size()):
		var region = regions[i]
		if region is Dictionary and time_val >= float(region.get("start", -1.0)) and time_val <= float(region.get("end", -1.0)):
			return i
	return -1

func _delete_selected_region() -> void:
	if selected_region_index < 0 or selected_region_index >= regions.size():
		_show_toast("No region selected")
		return
	regions.remove_at(selected_region_index)
	selected_region_index = min(selected_region_index, regions.size() - 1)
	if selected_region_index >= 0:
		region_start_time = float(regions[selected_region_index].get("start", -1.0))
		region_end_time = float(regions[selected_region_index].get("end", -1.0))
	else:
		region_start_time = -1.0
		region_end_time = -1.0
	_save_editor_region_to_chart()
	_update_region_ui()
	timeline.queue_redraw()

func _select_region(index: int) -> void:
	if index < 0 or index >= regions.size():
		return
	selected_region_index = index
	region_start_time = float(regions[index].get("start", -1.0))
	region_end_time = float(regions[index].get("end", -1.0))
	_update_region_ui()
	timeline.queue_redraw()

func _select_previous_region() -> void:
	if regions.is_empty():
		_show_toast("No regions")
		return
	_select_region(max(selected_region_index - 1, 0))

func _select_next_region() -> void:
	if regions.is_empty():
		_show_toast("No regions")
		return
	_select_region(min(selected_region_index + 1, regions.size() - 1))

func _is_note_in_view_region(note: Dictionary) -> bool:
	if not is_view_region_only or (not _has_valid_region() and not _has_enabled_regions()):
		return true
	var note_start = _get_timeline_display_time(note)
	var note_end = note_start
	if str(note.get("type", "normal")) == "hold":
		note_end += float(note.get("duration", 3.0))
	return _time_span_in_any_region(note_start, note_end)

func _time_span_in_any_region(start_time: float, end_time: float) -> bool:
	if _has_enabled_regions():
		for region in regions:
			if not region is Dictionary or not bool(region.get("enabled", true)):
				continue
			if start_time <= float(region.get("end", -1.0)) and end_time >= float(region.get("start", -1.0)):
				return true
		return false
	if _has_valid_region():
		return start_time <= region_end_time and end_time >= region_start_time
	return true

func _clamp_to_active_time_range(target: float) -> float:
	if is_view_region_only and _has_enabled_regions():
		for region in regions:
			if not region is Dictionary or not bool(region.get("enabled", true)):
				continue
			var start_time = float(region.get("start", -1.0))
			var end_time = float(region.get("end", -1.0))
			if target >= start_time and target <= end_time:
				return target
			if target < start_time:
				return start_time
		return float(regions[regions.size() - 1].get("end", song_duration))
	if is_view_region_only and _has_valid_region():
		return clamp(target, region_start_time, region_end_time)
	return clamp(target, 0.0, song_duration)

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
		# ?ㅻ뵒???ъ??섏쓣 留??꾨젅??媛뺤젣 ?숆린?뷀븯吏 ?딄퀬 CPU ?뺣? delta瑜??꾩쟻?섏뿬 ?꾩쟻 諛由?Drift) ?먯쿇 李⑤떒
		current_time += delta * playback_speed

		if audio_player.playing:
			var audio_pos = audio_player.get_playback_position()
			# Match the same chart-time/audio-time mapping used by gameplay.
			var expected_audio_pos = _chart_time_to_audio_pos(current_time)

			if expected_audio_pos < 0.0:
				if audio_player.playing:
					audio_player.stop()
			else:
				if not audio_player.playing:
					audio_player.play(expected_audio_pos)

			# ?κ린?곸씤 ?ㅻ쾭???몃뜑??諛⑹???蹂댁젙 肄붾뱶 (150ms ?댁긽 李⑥씠 諛쒖깮 ???섎뱶 ?깊겕)
			var current_audio_time = _audio_pos_to_chart_time(audio_pos)
			if absf(current_time - current_audio_time) > 0.15:
				current_time = current_audio_time
		else:
			# ?ъ깮???꾩쟾???앸궃 ?곹깭 ?먮뒗 珥덇린 ?湲??곹깭
			var expected_audio_pos = _chart_time_to_audio_pos(current_time)
			if expected_audio_pos >= 0.0 and expected_audio_pos < song_duration:
				audio_player.pitch_scale = playback_speed
				audio_player.play(expected_audio_pos)

			# 珥?怨?湲몄씠瑜?珥덇낵?섎㈃ ?ъ깮 ?뺤?
			if current_time >= song_duration:
				current_time = song_duration
				_on_play_pressed() # Pause ?먮룞 ?뺤?

	# ?쒓컙 珥덇낵 蹂댁젙
	if current_time < 0:
		current_time = 0.0

	# ?쒓컙 ?쒖떆 媛깆떊
	_update_time_label()

	# 援ш컙 ?ъ깮 猷⑦봽 諛??뺤? 泥섎━
	if is_playing and (is_playing_region or is_view_region_only) and _has_valid_region():
		if current_time >= region_end_time:
			if is_region_loop:
				_seek_time(region_start_time)
			else:
				if is_playing:
					_on_play_pressed()
				is_playing_region = false
				_show_toast("Region Completed")

	# ?먮룞 ?????대㉧ 泥섎━
	autosave_timer += delta
	if autosave_timer >= 60.0:
		autosave_timer = 0.0
		_auto_save_backup()

	# ?ㅽ넗?뚮젅???덊듃 諛??댄럺??泥섎━
	if is_playing and is_autoplay:
		var notes = chart_data.get("notes", [])
		for i in range(notes.size()):
			var note = notes[i]
			var note_time = _get_timeline_display_time(note)
			if current_time >= note_time and current_time < note_time + 0.15:
				if not autoplay_hit_notes.has(i):
					autoplay_hit_notes[i] = true
					Global.play_hit_sound()
					_trigger_autoplay_hit_effect(note)

	# ?ㅽ넗?뚮젅??由ы뵆 ?섎챸 媛깆떊
	for i in range(autoplay_ripples.size() - 1, -1, -1):
		autoplay_ripples[i]["life"] -= delta
		if autoplay_ripples[i]["life"] <= 0.0:
			autoplay_ripples.remove_at(i)

	# 罹붾쾭??諛???꾨씪??媛깆떊
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
	_update_note_count()

func _setup_note_count_ui() -> void:
	note_count_label = Label.new()
	note_count_label.name = "NoteCountLabel"
	note_count_label.layout_mode = 2
	note_count_label.add_theme_color_override("font_color", Color(0.482353, 0.223529, 0.286275, 1.0))
	note_count_label.add_theme_font_size_override("font_size", 12)
	note_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_count_label.text = "Total Notes: 0\n(Normal: 0 | Moving: 0 | Hold: 0)"

	var playback_section = time_label.get_parent()
	playback_section.add_child(note_count_label)

func _update_note_count() -> void:
	if not note_count_label:
		return
	var total = 0
	var normal = 0
	var moving = 0
	var hold = 0
	if chart_data and chart_data.has("notes") and chart_data["notes"] is Array:
		var notes = chart_data["notes"]
		total = notes.size()
		for note in notes:
			if note is Dictionary:
				var type = note.get("type", "normal")
				if type == "moving":
					moving += 1
				elif type == "hold":
					hold += 1
				else:
					normal += 1
	var max_notes = int(song_duration / Global.note_limit_seconds_interval)
	if _uses_difficulty_filter() and total > max_notes:
		if not _prev_note_count_over_limit:
			_show_toast("WARNING: Over Limit (%d notes max)! (In-game play disabled)" % max_notes)
			_prev_note_count_over_limit = true
		note_count_label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15, 1.0))
		note_count_label.text = "Total Notes: %d / Max: %d (EXCEEDED!)\n(Normal: %d | Moving: %d | Hold: %d)" % [total, max_notes, normal, moving, hold]
	else:
		_prev_note_count_over_limit = false
		note_count_label.add_theme_color_override("font_color", Color(0.482353, 0.223529, 0.286275, 1.0))
		note_count_label.text = "Total Notes: %d / Max: %d\n(Normal: %d | Moving: %d | Hold: %d)" % [total, max_notes, normal, moving, hold]

# ==========================================
# ?ㅻ깄 ?곗궛
# ==========================================
func get_snapped_time(raw_time: float) -> float:
	if snap_division <= 1:
		return max(0.0, raw_time)
	var beat_length = 60.0 / bpm
	var step = beat_length * (4.0 / snap_division)
	var snapped: float = round(raw_time / step) * step
	return max(0.0, snapped)


func _get_timeline_note_preview_duration() -> float:
	if snap_division <= 1:
		return 0.25 * Global.editor_timeline_note_preview_steps
	var beat_length = 60.0 / bpm
	return beat_length * (4.0 / float(snap_division)) * Global.editor_timeline_note_preview_steps


func _get_timeline_step_duration() -> float:
	if snap_division <= 1:
		return 0.25
	var beat_length = 60.0 / bpm
	return beat_length * (4.0 / float(snap_division))


func _get_timeline_note_alpha(note_time: float) -> float:
	var preview_duration = _get_timeline_note_preview_duration()
	if current_time >= note_time:
		return 1.0
	if preview_duration <= 0.001:
		return 0.0
	return clamp(1.0 - ((note_time - current_time) / preview_duration), 0.0, 1.0)


func _get_note_pre_appear_alpha(note_time: float) -> float:
	return _get_timeline_note_alpha(note_time)

# ==========================================
# ?낅젰 肄쒕갚 諛??대깽??
# ==========================================
func _input(event: InputEvent) -> void:
	# ESC ?꾨Ⅴ硫?硫붿씤 硫붾돱濡??섍?湲?
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_playing:
			audio_player.stop()
		get_viewport().set_input_as_handled()
		SceneTransition.transition_to_scene(MAIN_MENU_SCENE)
		return

	# Space ?꾨Ⅴ硫??ъ깮 / ?뺤?
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner == null or not (focus_owner is LineEdit):
			get_viewport().set_input_as_handled()
			if event is InputEventWithModifiers and event.shift_pressed:
				_on_play_region_pressed()
			else:
				_on_play_pressed()
			return

	# --- ?몄쓽 湲곕뒫 ?⑥텞??紐⑥쓬 ---
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner == null or not (focus_owner is LineEdit):
			# A. 遺곷쭏??湲곕뒫 (Alt+1~5 ??? 1~5 ?대룞)
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

			# B. ?명듃 誘몃윭留?(H: 醫뚯슦 諛섏쟾, V: ?곹븯 諛섏쟾)
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

			# C. ?좏깮???명듃 ?쒓컙 誘몄꽭 ?대룞 (PageUp: ???ㅻ깄 鍮꾪듃 ?ㅻ줈, PageDown: ???ㅻ깄 鍮꾪듃 ?욎쑝濡?
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

			# D. ?ъ깮 諛곗냽 ?⑥텞??([ : 媛먯냽, ] : 媛??
			elif code_val == KEY_BRACKETLEFT:
				get_viewport().set_input_as_handled()
				var new_sel = max(0, speed_select.selected - 1)
				if new_sel != speed_select.selected:
					speed_select.selected = new_sel
					_on_speed_selected(new_sel)
					_show_toast("Speed: %s" % speed_select.get_item_text(new_sel))
				return

			# E. 利됱떆 ?뚯뒪???⑥텞??(F5)
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

	# Ctrl ?⑥텞??泥섎━ (Undo / Redo / Copy / Paste)
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
					new_note["time"] = _editor_time_to_note_time(str(new_note.get("type", "normal")), get_snapped_time(current_time))
					chart_data["notes"].append(new_note)
					_save_chart_file()
					selected_note_index = chart_data["notes"].find(new_note)
					_show_toast("Note Pasted")
					preview_canvas.queue_redraw()
					return

	# ?좏깮???명듃 誘몄꽭 ?대룞 (WASD / Shift+WASD)
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

	# 諛⑺뼢??醫뚯슦 ?대룞 (?쒓컙 ?먯깋)
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

	# Delete ???꾨Ⅴ硫??좏깮???명듃 ??젣
	if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		if selected_note_index != -1:
			get_viewport().set_input_as_handled()
			save_state_for_undo()
			_delete_note(selected_note_index)

	# ?쒕옒洹?以묒씤 ?숈븞?먮뒗 留덉슦?ㅼ쓽 ?꾩튂媛 ?대뵒??理쒖슦?좎쑝濡??쒕옒洹??대룞怨?由대━利덈? 泥섎━
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

	# 罹붾쾭??諛??곸뿭(?щ갚) 留덉슦???낅젰 泥섎━ (?붾㈃ 諛??앹꽦 諛???젣 吏??
	var canvas_container = get_node_or_null("Split/MainArea/CanvasContainer") as Control
	if canvas_container and (event is InputEventMouseButton or event is InputEventMouseMotion):
		var global_pos = event.global_position
		# 留덉슦?ㅺ? CanvasContainer ?대??대릺 PreviewCanvas ?몃???寃쎌슦
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
	current_time = _clamp_to_active_time_range(target)
	autoplay_hit_notes.clear()

	var expected_audio_pos = _chart_time_to_audio_pos(current_time)
	if expected_audio_pos >= 0.0 and expected_audio_pos < song_duration:
		if audio_player.playing:
			audio_player.seek(expected_audio_pos)
	else:
		audio_player.stop()

func _on_play_pressed() -> void:
	is_playing = not is_playing
	if is_playing:
		if is_view_region_only and _has_valid_region() and (current_time < region_start_time or current_time >= region_end_time):
			_seek_time(region_start_time)
		play_button.text = "Pause"
		audio_player.pitch_scale = playback_speed

		var expected_audio_pos = _chart_time_to_audio_pos(current_time)
		if expected_audio_pos >= 0.0 and expected_audio_pos < song_duration:
			audio_player.play(expected_audio_pos)
		else:
			audio_player.stop()
	else:
		play_button.text = "Play"
		audio_player.stop()
		is_playing_region = false # ?먮룞 ?뺤? ??援ш컙 ?ъ깮 ?ㅽ봽

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
# 罹붾쾭??2D 議곗옉
# ==========================================
func _on_canvas_gui_input(event: InputEvent) -> void:
	if not chart_data.has("notes"): return

	var canvas_w = preview_canvas.size.x
	var canvas_h = preview_canvas.size.y
	if canvas_w == 0 or canvas_h == 0: return

	var local_pos: Vector2 = event.position
	var logical_pos = Vector2(
		local_pos.x * (1920.0 / canvas_w),
		local_pos.y * (1080.0 / canvas_h)
	)

	if event is InputEventMouseMotion or event is InputEventMouseButton:
		mouse_logical_pos = logical_pos
		is_mouse_hovering_canvas = true
		preview_canvas.queue_redraw()

	if event is InputEventMouseMotion:
		# 怨≪꽑 ?쒕옒洹?紐⑤뱶: ?ㅼ떆媛??쒖뼱???낅뜲?댄듃
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

func _get_note_alpha(note: Dictionary, current_time: float) -> float:
	var note_time = _get_timeline_display_time(note)
	var note_type = str(note.get("type", "normal"))
	var dt = current_time - note_time

	var judgment_time = 0.7
	var perfect_margin = Global.judgment_perfect_margin
	var note_timeout = judgment_time + perfect_margin * 1.8
	var normal_fade_duration = 0.15
	var hold_fade_duration = 0.3

	if dt < 0.0:
		return _get_note_pre_appear_alpha(note_time)

	if note_type == "hold":
		var duration = float(note.get("duration", 3.0))
		if dt <= duration:
			return 1.0
		elif dt <= duration + hold_fade_duration:
			return 1.0 - ((dt - duration) / hold_fade_duration)
		else:
			return 0.0
	else:
		if dt <= note_timeout:
			return 1.0
		elif dt <= note_timeout + normal_fade_duration:
			return 1.0 - ((dt - note_timeout) / normal_fade_duration)
		else:
			return 0.0

func _update_hover_note(logical_pos: Vector2) -> void:
	hover_note_index = -1
	if not chart_data.has("notes"): return

	var threshold = 40.0
	var notes: Array = chart_data["notes"]

	for i in range(notes.size()):
		var note: Dictionary = notes[i]
		if not _is_note_in_view_region(note):
			continue
		var note_type = str(note.get("type", "normal"))

		if _get_note_alpha(note, current_time) <= 0.0:
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
	var note_time = _editor_time_to_note_time(selected_type, time_val)
	if is_view_region_only and not _time_span_in_any_region(time_val, time_val):
		_show_toast("Move inside the selected region first!")
		return

	if selected_type != "hold" and _is_inside_existing_note_block(logical_pos, note_time):
		_show_toast("Placement blocked: Inside note size!")
		return

	# Enforce note placement distance restriction
	if Global.limit_placement_distance and _uses_difficulty_filter():
		var prev_note = _get_previous_note_for_time(note_time)
		if prev_note != null:
			var prev_pos = Vector2(float(prev_note.get("x", 960.0)), float(prev_note.get("y", 540.0)))
			var allowed_radius = _get_allowed_placement_radius(prev_note, note_time)
			if logical_pos.distance_to(prev_pos) > allowed_radius:
				_show_toast("Placement blocked: Too far for this timing!")
				return

	save_state_for_undo()
	var note_node = {}
	note_node["time"] = note_time
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


func _is_point_note(note: Dictionary) -> bool:
	return str(note.get("type", "normal")) != "hold"


func _is_inside_existing_note_block(logical_pos: Vector2, time_val: float) -> bool:
	for note in chart_data.get("notes", []):
		if not note is Dictionary or not _is_point_note(note):
			continue
		if not _note_times_overlap(time_val, note):
			continue
		var note_pos = Vector2(float(note.get("x", 960.0)), float(note.get("y", 540.0)))
		if logical_pos.distance_to(note_pos) < Global.editor_note_block_radius:
			return true
	return false


func _note_times_overlap(time_val: float, other_note: Dictionary) -> bool:
	var judgment_time = 0.7
	var perfect_margin = Global.judgment_perfect_margin
	var note_timeout = judgment_time + perfect_margin * 1.8
	var other_start = float(other_note.get("time", 0.0))
	var other_end = other_start + note_timeout
	var new_start = time_val
	var new_end = new_start + note_timeout
	return new_start < other_end and other_start < new_end


func _get_previous_note_for_time(time_val: float) -> Variant:
	var prev_note = null
	var prev_time = -1.0
	for note in chart_data.get("notes", []):
		if not note is Dictionary:
			continue
		var nt = _get_note_end_time(note)
		if nt < time_val and nt > prev_time:
			prev_time = nt
			prev_note = note
	return prev_note


func _get_placement_guide_note_for_time(time_val: float) -> Variant:
	var guide_note = null
	var guide_time = -1.0
	for note in chart_data.get("notes", []):
		if not note is Dictionary:
			continue
		var nt = _get_note_end_time(note)
		if nt <= time_val and nt > guide_time:
			guide_time = nt
			guide_note = note
	return guide_note


func _get_next_note_after_time(time_val: float) -> Variant:
	var next_note = null
	var next_time = INF
	for note in chart_data.get("notes", []):
		if not note is Dictionary:
			continue
		var nt = _get_note_end_time(note)
		if nt > time_val and nt < next_time:
			next_time = nt
			next_note = note
	return next_note


func _get_note_end_time(note: Dictionary) -> float:
	var note_time = float(note.get("time", 0.0))
	if str(note.get("type", "normal")) == "hold":
		note_time += float(note.get("duration", 3.0))
	return note_time


func _get_allowed_placement_radius(prev_note: Dictionary, time_val: float) -> float:
	var dt = max(0.0, time_val - _get_note_end_time(prev_note))
	return clamp(Global.max_note_speed * dt, Global.editor_min_placement_radius, Global.max_note_distance)


func _get_visual_placement_radius(prev_note: Dictionary, time_val: float) -> float:
	var grow_delay = _get_timeline_step_duration() * Global.editor_placement_guide_grow_delay_steps
	var visual_time = max(_get_note_end_time(prev_note), time_val - grow_delay)
	return _get_allowed_placement_radius(prev_note, visual_time)


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
# ??꾨씪??議곗옉
# ==========================================
func _on_timeline_gui_input(event: InputEvent) -> void:
	var timeline_w = timeline.size.x
	if timeline_w == 0: return

	var pixels_per_second = 150.0 * timeline_zoom

	# Shift + ?쒕옒洹몃? ?댁슜??援ш컙 留덉슦??吏??泥섎━
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
				_add_current_region_to_list()
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
		if is_view_region_only and (_has_valid_region() or _has_enabled_regions()):
			current_time = clamp(current_time, region_start_time, region_end_time)
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
# ?묓겕 ?뚮쭏 ?뚮뜑留?(_draw)
# ==========================================
func _draw_preview_canvas() -> void:
	var canvas_w = preview_canvas.size.x
	var canvas_h = preview_canvas.size.y
	if canvas_w == 0 or canvas_h == 0: return

	var sx = canvas_w / 1920.0
	var sy = canvas_h / 1080.0

	# 罹붾쾭???묓겕 諛곌꼍 諛??묓겕 ?먯뒪?뚰떛 ?뚮몢由?
	preview_canvas.draw_rect(Rect2(Vector2.ZERO, preview_canvas.size), COLOR_BG_CANVAS, true)
	preview_canvas.draw_rect(Rect2(Vector2.ZERO, preview_canvas.size), COLOR_BORDER_CANVAS, false, 2.0 * sx)

	# ?묓겕 ??옄 媛??
	preview_canvas.draw_line(Vector2(canvas_w/2, 0), Vector2(canvas_w/2, canvas_h), COLOR_GRID_CANVAS, 1.0)
	preview_canvas.draw_line(Vector2(0, canvas_h/2), Vector2(canvas_w, canvas_h/2), COLOR_GRID_CANVAS, 1.0)

	if not chart_data.has("notes"): return

	var notes: Array = chart_data["notes"]

	# Draw placement boundary guides. The previous guide fades out after the next note appears.
	var active_guide_note = _get_placement_guide_note_for_time(current_time)
	for guide_note in notes:
		if not guide_note is Dictionary:
			continue
		if not _is_note_in_view_region(guide_note):
			continue
		var guide_start = _get_note_end_time(guide_note)
		if current_time < guide_start:
			continue
		var next_note = _get_next_note_after_time(guide_start)
		var next_start = _get_note_end_time(next_note) if next_note != null else INF
		var guide_alpha = 1.0
		if current_time >= next_start:
			guide_alpha = 1.0 - ((current_time - next_start) / Global.editor_placement_guide_fade_duration)
		if guide_alpha <= 0.0:
			continue
		guide_alpha = clamp(guide_alpha, 0.0, 1.0)

		var prev_pos = Vector2(float(guide_note.get("x", 960.0)), float(guide_note.get("y", 540.0)))
		var p_draw = prev_pos * Vector2(sx, sy)
		var allowed_radius = _get_visual_placement_radius(guide_note, min(current_time, next_start))

		preview_canvas.draw_circle(p_draw, allowed_radius * sx, Color(0.2, 0.8, 0.3, 0.06 * guide_alpha))
		preview_canvas.draw_arc(p_draw, allowed_radius * sx, 0.0, TAU, 64, Color(0.2, 0.8, 0.3, 0.3 * guide_alpha), 1.5 * sx)

		if guide_note == active_guide_note and is_mouse_hovering_canvas:
			var m_draw = mouse_logical_pos * Vector2(sx, sy)
			var distance_ratio = mouse_logical_pos.distance_to(prev_pos) / max(allowed_radius, 1.0)
			var line_color = Color(0.2, 0.8, 0.3, 0.5)
			if distance_ratio > 1.0:
				line_color = Color(0.9, 0.2, 0.2, 0.5)
			elif distance_ratio > 0.75:
				line_color = Color(0.9, 0.75, 0.15, 0.5)
			preview_canvas.draw_line(p_draw, m_draw, line_color, 1.5 * sx)

	for i in range(notes.size()):
		var note: Dictionary = notes[i]
		if not _is_note_in_view_region(note):
			continue
		var note_time = float(note.get("time", 0.0))
		var note_type = str(note.get("type", "normal"))
		var display_time: float = _get_timeline_display_time(note)

		var alpha = _get_note_alpha(note, current_time)
		if alpha <= 0.0:
			continue
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
				# ?묓겕 釉붾젋???ㅼ씪濡?留?
				preview_canvas.draw_circle(center, radius + 10.0*sx, Color(1.0, 0.301961, 0.427451, alpha * 0.25))

			preview_canvas.draw_arc(center, radius, 0.0, TAU, 64, color, 8.0 * sx, true)

			var hold_font = get_theme_font("font")
			var text_str = "HOLD (%.1fs)" % float(note.get("duration", 3.0))
			var hold_text_color = COLOR_TEXT_WINE
			hold_text_color.a = alpha * 0.85
			preview_canvas.draw_string(hold_font, center + Vector2(-60.0*sx, 10.0*sy), text_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, hold_text_color)

			# --- 濡??명듃 寃쎄퀬 ?쒖떆 ---
			var warning = _get_note_warnings(i) if current_time >= display_time else ""
			if warning != "":
				var w_font = get_theme_font("font")
				if warning == "LIMIT_EXCEEDED":
					# 怨?湲몄씠 湲곗? 珥덇낵 寃쎄퀬 (鍮④컯)
					preview_canvas.draw_circle(center, radius + 20.0 * sx, Color(1.0, 0.0, 0.0, alpha * 0.8), false, 2.5 * sx)
					preview_canvas.draw_string(w_font, center + Vector2(-60.0 * sx, - (radius + 25.0 * sy)), "?좑툘 Over Limit", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.3, 0.3, alpha * 0.9))
				elif warning == "SIMULTANEOUS":
					# ?숈떆移섍린 遺덇? 寃쎄퀬 (鍮④컯)
					preview_canvas.draw_circle(center, radius + 20.0 * sx, Color(1.0, 0.0, 0.0, alpha * 0.8), false, 2.5 * sx)
					preview_canvas.draw_string(w_font, center + Vector2(-60.0 * sx, - (radius + 25.0 * sy)), "?좑툘 Double Key", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.3, 0.3, alpha * 0.9))
		else:
			var nx = float(note.get("x", 960.0))
			var ny = float(note.get("y", 540.0))
			var is_offscreen = (nx < 0.0 or nx > 1920.0 or ny < 0.0 or ny > 1080.0)

			var rx = clamp(nx, 0.0, 1920.0) * sx
			var ry = clamp(ny, 0.0, 1080.0) * sy
			var pos = Vector2(rx, ry)
			var radius = 25.0 * sx
			var block_radius = Global.editor_note_block_radius * sx
			preview_canvas.draw_circle(pos, block_radius, Color(1.0, 0.0, 0.0, alpha * 0.035))
			preview_canvas.draw_arc(pos, block_radius, 0.0, TAU, 64, Color(1.0, 0.0, 0.0, alpha * 0.22), 1.5 * sx)

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

			# ?꾨꽋 ?뺥깭 ?대? (媛?μ옄由ъ? ?鍮꾨릺???대몢???묓겕 ????됱긽)
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

			# --- 遺덇??ν븳 ?⑦꽩 ?먮룞 寃異?諛??쒓컖 寃쎄퀬 ---
			var warning = _get_note_warnings(i) if current_time >= display_time else ""
			if warning != "":
				var w_font = get_theme_font("font")
				if warning == "LIMIT_EXCEEDED":
					# 怨?湲몄씠 湲곗? 珥덇낵 寃쎄퀬 (鍮④컯)
					preview_canvas.draw_circle(pos, 35.0 * sx, Color(1.0, 0.0, 0.0, alpha * 0.8), false, 2.5 * sx)
					preview_canvas.draw_string(w_font, pos + Vector2(-55.0 * sx, -40.0 * sy), "?좑툘 Over Limit", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.3, 0.3, alpha * 0.9))
				elif warning == "SIMULTANEOUS":
					# ?숈떆移섍린 遺덇? 寃쎄퀬 (鍮④컯)
					preview_canvas.draw_circle(pos, 35.0 * sx, Color(1.0, 0.0, 0.0, alpha * 0.8), false, 2.5 * sx)
					preview_canvas.draw_string(w_font, pos + Vector2(-45.0 * sx, -40.0 * sy), "?좑툘 Double Key", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.3, 0.3, alpha * 0.9))
				elif warning == "TOO_CLOSE":
					# 珥덇퀬???쇱?而?寃쎄퀬 (?ㅻ젋吏)
					preview_canvas.draw_circle(pos, 32.0 * sx, Color(1.0, 0.5, 0.0, alpha * 0.8), false, 2.0 * sx)
					preview_canvas.draw_string(w_font, pos + Vector2(-45.0 * sx, -40.0 * sy), "?좑툘 Extreme Speed", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.6, 0.2, alpha * 0.9))
				elif warning == "OVERLAP":
					# 寃뱀묠 諛곗튂 李⑦룓 寃쎄퀬 (?몃옉)
					preview_canvas.draw_circle(pos, 30.0 * sx, Color(1.0, 0.8, 0.0, alpha * 0.7), false, 1.5 * sx)
					preview_canvas.draw_string(w_font, pos + Vector2(-45.0 * sx, -40.0 * sy), "?좑툘 Hidden Note", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.85, 0.2, alpha * 0.9))
				elif warning == "NOTE_SIZE_BLOCKED":
					preview_canvas.draw_circle(pos, Global.editor_note_block_radius * sx, Color(1.0, 0.0, 0.0, alpha * 0.85), false, 2.5 * sx)
					preview_canvas.draw_string(w_font, pos + Vector2(-55.0 * sx, -40.0 * sy), "??Note Area", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.25, 0.25, alpha * 0.9))
				elif warning == "TOO_DISTANT":
					# ?덈? 嫄곕━ ?쒗븳 寃쎄퀬 (鍮④컙??
					preview_canvas.draw_circle(pos, 36.0 * sx, Color(0.9, 0.2, 0.2, alpha * 0.8), false, 2.5 * sx)
					preview_canvas.draw_string(w_font, pos + Vector2(-55.0 * sx, -40.0 * sy), "??Too Distant", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.9, 0.2, 0.2, alpha * 0.9))
				elif warning == "TOO_FAR":
					# 移????녿뒗 ?명듃 寃쎄퀬 (?먯＜??
					preview_canvas.draw_circle(pos, 38.0 * sx, Color(0.7, 0.0, 0.7, alpha * 0.9), false, 3.0 * sx)
					preview_canvas.draw_string(w_font, pos + Vector2(-55.0 * sx, -40.0 * sy), "??Too Far (Unhittable)", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.9, 0.2, 0.9, alpha * 0.9))

			# ?띿뒪???쇰꺼 (??????됱긽)
			var lbl_font = get_theme_font("font")
			var lbl_text_color = COLOR_TEXT_WINE
			lbl_text_color.a = alpha * 0.8
			preview_canvas.draw_string(lbl_font, pos + Vector2(15.0*sx, -15.0*sy), "%.2fs" % display_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, lbl_text_color)


	# --- ?ㅽ넗?뚮젅??由ы뵆 ?④낵 ?뚮뜑留?---
	for rip in autoplay_ripples:
		var r_pos = rip["pos"] * Vector2(sx, sy)
		var progress = 1.0 - (rip["life"] / 0.3)
		var radius = lerp(15.0, 65.0, progress) * sx
		var rip_color = Color(1.0, 0.0, 0.329412, lerp(0.8, 0.0, progress))
		preview_canvas.draw_circle(r_pos, radius, rip_color, false, 2.0 * sx)

	# --- ?ㅼ떆媛?怨≪꽑 ?쒕옒洹?誘몃━蹂닿린 ?뚮뜑留?---
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
	# --- 怨좏빐?곷룄 二쇳뙆?섎퀎 ?됱긽???ㅻ뵒???뚰삎 ?뚮뜑留?---
	if is_waveform_loaded and waveform_data.has("low"):
		var samples_per_second: float = float(waveform_data.get("samples_per_second", 60.0))
		var low_arr: Array = waveform_data["low"]
		var mid_arr: Array = waveform_data["mid"]
		var high_arr: Array = waveform_data["high"]
		var center_y: float = timeline_h / 2.0

		# 2?쎌? 媛꾧꺽?쇰줈 珥섏킌???뚮뜑留곹븯??怨좏빐?곷룄 ?띾룄 蹂댁옣
		var step: int = 2
		for x in range(0, int(timeline_w), step):
			var dx: float = x - center_x
			var t: float = current_time + (dx / pixels_per_second)

			# Draw waveform samples at the audio position that matches chart time.
			var t_audio = _chart_time_to_audio_pos(t)
			if t_audio < 0.0 or t_audio >= song_duration:
				continue

			var idx: int = int(t_audio * samples_per_second)
			if idx >= 0 and idx < low_arr.size():
				var low_val: float = float(low_arr[idx])
				var mid_val: float = float(mid_arr[idx])
				var high_val: float = float(high_arr[idx])

				# ??鍮④컯 - ???, ?ㅻ꽕???뚮옉 - 以묒뿭), 蹂댁뺄/硫쒕줈??珥덈줉 - 怨좎뿭) 二쇳뙆?????諛섑닾紐??移?삎 以묒꺽 洹몃━湲?
				if low_val > 0.01:
					var lh = low_val * (timeline_h * 0.45)
					timeline.draw_line(Vector2(x, center_y - lh), Vector2(x, center_y + lh), Color(0.9, 0.25, 0.25, 0.38), 2.0)
				if mid_val > 0.01:
					var mh = mid_val * (timeline_h * 0.38)
					timeline.draw_line(Vector2(x, center_y - mh), Vector2(x, center_y + mh), Color(0.25, 0.45, 0.9, 0.38), 2.0)
				if high_val > 0.01:
					var hh = high_val * (timeline_h * 0.28)
					timeline.draw_line(Vector2(x, center_y - hh), Vector2(x, center_y + hh), Color(0.25, 0.85, 0.35, 0.38), 2.0)

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

	# --- 援ш컙(Region) ?좏깮 ?곸뿭 諛?寃쎄퀎 ?뚮뜑留?---
	if region_start_time >= 0.0 and region_end_time >= 0.0 and region_end_time > region_start_time:
		var dx_start = (region_start_time - current_time) * pixels_per_second
		var dx_end = (region_end_time - current_time) * pixels_per_second
		var lx_start = center_x + dx_start
		var lx_end = center_x + dx_end

		var rx_start = clamp(lx_start, 0.0, timeline_w)
		var rx_end = clamp(lx_end, 0.0, timeline_w)

		if rx_end > rx_start:
			# 諛섑닾紐???????됱긽?쇰줈 ?곸뿭??洹몃┝
			var overlay_rect = Rect2(Vector2(rx_start, 0.0), Vector2(rx_end - rx_start, timeline_h))
			timeline.draw_rect(overlay_rect, Color(0.788235, 0.0941176, 0.290196, 0.22), true)

			# 寃쎄퀎???먯꽑/?ㅼ꽑 ?뚮뜑留?
			timeline.draw_line(Vector2(lx_start, 0.0), Vector2(lx_start, timeline_h), Color(0.788235, 0.0941176, 0.290196, 0.8), 2.0)
			timeline.draw_line(Vector2(lx_end, 0.0), Vector2(lx_end, timeline_h), Color(0.788235, 0.0941176, 0.290196, 0.8), 2.0)

			# ?쒖옉/醫낅즺 ?쒓컙 ?띿뒪???쒓린
			var r_font = get_theme_font("font")
			if lx_start >= 0.0 and lx_start <= timeline_w:
				timeline.draw_string(r_font, Vector2(lx_start + 4, timeline_h - 6), "[Start", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.788235, 0.0941176, 0.290196, 0.8))
			if lx_end >= 0.0 and lx_end <= timeline_w:
				timeline.draw_string(r_font, Vector2(lx_end - 45, timeline_h - 6), "End]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.788235, 0.0941176, 0.290196, 0.8))

	if regions.size() > 0:
		for region_idx in range(regions.size()):
			var draw_region = regions[region_idx]
			if not draw_region is Dictionary or not bool(draw_region.get("enabled", true)):
				continue
			var draw_start = float(draw_region.get("start", -1.0))
			var draw_end = float(draw_region.get("end", -1.0))
			if draw_start < 0.0 or draw_end <= draw_start:
				continue
			var draw_lx_start = center_x + ((draw_start - current_time) * pixels_per_second)
			var draw_lx_end = center_x + ((draw_end - current_time) * pixels_per_second)
			var draw_rx_start = clamp(draw_lx_start, 0.0, timeline_w)
			var draw_rx_end = clamp(draw_lx_end, 0.0, timeline_w)
			if draw_rx_end <= draw_rx_start:
				continue
			var multi_color = Color(1.0, 0.0, 0.329412, 0.28) if region_idx == selected_region_index else Color(0.788235, 0.0941176, 0.290196, 0.14)
			timeline.draw_rect(Rect2(Vector2(draw_rx_start, 0.0), Vector2(draw_rx_end - draw_rx_start, timeline_h)), multi_color, true)
			timeline.draw_line(Vector2(draw_lx_start, 0.0), Vector2(draw_lx_start, timeline_h), Color(0.788235, 0.0941176, 0.290196, 0.75), 1.5)
			timeline.draw_line(Vector2(draw_lx_end, 0.0), Vector2(draw_lx_end, timeline_h), Color(0.788235, 0.0941176, 0.290196, 0.75), 1.5)

	if not chart_data.has("notes"): return

	var notes: Array = chart_data["notes"]
	for i in range(notes.size()):
		var note: Dictionary = notes[i]
		if not _is_note_in_view_region(note):
			continue
		var note_time: float = float(note.get("time", 0.0))
		var note_type: String = str(note.get("type", "normal"))
		var display_time: float = _get_timeline_display_time(note)

		var dx: float = (display_time - current_time) * pixels_per_second
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

		# ??꾨씪?????ㅻ쪟 ?쒖떆 湲곕뒫 異붽?
		var warning = _get_note_warnings(i) if current_time >= display_time else ""
		if warning != "":
			var border_pts = PackedVector2Array([
				Vector2(lx, timeline_h / 2.0 - 10.0),
				Vector2(lx + 8.0, timeline_h / 2.0),
				Vector2(lx, timeline_h / 2.0 + 10.0),
				Vector2(lx - 8.0, timeline_h / 2.0),
				Vector2(lx, timeline_h / 2.0 - 10.0)
			])
			timeline.draw_polyline(border_pts, Color(0.85, 0.15, 0.15, 0.95), 2.0)

		if note_type == "hold":
			var duration: float = float(note.get("duration", 3.0))
			var end_dx: float = ((display_time + duration) - current_time) * pixels_per_second
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

	# 利됱떆 ?뚯뒪??(F5) 踰꾪듉 異붽?
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

	# 紐⑤뱺 梨꾨낫 吏?곌린 踰꾪듉 異붽?
	var clear_chart_btn = Button.new()
	clear_chart_btn.text = "Clear All Notes"
	clear_chart_btn.add_theme_color_override("font_color", Color.WHITE)
	clear_chart_btn.add_theme_font_size_override("font_size", 13)
	var clear_btn_style = StyleBoxFlat.new()
	clear_btn_style.bg_color = Color(0.65, 0.1, 0.1, 1.0)
	clear_btn_style.set_corner_radius_all(5)
	clear_btn_style.set_content_margin_all(8)
	clear_chart_btn.add_theme_stylebox_override("normal", clear_btn_style)
	clear_chart_btn.add_theme_stylebox_override("hover", btn_style_hover)
	clear_chart_btn.add_theme_stylebox_override("pressed", btn_style_pressed)
	clear_chart_btn.pressed.connect(_on_clear_all_notes_pressed)
	hbox.add_child(clear_chart_btn)

	# ?ㅽ넗 ?뚮젅??踰꾪듉 異붽?
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
	SceneTransition.transition_to_scene("res://scenes/menu/effect_editor.tscn")

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
# ?ㅽ뻾 痍⑥냼 / ?ㅼ떆 ?ㅽ뻾 諛?蹂듭궗 遺숈뿬?ｊ린 ?ы띁
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


# --- ?먮룞 ???諛깆뾽 湲곕뒫 ---
func _auto_save_backup() -> void:
	if selected_song == "" or not chart_data.has("notes") or chart_data["notes"].is_empty():
		return
	var song_path = MUSIC_BASE_PATH + selected_song + "/chart_backup.json"
	var file = FileAccess.open(song_path, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(chart_data, "\t")
		file.store_string(json_str)
		_show_toast("Auto-backup saved!")


# --- ?ㅽ넗?뚮젅??諛?遺덇??ν븳 ?⑦꽩 寃異??꾩슦誘??⑥닔 ---
func _on_autoplay_toggled(is_toggled: bool) -> void:
	is_autoplay = is_toggled
	autoplay_hit_notes.clear()
	var btn = get_viewport().gui_get_focus_owner() as Button
	# 踰꾪듉 ?띿뒪???숈쟻 ?낅뜲?댄듃
	for child in top_bar.get_child(0).get_child(0).get_children():
		if child is Button and "Auto-Play:" in child.text:
			child.text = "Auto-Play: ON" if is_toggled else "Auto-Play: OFF"
	if is_toggled:
		_show_toast("Auto-Play Enabled")
	else:
		_show_toast("Auto-Play Disabled")

func _on_clear_all_notes_pressed() -> void:
	var confirm = ConfirmationDialog.new()
	confirm.title = "Warning / 寃쎄퀬"
	confirm.dialog_text = "Are you sure you want to delete all notes in this chart?\n?꾩옱 ?대┛ 怨≪쓽 紐⑤뱺 梨꾨낫(?명듃)瑜???젣?섏떆寃좎뒿?덇퉴?"
	confirm.confirmed.connect(func():
		chart_data["notes"] = []
		selected_note_index = -1
		_save_chart_file()
		if preview_canvas:
			preview_canvas.queue_redraw()
		_show_toast("All notes deleted and saved!")
		confirm.queue_free()
	)
	confirm.canceled.connect(func():
		confirm.queue_free()
	)
	add_child(confirm)
	confirm.popup_centered()

func _on_instant_test_pressed() -> void:
	if is_playing:
		audio_player.stop()
	Global.is_editor_test_mode = true
	Global.editor_test_start_time = current_time
	_save_chart_file()
	_show_toast("Launching Instant Test...")
	# ???섏씠???몃옖吏?섏쓣 ?댁슜???먯뿰?ㅻ읇寃??꾪솚
	SceneTransition.transition_to_scene("res://scenes/game/game.tscn")

func _trigger_autoplay_hit_effect(note: Dictionary) -> void:
	var pos = Vector2(float(note.get("x", 960.0)), float(note.get("y", 540.0)))
	autoplay_ripples.append({"pos": pos, "life": 0.3})

func _get_note_warnings(idx: int) -> String:
	var notes = chart_data.get("notes", [])
	if idx >= notes.size(): return ""

	# ?쒓컙 ?쒖쑝濡??뺣젹??蹂듭궗蹂몄쓣 留뚮뱾???꾩옱 ?명듃???쒓컙???쒖꽌 ?뚯븙
	var indexed_notes = []
	for i in range(notes.size()):
		indexed_notes.append({"index": i, "note": notes[i]})
	indexed_notes.sort_custom(func(a, b): return float(a["note"].get("time", 0.0)) < float(b["note"].get("time", 0.0)))

	var sorted_idx = -1
	for i in range(indexed_notes.size()):
		if indexed_notes[i]["index"] == idx:
			sorted_idx = i
			break

	# 1. ?몃옒 湲몄씠 湲곗? 珥덇낵 寃쎄퀬 (????? ???쒓컙???꾩튂???명듃遺???곗꽑?곸쑝濡??ㅻ쪟 遺??
	var max_notes = int(song_duration / Global.note_limit_seconds_interval)
	if _uses_difficulty_filter() and sorted_idx >= max_notes:
		return "LIMIT_EXCEEDED"

	var note = notes[idx]
	var t = float(note.get("time", 0.0))
	var pos = Vector2(float(note.get("x", 960.0)), float(note.get("y", 540.0)))

	for i in range(notes.size()):
		if i == idx: continue
		var other = notes[i]
		var other_t = float(other.get("time", 0.0))
		var other_pos = Vector2(float(other.get("x", 960.0)), float(other.get("y", 540.0)))

		# 2. ?숈떆 移섍린 遺덇? 寃쎄퀬 (0.01珥??대궡 ?숈씪 ?쒓컙? ?寃??붽뎄)
		if abs(t - other_t) < 0.01:
			return "SIMULTANEOUS"
		# 3. 珥덇퀬???쇱?而?寃쎄퀬 (0.07珥??대궡 ?寃??붽뎄 - 80ms 誘몃쭔)
		elif _uses_difficulty_filter() and abs(t - other_t) < Global.min_note_interval:
			return "TOO_CLOSE"
		# 4. ?꾩튂 諛??쒓컙 寃뱀묠 李⑦룓 寃쎄퀬 (諛섍꼍 65px ?대궡 諛??쒓컙李?0.4珥??대궡)
		elif pos.distance_to(other_pos) < 65.0 and abs(t - other_t) < 0.4:
			return "OVERLAP"
		elif _is_point_note(note) and other is Dictionary and _is_point_note(other) and _note_times_overlap(t, other) and pos.distance_to(other_pos) < Global.editor_note_block_radius:
			return "NOTE_SIZE_BLOCKED"

	# 5. ?쒓컙 ?鍮?嫄곕━媛 ?덈Т 癒??명듃 (移????녿뒗 ?명듃 寃쎄퀬)
	var prev_note = null
	if sorted_idx > 0:
		prev_note = indexed_notes[sorted_idx - 1]["note"]

	if prev_note != null and _uses_difficulty_filter():
		var t1 = float(prev_note.get("time", 0.0))
		if str(prev_note.get("type", "normal")) == "hold":
			t1 += float(prev_note.get("duration", 3.0))
		var dt = t - t1
		var p1 = Vector2(float(prev_note.get("x", 960.0)), float(prev_note.get("y", 540.0)))
		var dist = pos.distance_to(p1)

		# ?몄젒 ?명듃 媛?嫄곕━媛 留ㅼ슦 媛源뚯슦硫??? 50px 誘몃쭔) 移????덈뒗 寃껋쑝濡?媛꾩＜?섏뿬 TOO_FAR ?먯젙 ?쒖쇅
		var speed = 0.0
		if dist >= 50.0:
			speed = dist / dt if dt > 0.001 else 999999.0
		else:
			speed = 0.0 if dt >= 0.0 else 999999.0

		# 6. ?덈? 臾쇰━??嫄곕━ ?쒗븳 珥덇낵 寃쎄퀬
		if dist > Global.max_note_distance:
			return "TOO_DISTANT"

		if speed > Global.max_note_speed:
			return "TOO_FAR"

	return ""


# --- 援ш컙 ?ъ깮 諛?諛섎났 ?ъ깮 UI 諛붿씤??諛??ы띁 ---
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

	region_list_label = Label.new()
	region_list_label.text = "Regions: --"
	region_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	region_list_label.add_theme_color_override("font_color", COLOR_TEXT_WINE_MUTED)
	region_list_label.add_theme_font_size_override("font_size", 11)
	region_settings_box.add_child(region_list_label)

	region_loop_check = CheckBox.new()
	region_loop_check.text = "Loop Region"
	region_loop_check.button_pressed = is_region_loop
	region_loop_check.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	region_loop_check.add_theme_font_size_override("font_size", 12)
	region_loop_check.toggled.connect(func(is_toggled):
		is_region_loop = is_toggled
		_save_editor_region_to_chart()
		_show_toast("Region Loop: ON" if is_toggled else "Region Loop: OFF")
	)
	region_settings_box.add_child(region_loop_check)

	region_view_check = CheckBox.new()
	region_view_check.text = "Show Region Only"
	region_view_check.button_pressed = is_view_region_only
	region_view_check.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	region_view_check.add_theme_font_size_override("font_size", 12)
	region_view_check.toggled.connect(func(is_toggled):
		if is_toggled and not _has_valid_region() and not _has_enabled_regions():
			is_view_region_only = false
			region_view_check.set_pressed_no_signal(false)
			_show_toast("Set Start & End first!")
			return
		is_view_region_only = is_toggled
		if is_view_region_only:
			_seek_time(current_time)
		_save_editor_region_to_chart()
		preview_canvas.queue_redraw()
		timeline.queue_redraw()
		_show_toast("Show Region Only: ON" if is_toggled else "Show Region Only: OFF")
	)
	region_settings_box.add_child(region_view_check)

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
		regions = []
		selected_region_index = -1
		is_playing_region = false
		is_view_region_only = false
		if region_view_check:
			region_view_check.set_pressed_no_signal(false)
		_save_editor_region_to_chart()
		_update_region_ui()
		timeline.queue_redraw()
		_show_toast("Region Cleared")
	)
	hbox_btns.add_child(clear_btn)

	region_settings_box.add_child(hbox_btns)

	var hbox_multi_1 = HBoxContainer.new()
	var add_region_btn = Button.new()
	add_region_btn.text = "Add Region"
	add_region_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_region_btn.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	add_region_btn.add_theme_font_size_override("font_size", 12)
	add_region_btn.pressed.connect(_add_current_region_to_list)
	hbox_multi_1.add_child(add_region_btn)

	var delete_region_btn = Button.new()
	delete_region_btn.text = "Delete"
	delete_region_btn.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	delete_region_btn.add_theme_font_size_override("font_size", 12)
	delete_region_btn.pressed.connect(_delete_selected_region)
	hbox_multi_1.add_child(delete_region_btn)
	region_settings_box.add_child(hbox_multi_1)

	var hbox_multi_2 = HBoxContainer.new()
	var prev_region_btn = Button.new()
	prev_region_btn.text = "< Prev"
	prev_region_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_region_btn.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	prev_region_btn.add_theme_font_size_override("font_size", 12)
	prev_region_btn.pressed.connect(_select_previous_region)
	hbox_multi_2.add_child(prev_region_btn)

	var next_region_btn = Button.new()
	next_region_btn.text = "Next >"
	next_region_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_region_btn.add_theme_color_override("font_color", COLOR_TEXT_WINE)
	next_region_btn.add_theme_font_size_override("font_size", 12)
	next_region_btn.pressed.connect(_select_next_region)
	hbox_multi_2.add_child(next_region_btn)
	region_settings_box.add_child(hbox_multi_2)

	var sep = HSeparator.new()
	region_settings_box.add_child(sep)

	# ?ъ씠?쒕컮 而⑦듃濡ㅼ쫰 ?먯떇 紐⑸줉??RegionSettings ?쎌엯 (MovingSettings ?꾨옒??諛곗튂)
	var controls_parent = hold_settings.get_parent()
	controls_parent.add_child(region_settings_box)
	var moving_idx = moving_settings.get_index() if moving_settings else hold_settings.get_index()
	controls_parent.move_child(region_settings_box, moving_idx + 1)

func _update_region_ui() -> void:
	if region_lbl_info == null:
		return
	if region_loop_check:
		region_loop_check.set_pressed_no_signal(is_region_loop)
	if region_view_check:
		region_view_check.set_pressed_no_signal(is_view_region_only)
	if region_list_label:
		if regions.is_empty():
			region_list_label.text = "Regions: --"
		else:
			var list_text = "Regions:"
			for i in range(regions.size()):
				var region = regions[i]
				var marker = "* " if i == selected_region_index else "  "
				list_text += "\n%s%d. %.2fs - %.2fs" % [marker, i + 1, float(region.get("start", -1.0)), float(region.get("end", -1.0))]
			region_list_label.text = list_text
	if region_start_time >= 0.0 and region_end_time >= 0.0:
		region_lbl_info.text = "Start: %.2fs / End: %.2fs" % [region_start_time, region_end_time]
	elif region_start_time >= 0.0:
		region_lbl_info.text = "Start: %.2fs / End: --" % region_start_time
	elif region_end_time >= 0.0:
		region_lbl_info.text = "Start: -- / End: %.2fs" % region_end_time
	else:
		region_lbl_info.text = "Start: -- / End: --"

func _on_play_region_pressed() -> void:
	if not _has_valid_region() and not _has_enabled_regions():
		_show_toast("Set Start & End first!")
		return
	is_playing_region = true
	if _has_valid_region():
		_seek_time(region_start_time)
	elif _has_enabled_regions():
		_seek_time(float(regions[0].get("start", 0.0)))
	if not is_playing:
		_on_play_pressed()
	_show_toast("Playing Region...")


# ==========================================
# 怨좏빐?곷룄 二쇳뙆??遺꾪븷 ?됱긽 ?ㅻ뵒???뚰삎 泥섎━ ?쒖뒪??
# ==========================================

func _load_waveform_data() -> void:
	is_waveform_loaded = false
	waveform_data = {}

	if selected_song == "":
		return

	var song_folder = MUSIC_BASE_PATH + selected_song + "/"
	var mp3_path = ProjectSettings.globalize_path(song_folder + selected_song + ".mp3")
	var json_path = ProjectSettings.globalize_path(song_folder + "waveform_data.json")

	# 1. ?대? ?뚰삎 JSON??議댁옱??寃쎌슦 ?뚯씪 Access濡?利됯컖 ?뚯떛
	if FileAccess.file_exists(song_folder + "waveform_data.json"):
		_parse_waveform_json(song_folder + "waveform_data.json")
		return

	# 2. 罹먯떆 ?곗씠?곌? ?놁쑝硫?諛깃렇?쇱슫?쒕줈 ?뚯씠???ㅽ럺?몃읆 異붿텧 ?ㅽ겕由쏀듃 ?ㅽ뻾
	var script_path = ProjectSettings.globalize_path("res://scripts/ui/extract_waveform.py")
	var ffmpeg_path = ProjectSettings.globalize_path("res://ffmpeg.exe")

	if not FileAccess.file_exists("res://scripts/ui/extract_waveform.py"):
		push_error("extract_waveform.py not found.")
		return

	# Git LFS pointer file check for ffmpeg.exe
	var ffmpeg_file = FileAccess.open("res://ffmpeg.exe", FileAccess.READ)
	if ffmpeg_file:
		var ffmpeg_size = ffmpeg_file.get_length()
		ffmpeg_file.close()
		if ffmpeg_size < 1024:
			push_error("FFmpeg executable is invalid (Git LFS pointer file detected!). Size: " + str(ffmpeg_size) + " bytes.")
			_show_toast("?ㅻ쪟: ffmpeg.exe媛 ?뺤긽?곸쑝濡??ㅼ슫濡쒕뱶?섏? ?딆븯?듬땲?? Git LFS瑜??ㅼ튂?섍퀬 'git lfs pull'???ㅽ뻾?섏꽭??")
			return
	else:
		push_error("ffmpeg.exe not found.")
		_show_toast("?ㅻ쪟: ffmpeg.exe ?뚯씪??李얠쓣 ???놁뒿?덈떎.")
		return

	print("Starting high-res colorful waveform generation process...")

	var args = [script_path, mp3_path, json_path, ffmpeg_path]
	var output = []

	# ?뚯씠???ㅽ뻾
	var exit_code = OS.execute("python", args, output, true, false)
	if exit_code != 0:
		exit_code = OS.execute("python3", args, output, true, false)

	if exit_code == 0:
		if FileAccess.file_exists(song_folder + "waveform_data.json"):
			_parse_waveform_json(song_folder + "waveform_data.json")
	else:
		push_error("Failed to generate waveform data: " + str(output))

func _parse_waveform_json(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary:
			waveform_data = parsed
			is_waveform_loaded = true
			print("Colorful dynamic waveform successfully loaded and cached!")
			if timeline:
				timeline.queue_redraw()


func _on_preview_canvas_mouse_exited() -> void:
	is_mouse_hovering_canvas = false
	preview_canvas.queue_redraw()
