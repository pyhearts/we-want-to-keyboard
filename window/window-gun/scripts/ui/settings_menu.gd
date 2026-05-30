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


func _ready() -> void:
	# 전역 데이터 로드 및 UI 값 초기화
	_load_values_to_ui()
	
	# 시그널 연결
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
		lbl_speed.text = "Max Note Speed Limit"
		lbl_speed.add_theme_font_size_override("font_size", 14)
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
		lbl_speed_val.add_theme_font_size_override("font_size", 14)
		grid.add_child(lbl_speed_val)
		
		slider_speed.value_changed.connect(func(val):
			Global.max_note_speed = val
			lbl_speed_val.text = "%d px/s" % int(val)
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
	option_pos.add_item("Note Position (Spawn at note)", 0)
	option_pos.add_item("Screen Center (Fixed focus)", 1)
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
	
	Global.save_settings()
	_load_values_to_ui()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
