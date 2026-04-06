extends Control

@export_category("Timing & Score Settings")
@export var judgment_time: float = 1.0       # 기본 대기 시간
@export var perfect_margin: float = 0.3      # 원이 사라지기 전 100점을 받는 시간 (0.3초)
@export var penalty_score: int = -70         # 시간 초과 시 감점

@export_category("Spawn Settings")
@export var prevent_overlap_count: int = 3 
@export var prevent_overlap_radius: float = 200.0 
@export var min_x: float = 200.0 
@export var max_x: float = 1400.0
@export var min_y: float = 200.0
@export var max_y: float = 700.0

@export_category("Particle Settings")
@export var particle_min_amount: int = 15
@export var particle_max_amount: int = 40
@export var color_miss: Color = Color.GRAY
@export var color_low_score: Color = Color(0.6, 0.8, 0.9)
@export var color_high_score: Color = Color(0.0, 0.8, 1.0)
@export var particle_offset: Vector2 = Vector2.ZERO
@export var particle_lifetime: float = 0.6

var speed = 100
var is_clone: bool = false 
var spawn_time_msec: int = 0 

@onready var point: TextureButton = $Point

static var recent_positions: Array[Vector2] = []
static var active_notes: Array[Control] = [] 

func _ready():
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if not is_clone:
		self.hide() # 원본은 숨김 처리
	
	if point and not point.pressed.is_connected(_on_point_pressed):
		point.pressed.connect(_on_point_pressed)

func rng_point():
	var clone = self.duplicate()
	var new_pos = Vector2.ZERO
	var is_valid_pos = false
	var max_attempts = 50 
	
	for attempt in range(max_attempts):
		new_pos.x = randf_range(min_x, max_x)
		new_pos.y = randf_range(min_y, max_y)
		is_valid_pos = true
		for past_pos in recent_positions:
			if new_pos.distance_to(past_pos) < prevent_overlap_radius:
				is_valid_pos = false
				break 
		if is_valid_pos:
			break 
			
	recent_positions.append(new_pos)
	if recent_positions.size() > prevent_overlap_count:
		recent_positions.pop_front()
	
	get_parent().call_deferred("add_child", clone)
	clone.call_deferred("activate_clone", new_pos)

func activate_clone(new_pos: Vector2):
	is_clone = true
	global_position = new_pos
	self.show() 
	
	spawn_time_msec = Time.get_ticks_msec()
	
	active_notes.append(self)
	update_target_visuals()
	
	for child in get_children():
		if child.has_method("start_shrinking"):
			child.start_shrinking()
			
	var total_life_time = judgment_time + perfect_margin
	get_tree().create_timer(total_life_time).timeout.connect(_on_time_out)

func _on_time_out():
	if is_instance_valid(self):
		Global.score += penalty_score
		Global.combo = 0
		
		spawn_hit_particles("MISS", 0)
		
		active_notes.erase(self)
		update_target_visuals()
		queue_free()

func _on_point_pressed():
	if not is_clone: return 
	
	active_notes = active_notes.filter(func(note): return is_instance_valid(note))
	
	var earned_score: int = 0
	
	if active_notes.size() > 0 and active_notes[0] == self:
		Global.combo += 1
		var time_alive: float = (Time.get_ticks_msec() - spawn_time_msec) / 1000.0
		
		if time_alive >= judgment_time:
			earned_score = 100
		else:
			var step: int = int(time_alive / (judgment_time / 5.0))
			earned_score = 50 + (step * 10)
	else:
		earned_score = 50
	
	Global.score += earned_score
	
	spawn_hit_particles("HIT", earned_score)
	
	active_notes.erase(self)
	update_target_visuals()
	self.queue_free()

func spawn_hit_particles(type: String, score_val: int):
	var particles = CPUParticles2D.new()
	
	# 기본 물리 설정
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9      # 한 번에 팍 터지는 느낌 강화
	particles.lifetime = particle_lifetime
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 120.0 # 속도 소폭 상향
	particles.initial_velocity_max = 280.0
	
	# 🌟 [개선 1] 부드럽게 사라지는 투명도 설정 (ColorRamp)
	var gradient = Gradient.new()
	var base_color: Color
	
	if type == "MISS":
		base_color = color_miss
		particles.amount = max(1, particle_min_amount / 2)
	else:
		var weight: float = clamp(float(score_val - 50) / 50.0, 0.0, 1.0)
		base_color = color_low_score.lerp(color_high_score, weight)
		particles.amount = int(lerp(float(particle_min_amount), float(particle_max_amount), weight))
	
	# 그라데이션 설정: 시작(0.0)은 base_color, 끝(1.0)은 투명한 base_color
	gradient.set_color(0, base_color)
	gradient.set_color(1, Color(base_color.r, base_color.g, base_color.b, 0.0))
	particles.color_ramp = gradient

	# 🌟 [개선 2] 작아지면서 사라지는 크기 곡선 설정 (Scale Curve)
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.0))  # 시작 크기 100%
	curve.add_point(Vector2(1, 0.0))  # 끝 크기 0%
	particles.scale_amount_curve = curve
	
	# 기본 크기 값 (이 값에 곡선이 곱해짐)
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 10.0

	# 위치 설정
	get_parent().add_child(particles)
	var center_pos = self.global_position + ((self.size * self.scale) / 2.0) + particle_offset
	particles.global_position = center_pos
	
	particles.emitting = true
	
	# 파티클이 완전히 사라진 후 노드 삭제
	get_tree().create_timer(particles.lifetime).timeout.connect(particles.queue_free)

func update_target_visuals():
	active_notes = active_notes.filter(func(note): return is_instance_valid(note))
	
	for i in range(active_notes.size()):
		var note = active_notes[i]
		if i == 0:
			note.modulate = Color(1.0, 1.0, 1.0, 1.0) 
		else:
			note.modulate = Color(0.5, 0.5, 0.5, 0.7)
