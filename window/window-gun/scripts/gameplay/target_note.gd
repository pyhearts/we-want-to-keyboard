extends Control
class_name TargetNote

const MODE_NORMAL = "normal"
const MODE_MOVING = "moving"

@export_group("Timing")
@export var judgment_time = 0.7
@export var perfect_margin = 0.45

@export_group("Hit Area")
@export var hit_radius = 90.0

@export_group("Score")
@export var penalty_score = 0

@export_group("Spawn Area")
@export var prevent_overlap_count = 3
@export var prevent_overlap_radius = 200.0
@export var min_x = 200.0
@export var max_x = 1400.0
@export var min_y = 200.0
@export var max_y = 700.0

@export_group("Particles")
@export var particle_min_amount = 15
@export var particle_max_amount = 40
@export var particle_lifetime = 0.6
@export var particle_offset = Vector2.ZERO
@export var color_miss = Color.GRAY
@export var color_low_score = Color(0.6, 0.8, 0.9)
@export var color_high_score = Color(0.0, 0.8, 1.0)

@export_group("Guide Line")
@export var center_offset = Vector2(-220.0, -90.0)  # Adjusted effect offset
@export var connect_line_color = Color(1.0, 1.0, 1.0, 0.5)
@export var connect_line_width = 4.0

var is_moving = false
var velocity = Vector2.ZERO
var gravity = 0.0

# --- 베지에 커브 및 중력 확장 변수 ---
var curve_control_point: Variant = null  # Vector2 또는 null (직선이면 null)
var use_curve_gravity: bool = false      # 중력 이징 적용 여부
var move_target_pos: Vector2 = Vector2.ZERO
var move_start_pos: Vector2 = Vector2.ZERO
var move_elapsed: float = 0.0
var move_total_duration: float = 0.0
var use_bezier_mode: bool = false
var is_clone = false
var spawn_time_msec = 0
var is_hit = false  # 노트가 눌렸으면 true — 타임아웃 Miss 방지용

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


static func reset_state() -> void:
	active_notes.clear()
	recent_positions.clear()


func spawn_node(mode: String = MODE_NORMAL, target_pos: Variant = null, start_pos: Variant = null, curve_control: Variant = null, use_gravity: bool = false, move_duration: float = 0.0) -> void:
	var final_pos = _get_spawn_position(target_pos)
	_remember_spawn_position(final_pos)

	var clone = duplicate() as Control
	clone.set("is_clone", true)
	get_parent().call_deferred("add_child", clone)

	if mode == MODE_MOVING:
		var final_start_pos: Vector2
		if start_pos is Vector2:
			final_start_pos = start_pos
		else:
			final_start_pos = Vector2(final_pos.x + randf_range(-100.0, 100.0), max_y + 300.0)
		clone.call_deferred("activate_moving", final_pos, final_start_pos, curve_control, use_gravity, move_duration)
	else:
		clone.call_deferred("activate_stationary", final_pos)


func activate_stationary(new_pos: Vector2) -> void:
	is_moving = false
	# 노트의 중심을 목표 위치에 맞추기 위해 절반 크기만큼 왼쪽 위로 당겨줍니다.
	global_position = new_pos - ((size / 2.0) * scale + center_offset)
	_setup_clone()

func activate_moving(target_pos: Vector2, start_pos_arg: Vector2, p_curve_control: Variant = null, p_use_gravity: bool = false, p_move_duration: float = 0.0) -> void:
	is_moving = true
	move_target_pos = target_pos
	move_start_pos = start_pos_arg
	move_elapsed = 0.0
	
	# 시작 위치에 일치하게 중심을 맞춰줍니다.
	global_position = start_pos_arg - ((size / 2.0) * scale + center_offset)
	
	# 베지에 커브 모드 설정
	if p_curve_control is Vector2:
		curve_control_point = p_curve_control
		use_bezier_mode = true
	else:
		curve_control_point = null
		use_bezier_mode = false
	
	use_curve_gravity = p_use_gravity
	
	# 이동 총 시간 설정 (0이면 기존 judgment_time 사용)
	if p_move_duration > 0.01:
		move_total_duration = p_move_duration
	else:
		move_total_duration = judgment_time
	
	if use_bezier_mode:
		# 베지에 모드에서는 velocity/gravity를 사용하지 않음 (직접 보간)
		velocity = Vector2.ZERO
		gravity = 0.0
	else:
		# 기존 물리 기반 이동 (레거시 호환)
		var travel_time = judgment_time
		gravity = (2.0 * (start_pos_arg.y - target_pos.y)) / (travel_time * travel_time)
		velocity = Vector2(
			(target_pos.x - start_pos_arg.x) / travel_time,
			-gravity * travel_time
		)
	
	_setup_clone()


func _process(delta: float) -> void:
	if not is_clone or not is_moving:
		return

	if use_bezier_mode:
		# 베지에 커브 기반 이동
		move_elapsed += delta
		var t = clamp(move_elapsed / move_total_duration, 0.0, 1.0)
		
		# 중력 이징: t^2 가속 적용 (포물선 낙하 느낌)
		if use_curve_gravity:
			t = t * t
		
		var new_pos: Vector2
		if curve_control_point is Vector2:
			# 2차 베지에 보간
			var q0 = move_start_pos.lerp(curve_control_point, t)
			var q1 = curve_control_point.lerp(move_target_pos, t)
			new_pos = q0.lerp(q1, t)
		else:
			# 직선 보간
			new_pos = move_start_pos.lerp(move_target_pos, t)
		
		global_position = new_pos - ((size / 2.0) * scale + center_offset)
	else:
		# 기존 물리 기반 이동 (레거시 호환)
		velocity.y += gravity * delta
		global_position += velocity * delta
	
	if not _is_headless_run():
		queue_redraw()
		_redraw_previous_note()


func _draw() -> void:
	# 안전성 검사: 복제본이거나 씬 트리 밖에 있거나 헤드리스 환경인 경우 즉시 리턴
	if not is_clone or not is_inside_tree() or _is_headless_run():
		return

	var my_index = active_notes.find(self)
	if my_index == -1 or my_index >= active_notes.size() - 1:
		return

	var next_note = active_notes[my_index + 1]
	# 다음 노트의 인스턴스 유효성 및 씬 트리 소속 검증 (런타임 Parent node is not inside tree 버그 예방)
	if not is_instance_valid(next_note) or not next_note.is_inside_tree():
		return

	# 로컬 좌표계 시작 중심점
	var my_center_local = (size / 2.0) + center_offset
	
	# 다음 노트의 center_offset 안전 검사 (Invalid operands 'Vector2' and 'Nil' 버그 원천 예방)
	var next_offset = Vector2.ZERO
	if next_note.get("center_offset") is Vector2:
		next_offset = next_note.center_offset
	
	# 다음 노트의 글로벌 중심점 계산
	var next_center_global: Vector2 = next_note.global_position + (((next_note.size / 2.0) + next_offset) * next_note.scale)
	
	# 글로벌 중심점을 자신의 로컬 좌표계로 변환 (좌표계 버그 수정!)
	var next_center_local = get_global_transform().affine_inverse() * next_center_global
	
	# 가이드라인 연결선 그리기 복구 및 활성화
	draw_line(my_center_local, next_center_local, connect_line_color, Global.judgment_line_width, true)



func _get_spawn_position(target_pos: Variant) -> Vector2:
	if target_pos is Vector2:
		return target_pos

	var final_pos = Vector2.ZERO
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
	get_tree().create_timer(judgment_time + perfect_margin * 1.8).timeout.connect(_on_time_out)


func _on_time_out() -> void:
	# 이미 노트를 눌렀거나 삭제 중이면 Miss 처리하지 않음
	if not is_clone or is_queued_for_deletion() or is_hit:
		return

	Global.add_score(penalty_score)
	Global.reset_combo()
	Global.add_judgment("miss")
	
	# Miss 판정 및 이펙트 호출
	_spawn_judgment_effects("miss", 0)
	spawn_hit_particles("miss", 0)
	
	active_notes.erase(self)
	update_target_visuals()
	
	# 미스 시 서서히 페이드아웃되며 축소 소멸 리액션 (0.15초)
	if point:
		point.disabled = true
		var tween = create_tween().set_parallel(true)
		tween.tween_property(point, "scale", Vector2.ZERO, 0.15) \
			.set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)
		tween.tween_property(point, "modulate:a", 0.0, 0.15)
		
		if judgment_ring:
			var ring_tween = create_tween()
			ring_tween.tween_property(judgment_ring, "modulate:a", 0.0, 0.15)
			
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()


func _on_point_pressed() -> void:
	if not is_clone or is_hit or (point and point.disabled):
		return

	is_hit = true  # 타임아웃 Miss 방지 플래그 세팅
	_prune_active_notes()

	var is_first = active_notes.size() > 0 and active_notes[0] == self
	if is_first:
		Global.add_combo()
	else:
		Global.reset_combo()

	# 타이밍 오차 계산 및 판정 적용
	var time_alive = (Time.get_ticks_msec() - spawn_time_msec) / 1000.0
	var diff_time = time_alive - judgment_time

	var judgment_type = "miss"
	var earned_score = 0

	# 수학적 등비 분할 판정 범위 계산 (유효 범위 perfect_margin 기준)
	# - Perfect: 유효 범위의 50%
	# - Great: 이전 판정 제외 남은 범위의 50%
	# - Good: 마지막 잔여 범위 100% 전체 할당 (Miss 직전 단계)
	var max_window = perfect_margin
	var perfect_limit = max_window * 0.5
	var great_limit = perfect_limit + (max_window - perfect_limit) * 0.5
	var good_limit = max_window

	if diff_time < 0.0:
		# 일찍 누른 경우 (Early)
		var diff = abs(diff_time)
		if diff <= perfect_limit:
			judgment_type = "perfect"
			earned_score = 100
		elif diff <= great_limit:
			judgment_type = "great"
			earned_score = 80
		elif diff <= good_limit:
			judgment_type = "good"
			earned_score = 50
		else:
			judgment_type = "miss"
			earned_score = 0
	else:
		# 늦게 누른 경우 (Late) - 1.6배 더 너그러운 판정 적용
		var diff = diff_time
		if diff <= perfect_limit * 1.6:
			judgment_type = "perfect"
			earned_score = 100
		elif diff <= great_limit * 1.6:
			judgment_type = "great"
			earned_score = 80
		elif diff <= good_limit * 1.6:
			judgment_type = "good"
			earned_score = 50
		else:
			judgment_type = "miss"
			earned_score = 0

	if judgment_type == "miss":
		Global.reset_combo()

	# 점수 및 판정 반영
	Global.add_score(earned_score)
	Global.add_judgment(judgment_type)
	
	# 신규 프리미엄 타격감 연출(소리, 링, 판정 텍스트, 카메라 흔들림) 적용
	_spawn_judgment_effects(judgment_type, earned_score)
	spawn_hit_particles("hit", earned_score)
	
	active_notes.erase(self)
	update_target_visuals()
	
	# 타격 성공 시 순간 가로 찌그러짐 Squash & Stretch 소멸 리액션 (0.08초)
	if point:
		point.disabled = true; point.global_position += Vector2(-430, -370)  # Apply visual offset for shrinking effect
		point.pivot_offset = point.size / 2.0
		
		var final_duration = 0.08
		var tween = create_tween().set_parallel(true)
		
		# 가로 1.5배 늘리고 세로 0.4배 줄임 (순간 납작 타격 찌그러짐)
		var target_scale = Vector2(point.scale.x * 1.5, point.scale.y * 0.4)
		tween.tween_property(point, "scale", target_scale, final_duration) \
			.set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(point, "modulate:a", 0.0, final_duration) \
			.set_trans(Tween.TRANS_LINEAR)
			
		if judgment_ring:
			var ring_tween = create_tween()
			ring_tween.tween_property(judgment_ring, "modulate:a", 0.0, final_duration)
			
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()


func _calculate_hit_score() -> int:
	var time_alive = (Time.get_ticks_msec() - spawn_time_msec) / 1000.0
	if time_alive >= judgment_time:
		return 100

	var score_step = int(time_alive / (judgment_time / 5.0)) * 10
	return 50 + score_step


func _is_inside_hit_radius(global_pos: Vector2) -> bool:
	var note_center = global_position + ((size * scale) / 2.0) + center_offset
	return global_pos.distance_to(note_center) <= hit_radius


func _spawn_judgment_effects(judgment_type: String, score_value: int) -> void:
	if _is_headless_run():
		return

	# 1. 지연 없는 다중 채널 합성 효과음 재생
	if judgment_type != "miss":
		Global.play_hit_sound()

	# 2. 판정 텍스트 인스턴스 생성 및 연출 (설정된 위치 적용)
	var label_scene = load("res://scenes/effects/judgment_label.tscn")
	if label_scene:
		var label = label_scene.instantiate()
		get_parent().add_child(label)
		
		var center_pos = global_position + ((size * scale) / 2.0) + Global.effect_offset
		if Global.judgment_text_pos == "note":
			# 노트 머리보다 60픽셀 높여 시인성 보장
			label.global_position = center_pos + Vector2(0, -60.0)
		else:
			# 화면 중앙에 고정 팝업
			label.global_position = Vector2(960.0, 500.0)
			
		label.start(judgment_type)

	# 3. 절차적 네온 쇼크웨이브 링 & 센터 플래시 소환
	if judgment_type != "miss":
		var ripple_script = load("res://scripts/effects/hit_ripple.gd")
		if ripple_script:
			var ripple = Node2D.new()
			ripple.set_script(ripple_script)
			
			# 판정별 고유 네온 색상 연동
			if judgment_type == "perfect":
				ripple.color = Color(0.0, 1.0, 0.9, 1.0) # 네온 민트
			elif judgment_type == "great":
				ripple.color = Color(0.2, 1.0, 0.3, 1.0) # 네온 그린
			else:
				ripple.color = Color(0.8, 0.3, 1.0, 1.0) # 네온 퍼플
				
			get_parent().add_child(ripple)
			ripple.global_position = global_position + ((size * scale) / 2.0) + Global.effect_offset

	# 4. 카메라 흔들림(Camera Shake) 전역 송출 (Perfect, Great)
	if Global.enable_camera_shake and Global.camera_shake_intensity > 0.0:
		var base_shake = 0.0
		if judgment_type == "perfect":
			base_shake = 10.0
		elif judgment_type == "great":
			base_shake = 5.0
			
		if base_shake > 0.0:
			Global.camera_shake_requested.emit(base_shake * Global.camera_shake_intensity, 0.08)


func spawn_hit_particles(hit_type: String, score_value: int) -> void:
	if _is_headless_run():
		return

	# 전역 설정의 파티클 농도 가중치 반영
	var final_intensity = Global.particle_intensity
	if final_intensity <= 0.01:
		return

	var particles = CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = particle_lifetime
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 280.0

	var particle_color = color_miss
	var particle_amount = particle_min_amount
	if hit_type == "hit":
		var weight: float = clamp(float(score_value - 50) / 50.0, 0.0, 1.0)
		particle_color = color_low_score.lerp(color_high_score, weight)
		particle_amount = int(lerp(float(particle_min_amount), float(particle_max_amount), weight))

	# 파티클 밀도 설정 연동
	particles.amount = int(particle_amount * final_intensity)
	particles.color_ramp = _create_particle_gradient(particle_color)

	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = scale_curve
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 10.0

	get_parent().add_child(particles)
	particles.global_position = global_position + ((size * scale) / 2.0) + Global.effect_offset
	particles.emitting = true
	get_tree().create_timer(particles.lifetime).timeout.connect(particles.queue_free)



func update_target_visuals() -> void:
	_prune_active_notes()
	for i in range(active_notes.size()):
		var note = active_notes[i]
		note.modulate = Color.WHITE if i == 0 else Color(0.5, 0.5, 0.5, 0.7)
		if not _is_headless_run():
			note.queue_redraw()


func _redraw_previous_note() -> void:
	var my_index = active_notes.find(self)
	if my_index <= 0:
		return

	var previous_note = active_notes[my_index - 1]
	if is_instance_valid(previous_note):
		previous_note.queue_redraw()


func _create_particle_gradient(base_color: Color) -> Gradient:
	var gradient = Gradient.new()
	gradient.set_color(0, base_color)
	gradient.set_color(1, Color(base_color.r, base_color.g, base_color.b, 0.0))
	return gradient


func _prune_active_notes() -> void:
	var valid_notes: Array[Control] = []
	for note in active_notes:
		if is_instance_valid(note):
			valid_notes.append(note)
	active_notes = valid_notes


func _is_headless_run() -> bool:
	return OS.has_feature("headless") or "--headless" in OS.get_cmdline_args() or "--headless-test" in OS.get_cmdline_user_args() or OS.get_environment("GODOT_HEADLESS_TEST") == "1"

func _input(event: InputEvent) -> void:
	if not is_clone:
		return

	# 현재 입력해야 하는 첫 번째 노트만 입력 가능
	if active_notes.is_empty() or active_notes[0] != self:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_point_pressed()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_inside_hit_radius(get_global_mouse_position()):
			get_viewport().set_input_as_handled()
			_on_point_pressed()
