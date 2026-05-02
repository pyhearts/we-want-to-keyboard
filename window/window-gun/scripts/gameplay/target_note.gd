extends Control

const MODE_NORMAL := "normal"
const MODE_MOVING := "moving"

@export_group("Timing")
@export var judgment_time := 0.7
@export var perfect_margin := 0.3

@export_group("Score")
@export var penalty_score := -70

@export_group("Spawn Area")
@export var prevent_overlap_count := 3
@export var prevent_overlap_radius := 200.0
@export var min_x := 200.0
@export var max_x := 1400.0
@export var min_y := 200.0
@export var max_y := 700.0

@export_group("Particles")
@export var particle_min_amount := 15
@export var particle_max_amount := 40
@export var particle_lifetime := 0.6
@export var particle_offset := Vector2.ZERO
@export var color_miss := Color.GRAY
@export var color_low_score := Color(0.6, 0.8, 0.9)
@export var color_high_score := Color(0.0, 0.8, 1.0)

@export_group("Guide Line")
@export var center_offset := Vector2.ZERO
@export var connect_line_color := Color(1.0, 1.0, 1.0, 0.5)
@export var connect_line_width := 4.0

var is_moving := false
var velocity := Vector2.ZERO
var gravity := 0.0
var is_clone := false
var spawn_time_msec := 0

@onready var point: TextureButton = $Point
@onready var judgment_ring: TextureRect = $Point/CircleJudgment

static var recent_positions: Array[Vector2] = []
static var active_notes: Array[Control] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = false

	if is_clone:
		show()
	else:
		hide()
		recent_positions.clear()
		active_notes.clear()

	if point and not point.pressed.is_connected(_on_point_pressed):
		point.pressed.connect(_on_point_pressed)


func spawn_node(mode: String = MODE_NORMAL, target_pos: Variant = null) -> void:
	var final_pos := _get_spawn_position(target_pos)
	_remember_spawn_position(final_pos)

	var clone := duplicate() as Control
	clone.set("is_clone", true)
	get_parent().call_deferred("add_child", clone)

	if mode == MODE_MOVING:
		var start_pos := Vector2(final_pos.x + randf_range(-100.0, 100.0), max_y + 300.0)
		clone.call_deferred("activate_moving", final_pos, start_pos)
	else:
		clone.call_deferred("activate_stationary", final_pos)


func activate_stationary(new_pos: Vector2) -> void:
	is_moving = false
	# 노트의 중심을 목표 위치에 맞추기 위해 절반 크기만큼 왼쪽 위로 당겨줍니다.
	global_position = new_pos - (size / 2.0) * scale
	_setup_clone()

func activate_moving(target_pos: Vector2, start_pos: Vector2) -> void:
	is_moving = true
	# 시작 위치도 동일하게 중심을 맞춰줍니다.
	global_position = start_pos - (size / 2.0) * scale

	var travel_time := judgment_time
	gravity = (2.0 * (start_pos.y - target_pos.y)) / (travel_time * travel_time)
	velocity = Vector2(
		(target_pos.x - start_pos.x) / travel_time,
		-gravity * travel_time
	)

	_setup_clone()


func _process(delta: float) -> void:
	if not is_clone or not is_moving:
		return

	velocity.y += gravity * delta
	global_position += velocity * delta
	queue_redraw()
	_redraw_previous_note()


func _draw() -> void:
	if not is_clone:
		return

	var my_index := active_notes.find(self)
	if my_index == -1 or my_index >= active_notes.size() - 1:
		return

	var next_note = active_notes[my_index + 1]
	if not is_instance_valid(next_note):
		return

	var my_center_local := (size / 2.0) + center_offset
	var next_center_global: Vector2 = next_note.global_position + (((next_note.size / 2.0) + next_note.get("center_offset")) * next_note.scale)
	var next_center_local: Vector2 = get_global_transform().affine_inverse() * next_center_global
	draw_line(my_center_local, next_center_local, connect_line_color, connect_line_width, true)


func _get_spawn_position(target_pos: Variant) -> Vector2:
	if target_pos is Vector2:
		return target_pos

	var final_pos := Vector2.ZERO
	for _attempt in range(50):
		final_pos = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		if not _overlaps_recent_position(final_pos):
			break

	return final_pos


func _overlaps_recent_position(target_pos: Vector2) -> bool:
	for previous_pos in recent_positions:
		if target_pos.distance_to(previous_pos) < prevent_overlap_radius:
			return true
	return false


func _remember_spawn_position(spawn_pos: Vector2) -> void:
	recent_positions.append(spawn_pos)
	if recent_positions.size() > prevent_overlap_count:
		recent_positions.pop_front()


func _setup_clone() -> void:
	show()
	spawn_time_msec = Time.get_ticks_msec()
	active_notes.append(self)

	if judgment_ring and judgment_ring.has_method("start"):
		judgment_ring.start(judgment_time)

	update_target_visuals()
	get_tree().create_timer(judgment_time + perfect_margin).timeout.connect(_on_time_out)


func _on_time_out() -> void:
	if not is_clone or is_queued_for_deletion():
		return

	Global.add_score(penalty_score)
	Global.reset_combo()
	spawn_hit_particles("miss", 0)
	active_notes.erase(self)
	update_target_visuals()
	queue_free()


func _on_point_pressed() -> void:
	if not is_clone:
		return

	_prune_active_notes()

	var earned_score := 50
	if active_notes.size() > 0 and active_notes[0] == self:
		Global.add_combo()
		earned_score = _calculate_hit_score()
	else:
		Global.reset_combo()

	Global.add_score(earned_score)
	spawn_hit_particles("hit", earned_score)
	active_notes.erase(self)
	update_target_visuals()
	queue_free()


func _calculate_hit_score() -> int:
	var time_alive := (Time.get_ticks_msec() - spawn_time_msec) / 1000.0
	if time_alive >= judgment_time:
		return 100

	var score_step := int(time_alive / (judgment_time / 5.0)) * 10
	return 50 + score_step


func spawn_hit_particles(hit_type: String, score_value: int) -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = particle_lifetime
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 280.0

	var particle_color := color_miss
	var particle_amount := particle_min_amount
	if hit_type == "hit":
		var weight: float = clamp(float(score_value - 50) / 50.0, 0.0, 1.0)
		particle_color = color_low_score.lerp(color_high_score, weight)
		particle_amount = int(lerp(float(particle_min_amount), float(particle_max_amount), weight))

	particles.amount = particle_amount
	particles.color_ramp = _create_particle_gradient(particle_color)

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = scale_curve
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 10.0

	get_parent().add_child(particles)
	particles.global_position = global_position + ((size * scale) / 2.0) + particle_offset
	particles.emitting = true
	get_tree().create_timer(particles.lifetime).timeout.connect(particles.queue_free)


func update_target_visuals() -> void:
	_prune_active_notes()
	for i in range(active_notes.size()):
		var note := active_notes[i]
		note.modulate = Color.WHITE if i == 0 else Color(0.5, 0.5, 0.5, 0.7)
		note.queue_redraw()


func _redraw_previous_note() -> void:
	var my_index := active_notes.find(self)
	if my_index <= 0:
		return

	var previous_note := active_notes[my_index - 1]
	if is_instance_valid(previous_note):
		previous_note.queue_redraw()


func _create_particle_gradient(base_color: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, base_color)
	gradient.set_color(1, Color(base_color.r, base_color.g, base_color.b, 0.0))
	return gradient


func _prune_active_notes() -> void:
	var valid_notes: Array[Control] = []
	for note in active_notes:
		if is_instance_valid(note):
			valid_notes.append(note)
	active_notes = valid_notes
