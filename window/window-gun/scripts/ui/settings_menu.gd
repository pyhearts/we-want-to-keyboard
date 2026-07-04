extends Control

@onready var check_shake: CheckButton = %CheckShake
@onready var slider_shake: HSlider = %SliderShake
@onready var label_shake: Label = %LabelShakeValue

@onready var check_sfx: CheckButton = %CheckSFX
@onready var slider_sfx: HSlider = %SliderSFX
@onready var label_sfx: Label = %LabelSFXValue

@onready var slider_particles: HSlider = %SliderParticles
@onready var label_particles: Label = %LabelParticlesValue

@onready var slider_line: HSlider = %SliderLine
@onready var label_line: Label = %LabelLineValue

@onready var option_pos: OptionButton = %OptionPos

@onready var slider_offset_x: HSlider = %SliderOffsetX
@onready var label_offset_x: Label = %LabelOffsetXValue

@onready var slider_offset_y: HSlider = %SliderOffsetY
@onready var label_offset_y: Label = %LabelOffsetYValue

@onready var btn_reset: Button = %BtnReset
@onready var btn_back: Button = %BtnBack

const MAIN_MENU_SCENE = "res://scenes/menu/main_menu.tscn"
const SETTING_FONT_SIZE = 22
const SETTING_VALUE_FONT_SIZE = 22


func _ready() -> void:
	# Load global values and initialize UI.
	_load_values_to_ui()

	# Connect signals.
	check_shake.toggled.connect(_on_shake_toggled)
	slider_shake.value_changed.connect(_on_shake_val_changed)

	check_sfx.toggled.connect(_on_sfx_toggled)
	slider_sfx.value_changed.connect(_on_sfx_val_changed)

	slider_particles.value_changed.connect(_on_particles_val_changed)
	slider_line.value_changed.connect(_on_line_val_changed)
	option_pos.item_selected.connect(_on_pos_selected)

	slider_offset_x.value_changed.connect(_on_offset_x_val_changed)
	slider_offset_y.value_changed.connect(_on_offset_y_val_changed)

	btn_reset.pressed.connect(_on_reset_pressed)
	btn_back.pressed.connect(_on_back_pressed)

	# Programmatic Addition of Max Note Speed Slider to Grid
	var grid = check_shake.get_parent() as GridContainer
	if grid:
		var lbl_speed = Label.new()
		lbl_speed.text = "최대 노트 속도"
		_style_setting_label(lbl_speed)
		grid.add_child(lbl_speed)

		var spacer = Control.new()
		grid.add_child(spacer)

		var slider_speed = HSlider.new()
		slider_speed.name = "SliderSpeed"
		slider_speed.min_value = 1000.0
		slider_speed.max_value = 10000.0
		slider_speed.step = 100.0
		slider_speed.value = Global.max_note_speed
		slider_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(slider_speed)

		var lbl_speed_val = Label.new()
		lbl_speed_val.name = "LabelSpeedValue"
		lbl_speed_val.text = "%d px/s" % int(Global.max_note_speed)
		_style_setting_value(lbl_speed_val)
		grid.add_child(lbl_speed_val)

		slider_speed.value_changed.connect(func(val):
			Global.max_note_speed = val
			lbl_speed_val.text = "%d px/s" % int(val)
			Global.save_settings()
		)

		# Programmatic Addition of Min Note Interval Slider to Grid
		var lbl_interval = Label.new()
		lbl_interval.text = "최소 노트 간격"
		_style_setting_label(lbl_interval)
		grid.add_child(lbl_interval)

		var spacer_interval = Control.new()
		grid.add_child(spacer_interval)

		var slider_interval = HSlider.new()
		slider_interval.name = "SliderInterval"
		slider_interval.min_value = 0.01
		slider_interval.max_value = 0.50
		slider_interval.step = 0.01
		slider_interval.value = Global.min_note_interval
		slider_interval.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(slider_interval)

		var lbl_interval_val = Label.new()
		lbl_interval_val.name = "LabelIntervalValue"
		lbl_interval_val.text = "%d ms" % int(Global.min_note_interval * 1000.0)
		_style_setting_value(lbl_interval_val)
		grid.add_child(lbl_interval_val)

		slider_interval.value_changed.connect(func(val):
			Global.min_note_interval = val
			lbl_interval_val.text = "%d ms" % int(val * 1000.0)
			Global.save_settings()
		)

		# Programmatic Addition of Limit Placement Distance Toggle
		var lbl_limit = Label.new()
		lbl_limit.text = "배치 영역 제한"
		_style_setting_label(lbl_limit)
		grid.add_child(lbl_limit)

		var check_limit = CheckButton.new()
		check_limit.name = "CheckLimitPlacement"
		check_limit.button_pressed = Global.limit_placement_distance
		check_limit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		grid.add_child(check_limit)

		var spacer1 = Control.new()
		var spacer2 = Control.new()
		grid.add_child(spacer1)
		grid.add_child(spacer2)

		check_limit.toggled.connect(func(pressed):
			Global.limit_placement_distance = pressed
			Global.save_settings()
		)

		# Programmatic Addition of Max Note Distance Slider to Grid
		var lbl_dist = Label.new()
		lbl_dist.text = "최대 노트 거리"
		_style_setting_label(lbl_dist)
		grid.add_child(lbl_dist)

		var spacer_dist = Control.new()
		grid.add_child(spacer_dist)

		var slider_dist = HSlider.new()
		slider_dist.name = "SliderDistance"
		slider_dist.min_value = 100.0
		slider_dist.max_value = 2000.0
		slider_dist.step = 50.0
		slider_dist.value = Global.max_note_distance
		slider_dist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(slider_dist)

		var lbl_dist_val = Label.new()
		lbl_dist_val.name = "LabelDistanceValue"
		lbl_dist_val.text = "%d px" % int(Global.max_note_distance)
		_style_setting_value(lbl_dist_val)
		grid.add_child(lbl_dist_val)

		slider_dist.value_changed.connect(func(val):
			Global.max_note_distance = val
			lbl_dist_val.text = "%d px" % int(val)
			Global.save_settings()
		)

		_add_number_setting(grid, "판정 시간 폭", "SliderJudgmentMargin", "LabelJudgmentMarginValue", 0.10, 0.80, 0.01, Global.judgment_perfect_margin, "%.2f초", func(val): Global.judgment_perfect_margin = val)
		_add_number_setting(grid, "주변 클릭 반경 배율", "SliderHitRadius", "LabelHitRadiusValue", 0.0, 1.0, 0.05, Global.note_hit_radius, "%.2f배", func(val): Global.note_hit_radius = val)
		_add_number_setting(grid, "최소 배치 원", "SliderEditorMinRadius", "LabelEditorMinRadiusValue", 0.0, 400.0, 10.0, Global.editor_min_placement_radius, "%d px", func(val): Global.editor_min_placement_radius = val)
		_add_number_setting(grid, "노트 금지 반경", "SliderNoteBlockRadius", "LabelNoteBlockRadiusValue", 0.0, 240.0, 5.0, Global.editor_note_block_radius, "%d px", func(val): Global.editor_note_block_radius = val)
		_add_number_setting(grid, "노트 미리보기", "SliderPreviewSteps", "LabelPreviewStepsValue", 0.0, 8.0, 0.5, Global.editor_timeline_note_preview_steps, "%.1f칸", func(val): Global.editor_timeline_note_preview_steps = val)
		_add_number_setting(grid, "가이드 성장 지연", "SliderGuideGrowDelay", "LabelGuideGrowDelayValue", 0.0, 8.0, 0.5, Global.editor_placement_guide_grow_delay_steps, "%.1f칸", func(val): Global.editor_placement_guide_grow_delay_steps = val)
		_add_number_setting(grid, "가이드 사라짐 시간", "SliderGuideFade", "LabelGuideFadeValue", 0.0, 1.5, 0.05, Global.editor_placement_guide_fade_duration, "%.2f초", func(val): Global.editor_placement_guide_fade_duration = val)


func _style_setting_label(label: Label) -> void:
	label.add_theme_font_size_override("font_size", SETTING_FONT_SIZE)


func _style_setting_value(label: Label) -> void:
	label.custom_minimum_size = Vector2(96.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", SETTING_VALUE_FONT_SIZE)


func _format_setting_value(format_text: String, value: float) -> String:
	if format_text.find("%d") != -1:
		return format_text % int(value)
	return format_text % value


func _add_number_setting(grid: GridContainer, title: String, slider_name: String, label_name: String, min_value: float, max_value: float, step: float, value: float, format_text: String, apply_value: Callable) -> void:
	var label = Label.new()
	label.text = title
	_style_setting_label(label)
	grid.add_child(label)

	var spacer = Control.new()
	grid.add_child(spacer)

	var slider = HSlider.new()
	slider.name = slider_name
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(slider)

	var value_label = Label.new()
	value_label.name = label_name
	value_label.text = _format_setting_value(format_text, value)
	_style_setting_value(value_label)
	grid.add_child(value_label)

	slider.value_changed.connect(func(val):
		apply_value.call(val)
		value_label.text = _format_setting_value(format_text, val)
		Global.save_settings()
	)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_back_pressed()


func _load_values_to_ui() -> void:
	check_shake.button_pressed = Global.enable_camera_shake
	slider_shake.editable = Global.enable_camera_shake
	slider_shake.value = Global.camera_shake_intensity
	label_shake.text = "%d%%" % int(Global.camera_shake_intensity * 100)

	check_sfx.button_pressed = Global.enable_sfx
	slider_sfx.editable = Global.enable_sfx
	slider_sfx.value = Global.sfx_volume
	label_sfx.text = "%d%%" % int(Global.sfx_volume * 100)

	slider_particles.value = Global.particle_intensity
	label_particles.text = "%d%%" % int(Global.particle_intensity * 100)

	slider_line.value = Global.judgment_line_width
	label_line.text = "%d px" % int(Global.judgment_line_width)

	option_pos.clear()
	option_pos.add_item("노트 위치", 0)
	option_pos.add_item("화면 중앙", 1)
	option_pos.selected = 0 if Global.judgment_text_pos == "note" else 1

	slider_offset_x.value = Global.effect_offset.x
	label_offset_x.text = "%d" % int(Global.effect_offset.x)

	slider_offset_y.value = Global.effect_offset.y
	label_offset_y.text = "%d" % int(Global.effect_offset.y)

	var slider_speed = check_shake.get_parent().get_node_or_null("SliderSpeed") as HSlider
	var lbl_speed_val = check_shake.get_parent().get_node_or_null("LabelSpeedValue") as Label
	if slider_speed:
		slider_speed.value = Global.max_note_speed
	if lbl_speed_val:
		lbl_speed_val.text = "%d px/s" % int(Global.max_note_speed)

	var slider_interval = check_shake.get_parent().get_node_or_null("SliderInterval") as HSlider
	var lbl_interval_val = check_shake.get_parent().get_node_or_null("LabelIntervalValue") as Label
	if slider_interval:
		slider_interval.value = Global.min_note_interval
	if lbl_interval_val:
		lbl_interval_val.text = "%d ms" % int(Global.min_note_interval * 1000.0)

	var check_limit = check_shake.get_parent().get_node_or_null("CheckLimitPlacement") as CheckButton
	if check_limit:
		check_limit.button_pressed = Global.limit_placement_distance

	var slider_dist = check_shake.get_parent().get_node_or_null("SliderDistance") as HSlider
	var lbl_dist_val = check_shake.get_parent().get_node_or_null("LabelDistanceValue") as Label
	if slider_dist:
		slider_dist.value = Global.max_note_distance
	if lbl_dist_val:
		lbl_dist_val.text = "%d px" % int(Global.max_note_distance)

	_set_number_setting_ui("SliderJudgmentMargin", "LabelJudgmentMarginValue", Global.judgment_perfect_margin, "%.2f초")
	_set_number_setting_ui("SliderHitRadius", "LabelHitRadiusValue", Global.note_hit_radius, "%.2f배")
	_set_number_setting_ui("SliderEditorMinRadius", "LabelEditorMinRadiusValue", Global.editor_min_placement_radius, "%d px")
	_set_number_setting_ui("SliderNoteBlockRadius", "LabelNoteBlockRadiusValue", Global.editor_note_block_radius, "%d px")
	_set_number_setting_ui("SliderPreviewSteps", "LabelPreviewStepsValue", Global.editor_timeline_note_preview_steps, "%.1f칸")
	_set_number_setting_ui("SliderGuideGrowDelay", "LabelGuideGrowDelayValue", Global.editor_placement_guide_grow_delay_steps, "%.1f칸")
	_set_number_setting_ui("SliderGuideFade", "LabelGuideFadeValue", Global.editor_placement_guide_fade_duration, "%.2f초")


func _set_number_setting_ui(slider_name: String, label_name: String, value: float, format_text: String) -> void:
	var grid = check_shake.get_parent()
	var slider = grid.get_node_or_null(slider_name) as HSlider
	var value_label = grid.get_node_or_null(label_name) as Label
	if slider:
		slider.value = value
	if value_label:
		value_label.text = _format_setting_value(format_text, value)


func _on_shake_toggled(button_pressed: bool) -> void:
	Global.enable_camera_shake = button_pressed
	slider_shake.editable = button_pressed
	Global.save_settings()


func _on_shake_val_changed(value: float) -> void:
	Global.camera_shake_intensity = value
	label_shake.text = "%d%%" % int(value * 100)
	Global.save_settings()


func _on_sfx_toggled(button_pressed: bool) -> void:
	Global.enable_sfx = button_pressed
	slider_sfx.editable = button_pressed
	Global.save_settings()


func _on_sfx_val_changed(value: float) -> void:
	Global.sfx_volume = value
	label_sfx.text = "%d%%" % int(value * 100)
	Global.save_settings()


func _on_particles_val_changed(value: float) -> void:
	Global.particle_intensity = value
	label_particles.text = "%d%%" % int(value * 100)
	Global.save_settings()


func _on_line_val_changed(value: float) -> void:
	Global.judgment_line_width = value
	label_line.text = "%d px" % int(value)
	Global.save_settings()


func _on_pos_selected(index: int) -> void:
	Global.judgment_text_pos = "note" if index == 0 else "center"
	Global.save_settings()


func _on_offset_x_val_changed(value: float) -> void:
	Global.effect_offset.x = value
	label_offset_x.text = "%d" % int(value)
	Global.save_settings()


func _on_offset_y_val_changed(value: float) -> void:
	Global.effect_offset.y = value
	label_offset_y.text = "%d" % int(value)
	Global.save_settings()


func _on_reset_pressed() -> void:
	Global.enable_camera_shake = true
	Global.camera_shake_intensity = 1.0
	Global.enable_sfx = true
	Global.sfx_volume = 0.5
	Global.particle_intensity = 1.0
	Global.judgment_line_width = 4.0
	Global.judgment_text_pos = "note"
	Global.effect_offset = Vector2(-220.0, -90.0)
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
	_load_values_to_ui()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
