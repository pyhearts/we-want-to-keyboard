extends Control

@export var judgment_time := 1.0
@export var perfect_margin := 0.3
@export var penalty_score := -70
@export var prevent_overlap_count := 3
@export var prevent_overlap_radius := 200.0
@export var min_x := 200.0; @export var max_x := 1400.0
@export var min_y := 200.0; @export var max_y := 700.0
@export var particle_min_amount := 15; @export var particle_max_amount := 40
@export var color_miss := Color.GRAY
@export var color_low_score := Color(0.6, 0.8, 0.9); @export var color_high_score := Color(0.0, 0.8, 1.0)
@export var particle_offset := Vector2.ZERO
@export var particle_lifetime := 0.6
@export var center_offset := Vector2.ZERO

# [추가됨] 선의 색상과 두께를 인스펙터에서 바꿀 수 있는 변수
@export var connect_line_color := Color(1.0, 1.0, 1.0, 0.5)
@export var connect_line_width := 4.0

var speed = 100; var is_clone := false; var spawn_time_msec := 0
@onready var point: TextureButton = $Point
static var recent_positions: Array[Vector2] = []
static var active_notes: Array[Control] = []

func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE
	if not is_clone: hide()
	if point and not point.pressed.is_connected(_on_point_pressed): 
		point.pressed.connect(_on_point_pressed)
	
	# [추가됨] 선이 Control 영역(Bounding Box) 밖으로 나가도 잘리지 않고 그려지도록 설정
	clip_contents = false

func rng_point():
	var clone = duplicate(); var new_pos = Vector2.ZERO
	for attempt in 50:
		new_pos = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		if not recent_positions.any(func(p): return new_pos.distance_to(p) < prevent_overlap_radius): break
	recent_positions.append(new_pos)
	if recent_positions.size() > prevent_overlap_count: recent_positions.pop_front()
	get_parent().call_deferred("add_child", clone)
	clone.call_deferred("activate_clone", new_pos)

func activate_clone(new_pos: Vector2):
	is_clone = true; global_position = new_pos; show()
	spawn_time_msec = Time.get_ticks_msec()
	active_notes.append(self); update_target_visuals()
	for c in get_children(): if c.has_method("start_shrinking"): c.start_shrinking()
	get_tree().create_timer(judgment_time + perfect_margin).timeout.connect(_on_time_out)

func _on_time_out():
	if not is_instance_valid(self): return
	Global.score += penalty_score; Global.combo = 0
	spawn_hit_particles("MISS", 0)
	active_notes.erase(self); update_target_visuals(); queue_free()

func _on_point_pressed():
	if not is_clone: return
	active_notes = active_notes.filter(func(n): return is_instance_valid(n))
	var earned_score := 50
	
	# [개선됨] 올바른 순서의 노트를 눌렀을 때만 콤보 증가, 틀린 순서면 콤보 초기화
	if active_notes.size() > 0 and active_notes[0] == self:
		Global.combo += 1
		var time_alive := (Time.get_ticks_msec() - spawn_time_msec) / 1000.0
		earned_score = 100 if time_alive >= judgment_time else 50 + (int(time_alive / (judgment_time / 5.0)) * 10)
	else:
		Global.combo = 0 # 순서가 틀린 노트를 눌렀을 때의 페널티 처리
		
	Global.score += earned_score
	spawn_hit_particles("HIT", earned_score)
	active_notes.erase(self); update_target_visuals(); queue_free()

# [추가됨] Godot의 기본 그리기 함수 오버라이드
func _draw():
	if not is_clone: return
	
	var my_index = active_notes.find(self)
	# 배열 내에 존재하고, 마지막 노트가 아니라면 다음 노트와 선을 연결
	if my_index != -1 and my_index < active_notes.size() - 1:
		var next_note = active_notes[my_index + 1]
		if is_instance_valid(next_note):
			# [수정됨] 내 노드의 기본 중심점에 오프셋 변수를 더하여 새로운 중심점을 계산합니다.
			var my_center_local = (size / 2.0) + center_offset
			
			# [수정됨] 다음 노트 역시 자신의 중심점에 오프셋을 더한 뒤, 스케일을 곱해 글로벌 좌표를 계산합니다.
			var next_offset_center = (next_note.size / 2.0) + next_note.center_offset
			var next_center_global = next_note.global_position + (next_offset_center * next_note.scale)
			
			# 글로벌 좌표를 내 로컬 좌표로 변환
			var next_center_local = get_global_transform().affine_inverse() * next_center_global
			
			# 계산된 새로운 중심점들을 사용하여 선 그리기
			draw_line(my_center_local, next_center_local, connect_line_color, connect_line_width, true)

func spawn_hit_particles(type: String, score_val: int):
	var p = CPUParticles2D.new()
	p.emitting = false; p.one_shot = true; p.explosiveness = 0.9; p.lifetime = particle_lifetime
	p.spread = 180.0; p.gravity = Vector2.ZERO; p.initial_velocity_min = 120.0; p.initial_velocity_max = 280.0
	
	var c: Color
	if type == "MISS":
		c = color_miss; p.amount = max(1, particle_min_amount / 2)
	else:
		var w = clamp((score_val - 50) / 50.0, 0.0, 1.0)
		c = color_low_score.lerp(color_high_score, w)
		p.amount = int(lerp(float(particle_min_amount), float(particle_max_amount), w))
	
	var g = Gradient.new()
	g.set_color(0, c); g.set_color(1, Color(c.r, c.g, c.b, 0.0)); p.color_ramp = g
	
	var cv = Curve.new(); cv.add_point(Vector2(0, 1.0)); cv.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = cv; p.scale_amount_min = 5.0; p.scale_amount_max = 10.0
	
	get_parent().add_child(p)
	p.global_position = global_position + ((size * scale) / 2.0) + particle_offset
	p.emitting = true
	get_tree().create_timer(p.lifetime).timeout.connect(p.queue_free)

func update_target_visuals():
	active_notes = active_notes.filter(func(n): return is_instance_valid(n))
	for i in active_notes.size(): 
		var note = active_notes[i]
		note.modulate = Color.WHITE if i == 0 else Color(0.5, 0.5, 0.5, 0.7)
		# [추가됨] 노트 상태가 변할 때마다 선을 다시 그리도록 요청
		note.queue_redraw()
