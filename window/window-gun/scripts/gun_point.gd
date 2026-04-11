extends Control

@export var judgment_time:=0.7 
@export var perfect_margin:=0.3 
@export var penalty_score:=-70
@export var prevent_overlap_count:=3; @export var prevent_overlap_radius:=200.0
@export var min_x:=200.0; @export var max_x:=1400.0; @export var min_y:=200.0; @export var max_y:=700.0
@export var particle_min_amount:=15; @export var particle_max_amount:=40
@export var color_miss:=Color.GRAY; @export var color_low_score:=Color(0.6,0.8,0.9); @export var color_high_score:=Color(0.0,0.8,1.0)
@export var particle_offset:=Vector2.ZERO; @export var particle_lifetime:=0.6; @export var center_offset:=Vector2.ZERO
@export var connect_line_color:=Color(1.0,1.0,1.0,0.5); @export var connect_line_width:=4.0

var is_moving := false
var velocity := Vector2.ZERO
var gravity := 0.0

var is_clone:=false; var spawn_time_msec:=0
@onready var point:TextureButton=$Point
static var recent_positions:Array[Vector2]=[]; static var active_notes:Array[Control]=[]

func _ready():
	mouse_filter=MOUSE_FILTER_IGNORE; clip_contents=false
	if not is_clone: hide()
	if point and not point.pressed.is_connected(_on_point_pressed): point.pressed.connect(_on_point_pressed)

# =========================================================
# 통합된 단일 스폰 함수
# 사용법: spawn_node("노트종류", Vector2(x, y)) <- 좌표 생략 가능
# =========================================================
func spawn_node(mode: String = "normal", target_pos = null):
	var final_pos = Vector2.ZERO
	
	# 좌표를 입력하지 않은 경우 (null) -> 랜덤 좌표 계산
	if target_pos == null:
		for attempt in 50:
			final_pos = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
			if not recent_positions.any(func(p): return final_pos.distance_to(p) < prevent_overlap_radius): break
	else:
		# 좌표를 입력한 경우
		final_pos = target_pos
		
	# 겹침 방지 배열 업데이트
	recent_positions.append(final_pos)
	if recent_positions.size() > prevent_overlap_count: recent_positions.pop_front()
	
	var clone = duplicate()
	get_parent().call_deferred("add_child", clone)
	
	if mode == "moving":
		var start_pos = Vector2(final_pos.x + randf_range(-100, 100), max_y + 300)
		clone.call_deferred("activate_moving", final_pos, start_pos)
	else:
		clone.call_deferred("activate_stationary", final_pos)

# ---------------------------------------------------------
# 내부 활성화 로직
# ---------------------------------------------------------
func activate_stationary(new_pos: Vector2):
	is_moving = false
	global_position = new_pos
	_setup_clone()

func activate_moving(target_pos: Vector2, start_pos: Vector2):
	is_moving = true
	global_position = start_pos
	
	var t = judgment_time
	gravity = (2.0 * (start_pos.y - target_pos.y)) / (t * t)
	var initial_vy = -gravity * t
	var initial_vx = (target_pos.x - start_pos.x) / t
	velocity = Vector2(initial_vx, initial_vy)
	
	_setup_clone()

func _setup_clone():
	is_clone = true
	show()
	spawn_time_msec = Time.get_ticks_msec()
	
	active_notes.append(self)
	update_target_visuals()
	
	for c in get_children(): 
		if c.has_method("start_shrinking"): c.start_shrinking()
		
	get_tree().create_timer(judgment_time + perfect_margin).timeout.connect(_on_time_out)

func _process(delta: float):
	if is_clone and is_moving:
		velocity.y += gravity * delta
		global_position += velocity * delta
		
		# 선 실시간 갱신
		queue_redraw() 
		
		var my_index = active_notes.find(self)
		if my_index > 0:
			var prev_note = active_notes[my_index - 1]
			if is_instance_valid(prev_note):
				prev_note.queue_redraw()

# ---------------------------------------------------------
# 판정 및 상호작용
# ---------------------------------------------------------
func _on_time_out():
	if not is_instance_valid(self): return
	
	Global.score += penalty_score; Global.combo = 0; spawn_hit_particles("MISS", 0)
	active_notes.erase(self)
		
	update_target_visuals(); queue_free()

func _on_point_pressed():
	if not is_clone: return
	active_notes=active_notes.filter(func(n): return is_instance_valid(n))
	
	var earned_score:=50
	if active_notes.size()>0 and active_notes[0]==self:
		Global.combo+=1; var time_alive:=(Time.get_ticks_msec()-spawn_time_msec)/1000.0
		earned_score=100 if time_alive>=judgment_time else 50+(int(time_alive/(judgment_time/5.0))*10)
	else: Global.combo=0
	Global.score+=earned_score; spawn_hit_particles("HIT",earned_score)
	active_notes.erase(self)
		
	update_target_visuals(); queue_free()

func _draw():
	if not is_clone: return 
	
	var my_index=active_notes.find(self)
	if my_index!=-1 and my_index<active_notes.size()-1:
		var next_note=active_notes[my_index+1]
		if is_instance_valid(next_note):
			var my_center_local=(size/2.0)+center_offset
			var next_center_global=next_note.global_position+(((next_note.size/2.0)+next_note.center_offset)*next_note.scale)
			draw_line(my_center_local,get_global_transform().affine_inverse()*next_center_global,connect_line_color,connect_line_width,true)

func spawn_hit_particles(type:String,score_val:int):
	var p=CPUParticles2D.new(); p.emitting=false; p.one_shot=true; p.explosiveness=0.9; p.lifetime=particle_lifetime
	p.spread=180.0; p.gravity=Vector2.ZERO; p.initial_velocity_min=120.0; p.initial_velocity_max=280.0; var c:Color
	if type=="MISS":  
		pass
	else:
		var w=clamp((score_val-50)/50.0,0.0,1.0); c=color_low_score.lerp(color_high_score,w)
		p.amount=int(lerp(float(particle_min_amount),float(particle_max_amount),w))
	var g=Gradient.new(); g.set_color(0,c); g.set_color(1,Color(c.r,c.g,c.b,0.0)); p.color_ramp=g
	var cv=Curve.new(); cv.add_point(Vector2(0,1.0)); cv.add_point(Vector2(1,0.0))
	p.scale_amount_curve=cv; p.scale_amount_min=5.0; p.scale_amount_max=10.0; get_parent().add_child(p)
	p.global_position=global_position+((size*scale)/2.0)+particle_offset; p.emitting=true
	get_tree().create_timer(p.lifetime).timeout.connect(p.queue_free)

func update_target_visuals():
	active_notes=active_notes.filter(func(n): return is_instance_valid(n))
	for i in active_notes.size():
		var note=active_notes[i]
		note.modulate = Color.WHITE if i==0 else Color(0.5, 0.5, 0.5, 0.7)
		note.queue_redraw()
