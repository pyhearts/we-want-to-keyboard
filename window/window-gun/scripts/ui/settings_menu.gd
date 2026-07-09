extends Control

const MAIN_MENU_SCENE = "res://scenes/menu/main_menu.tscn"
const SETTING_FONT_SIZE = 22
const SETTING_VALUE_FONT_SIZE = 22
const SECTION_BUTTON_FONT_SIZE = 22

@onready var btn_reset: Button = %BtnReset
@onready var btn_back: Button = %BtnBack

var section_buttons: Dictionary = {}
var section_content: VBoxContainer = null
var current_section: String = "gameplay"


func _ready() -> void:
	var title = get_node_or_null("Margin/VBox/Title") as Label
	if title:
		title.text = "게임 옵션"
	btn_reset.text = "기본값 초기화"
	btn_back.text = "저장 및 돌아가기"
	btn_reset.pressed.connect(_on_reset_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	_build_settings_layout()
	_show_section(current_section)


func _build_settings_layout() -> void:
	var old_grid = get_node_or_null("Margin/VBox/Grid")
	var vbox = get_node_or_null("Margin/VBox") as VBoxContainer
	if vbox == null:
		return
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	if old_grid:
		old_grid.visible = false
		old_grid.queue_free()

	var layout = HBoxContainer.new()
	layout.name = "SettingsLayout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 28)

	var nav = VBoxContainer.new()
	nav.name = "SectionNav"
	nav.custom_minimum_size = Vector2(190.0, 0.0)
	nav.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_theme_constant_override("separation", 10)
	layout.add_child(nav)

	_add_section_button(nav, "gameplay", "게임플레이")
	_add_section_button(nav, "visual", "화면/이펙트")
	_add_section_button(nav, "sound", "사운드")
	_add_section_button(nav, "editor", "에디터")

	var scroll = ScrollContainer.new()
	scroll.name = "SectionScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	section_content = VBoxContainer.new()
	section_content.name = "SectionContent"
	section_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_content.add_theme_constant_override("separation", 14)
	scroll.add_child(section_content)

	var buttons = get_node_or_null("Margin/VBox/HBoxButtons")
	var insert_index = buttons.get_index() if buttons else vbox.get_child_count()
	vbox.add_child(layout)
	vbox.move_child(layout, insert_index)


func _add_section_button(parent: VBoxContainer, section_id: String, title: String) -> void:
	var button = Button.new()
	button.text = title
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(170.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", SECTION_BUTTON_FONT_SIZE)
	button.pressed.connect(func(): _show_section(section_id))
	parent.add_child(button)
	section_buttons[section_id] = button


func _show_section(section_id: String) -> void:
	current_section = section_id
	for key in section_buttons.keys():
		var button = section_buttons[key] as Button
		if button:
			button.button_pressed = key == section_id

	if section_content == null:
		return
	for child in section_content.get_children():
		child.queue_free()

	match section_id:
		"gameplay":
			_build_gameplay_section()
		"visual":
			_build_visual_section()
		"sound":
			_build_sound_section()
		"editor":
			_build_editor_section()


func _build_gameplay_section() -> void:
	_add_section_title("게임플레이")
	_add_option_setting("곡 정렬 기준", ["제목", "영역 시간"], 1 if Global.music_sort_order == "duration" else 0, func(index):
		Global.music_sort_order = "duration" if index == 1 else "title"
		Global.music_titles = Global.get_folder_list(Global.MUSIC_BASE_PATH)
	)
	_add_slider_setting("최대 노트 속도", 1000.0, 10000.0, 100.0, Global.max_note_speed, "%d px/s", func(val): Global.max_note_speed = val)
	_add_slider_setting("최소 노트 간격", 0.01, 0.50, 0.01, Global.min_note_interval, "%d ms", func(val): Global.min_note_interval = val, func(val): return int(val * 1000.0))
	_add_toggle_setting("배치 영역 제한", Global.limit_placement_distance, func(pressed): Global.limit_placement_distance = pressed)
	_add_slider_setting("최대 노트 거리", 100.0, 2000.0, 50.0, Global.max_note_distance, "%d px", func(val): Global.max_note_distance = val)
	_add_slider_setting("판정 시간 폭", 0.10, 0.80, 0.01, Global.judgment_perfect_margin, "%.2f초", func(val): Global.judgment_perfect_margin = val)
	_add_slider_setting("주변 클릭 반경 배율", 0.0, 1.0, 0.05, Global.note_hit_radius, "%.2f배", func(val): Global.note_hit_radius = val)


func _build_visual_section() -> void:
	_add_section_title("화면/이펙트")
	_add_toggle_slider_setting("카메라 흔들림", Global.enable_camera_shake, Global.camera_shake_intensity, 0.0, 2.0, 0.1, "%d%%", func(pressed): Global.enable_camera_shake = pressed, func(val): Global.camera_shake_intensity = val, func(val): return int(val * 100.0))
	_add_slider_setting("파티클 밀도", 0.0, 2.0, 0.1, Global.particle_intensity, "%d%%", func(val): Global.particle_intensity = val, func(val): return int(val * 100.0))
	_add_slider_setting("노트 연결선 두께", 0.0, 12.0, 1.0, Global.judgment_line_width, "%d px", func(val): Global.judgment_line_width = val)
	_add_option_setting("판정 표시 위치", ["노트 위치", "화면 중앙"], 0 if Global.judgment_text_pos == "note" else 1, func(index): Global.judgment_text_pos = "note" if index == 0 else "center")
	_add_slider_setting("이펙트 오프셋 X", -500.0, 500.0, 1.0, Global.effect_offset.x, "%d", func(val): Global.effect_offset.x = val)
	_add_slider_setting("이펙트 오프셋 Y", -500.0, 500.0, 1.0, Global.effect_offset.y, "%d", func(val): Global.effect_offset.y = val)


func _build_sound_section() -> void:
	_add_section_title("사운드")
	_add_toggle_slider_setting("타격 효과음 (SFX)", Global.enable_sfx, Global.sfx_volume, 0.0, 1.0, 0.05, "%d%%", func(pressed): Global.enable_sfx = pressed, func(val): Global.sfx_volume = val, func(val): return int(val * 100.0))
	_add_toggle_setting("Scene transition SFX", Global.enable_scene_transition_sfx, func(pressed): Global.enable_scene_transition_sfx = pressed)


func _build_editor_section() -> void:
	_add_section_title("에디터")
	_add_slider_setting("최소 배치 원", 0.0, 400.0, 10.0, Global.editor_min_placement_radius, "%d px", func(val): Global.editor_min_placement_radius = val)
	_add_slider_setting("노트 금지 반경", 0.0, 240.0, 5.0, Global.editor_note_block_radius, "%d px", func(val): Global.editor_note_block_radius = val)
	_add_slider_setting("노트 미리보기", 0.0, 8.0, 0.5, Global.editor_timeline_note_preview_steps, "%.1f칸", func(val): Global.editor_timeline_note_preview_steps = val)
	_add_slider_setting("가이드 성장 지연", 0.0, 8.0, 0.5, Global.editor_placement_guide_grow_delay_steps, "%.1f칸", func(val): Global.editor_placement_guide_grow_delay_steps = val)
	_add_slider_setting("가이드 사라짐 시간", 0.0, 1.5, 0.05, Global.editor_placement_guide_fade_duration, "%.2f초", func(val): Global.editor_placement_guide_fade_duration = val)


func _add_section_title(title: String) -> void:
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 30)
	section_content.add_child(label)


func _add_slider_setting(title: String, min_value: float, max_value: float, step: float, value: float, format_text: String, apply_value: Callable, display_value: Callable = Callable()) -> void:
	var row = _create_setting_row(title)
	var slider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var value_label = _create_value_label(_format_setting_value(format_text, value, display_value))
	row.add_child(value_label)

	slider.value_changed.connect(func(val):
		apply_value.call(val)
		value_label.text = _format_setting_value(format_text, val, display_value)
		Global.save_settings()
	)


func _add_toggle_setting(title: String, value: bool, apply_value: Callable) -> void:
	var row = _create_setting_row(title)
	var check = CheckButton.new()
	check.button_pressed = value
	check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(check)
	row.add_child(Control.new())
	check.toggled.connect(func(pressed):
		apply_value.call(pressed)
		Global.save_settings()
	)


func _add_toggle_slider_setting(title: String, toggle_value: bool, slider_value: float, min_value: float, max_value: float, step: float, format_text: String, apply_toggle: Callable, apply_slider: Callable, display_value: Callable = Callable()) -> void:
	var row = _create_setting_row(title)
	var controls = HBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 14)
	row.add_child(controls)

	var check = CheckButton.new()
	check.button_pressed = toggle_value
	controls.add_child(check)

	var slider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = slider_value
	slider.editable = toggle_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(slider)

	var value_label = _create_value_label(_format_setting_value(format_text, slider_value, display_value))
	row.add_child(value_label)

	check.toggled.connect(func(pressed):
		apply_toggle.call(pressed)
		slider.editable = pressed
		Global.save_settings()
	)
	slider.value_changed.connect(func(val):
		apply_slider.call(val)
		value_label.text = _format_setting_value(format_text, val, display_value)
		Global.save_settings()
	)


func _add_option_setting(title: String, options: Array, selected: int, apply_value: Callable) -> void:
	var row = _create_setting_row(title)
	var option = OptionButton.new()
	option.custom_minimum_size = Vector2(300.0, 40.0)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_font_size_override("font_size", 20)
	for i in range(options.size()):
		option.add_item(str(options[i]), i)
	option.selected = selected
	row.add_child(option)
	row.add_child(Control.new())
	option.item_selected.connect(func(index):
		apply_value.call(index)
		Global.save_settings()
	)


func _create_setting_row(title: String) -> GridContainer:
	var row = GridContainer.new()
	row.columns = 3
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 24)
	row.add_theme_constant_override("v_separation", 8)
	section_content.add_child(row)

	var label = Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(220.0, 0.0)
	_style_setting_label(label)
	row.add_child(label)
	return row


func _create_value_label(text_value: String) -> Label:
	var value_label = Label.new()
	value_label.text = text_value
	_style_setting_value(value_label)
	return value_label


func _style_setting_label(label: Label) -> void:
	label.add_theme_font_size_override("font_size", SETTING_FONT_SIZE)


func _style_setting_value(label: Label) -> void:
	label.custom_minimum_size = Vector2(110.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", SETTING_VALUE_FONT_SIZE)


func _format_setting_value(format_text: String, value: float, display_value: Callable = Callable()) -> String:
	var shown_value = display_value.call(value) if display_value.is_valid() else value
	if format_text.find("%d") != -1:
		return format_text % int(shown_value)
	return format_text % shown_value


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_back_pressed()


func _on_reset_pressed() -> void:
	Global.enable_camera_shake = true
	Global.camera_shake_intensity = 1.0
	Global.enable_sfx = true
	Global.enable_scene_transition_sfx = true
	Global.sfx_volume = 0.5
	Global.particle_intensity = 1.0
	Global.judgment_line_width = 4.0
	Global.judgment_text_pos = "note"
	Global.effect_offset = Vector2(-220.0, -90.0)
	Global.music_sort_order = "title"
	Global.music_titles = Global.get_folder_list(Global.MUSIC_BASE_PATH)
	Global.max_note_speed = 4000.0
	Global.min_note_interval = 0.07
	Global.limit_placement_distance = false
	Global.max_note_distance = 800.0
	Global.judgment_perfect_margin = 0.45
	Global.note_hit_radius = 1.0
	Global.editor_min_placement_radius = 120.0
	Global.editor_note_block_radius = 108.0
	Global.editor_timeline_note_preview_steps = 3.0
	Global.editor_placement_guide_grow_delay_steps = 2.0
	Global.editor_placement_guide_fade_duration = 0.3

	Global.save_settings()
	_show_section(current_section)


func _on_back_pressed() -> void:
	SceneTransition.transition_to_scene(MAIN_MENU_SCENE)
