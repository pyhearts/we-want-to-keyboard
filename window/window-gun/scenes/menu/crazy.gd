extends TextureRect # 또는 Area2D, CharacterBody2D 등 상황에 맞게 사용하세요.

# 1. 기준이 되는 변수 (인스펙터 창에서 수정 가능하도록 @export 사용)
@export var base_speed: float = 300.0
@export var base_angle_deg: float = 45.0 # 기준 각도 (0도는 오른쪽, 90도는 아래쪽)

# 2. 랜덤성을 부여할 범위 (원하는 만큼 조절하세요)
@export var random_angle_range: float = 10.0 # 위아래로 10도씩 랜덤
@export var random_speed_range: float = 50.0 # 속도를 +- 50만큼 랜덤

# 최종 이동 방향과 속도를 담을 벡터
var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	# (선택) Godot 4에서는 보통 자동으로 시드가 섞이지만, 확실한 랜덤을 위해 호출
	randomize() 
	
	# --- [랜덤성 적용 및 계산] ---
	
	# 1. 기준 값에 랜덤 값을 더해 최종 속도와 각도를 정합니다.
	# randf_range(min, max)는 min과 max 사이의 무작위 실수를 뽑아냅니다.
	var final_speed = base_speed + randf_range(-random_speed_range, random_speed_range)
	var final_angle_deg = base_angle_deg + randf_range(-random_angle_range, random_angle_range)
	
	# 2. 각도(도, Degree)를 라디안(Radian)으로 변환합니다. (엔진 내부 수학은 라디안을 씁니다)
	var angle_rad = deg_to_rad(final_angle_deg)
	
	# 3. 라디안 각도를 이용해 실제 이동할 '속도 벡터(Velocity Vector)'를 만듭니다.
	# Vector2.from_angle()은 해당 각도를 바라보는 길이가 1인 벡터(방향)를 만들어줍니다.
	velocity = Vector2.from_angle(angle_rad) * final_speed


func _process(delta: float) -> void:
	# --- [실제 이동 처리] ---
	
	# 매 프레임마다 속도(velocity)에 델타 타임(delta)을 곱해서 부드럽게 이동시킵니다.
	position += velocity * delta
