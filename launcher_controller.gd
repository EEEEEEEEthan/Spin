extends Node3D

const PROJECTILE_SCENE := preload("res://knife_projectile.tscn")

@export var min_throw_speed: float = 10.0
@export var max_throw_speed: float = 32.0
@export var max_charge_seconds: float = 1.25
## 相对摄像机右侧偏移，避免从镜头中心穿出
@export var spawn_offset_right: float = 0.35
## 沿视线向前推出，避免生在相机体内
@export var spawn_offset_forward: float = 0.4
## 初速度向上分量 = throw_speed * 该系数，形成抛物线感
@export var arc_up_factor: float = 0.15
## 绕飞刀刚体局部 X 轴自旋角速度（弧度/秒，写入世界空间 angular_velocity）
@export var knife_spin_radians_per_second: float = 7.0
## 鼠标移动灵敏度（弧度/像素）
@export var mouse_look_sensitivity: float = 0.0022
## 俯仰角下限（弧度，略小于 ±90° 避免万向节死锁数值问题）
@export var pitch_limit_radians: float = 1.553343

var _charging: bool = false
var _charge_elapsed_seconds: float = 0.0
var _look_yaw: float = 0.0
var _look_pitch: float = 0.0

@onready var camera_yaw: Node3D = $CameraYaw
@onready var camera_3d: Camera3D = $CameraYaw/Camera3D
@onready var projectiles_root: Node3D = $Projectiles


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_look_yaw = camera_yaw.rotation.y
	_look_pitch = camera_3d.rotation.x


func _process(delta: float) -> void:
	if _charging:
		_charge_elapsed_seconds = minf(
			_charge_elapsed_seconds + delta,
			max_charge_seconds
		)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_look_yaw -= motion.relative.x * mouse_look_sensitivity
		_look_pitch -= motion.relative.y * mouse_look_sensitivity
		_look_pitch = clampf(_look_pitch, -pitch_limit_radians, pitch_limit_radians)
		camera_yaw.rotation.y = _look_yaw
		camera_3d.rotation.x = _look_pitch
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_viewport().set_input_as_handled()
				return
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		if mouse_event.pressed:
			_charging = true
			_charge_elapsed_seconds = 0.0
		else:
			if _charging:
				_throw_knife()
			_charging = false


func _throw_knife() -> void:
	var charge_ratio: float = 0.0
	if max_charge_seconds > 0.0:
		charge_ratio = clampf(_charge_elapsed_seconds / max_charge_seconds, 0.0, 1.0)
	var throw_speed: float = lerpf(min_throw_speed, max_throw_speed, charge_ratio)

	var camera_basis: Basis = camera_3d.global_transform.basis
	var spawn_origin: Vector3 = (
		camera_3d.global_position
		+ camera_basis.x * spawn_offset_right
		- camera_basis.z * spawn_offset_forward
	)

	var forward: Vector3 = -camera_basis.z.normalized()
	var initial_velocity: Vector3 = forward * throw_speed + Vector3.UP * (throw_speed * arc_up_factor)

	var knife: RigidBody3D = PROJECTILE_SCENE.instantiate() as RigidBody3D
	projectiles_root.add_child(knife)
	knife.global_position = spawn_origin
	knife.linear_velocity = initial_velocity
	var spin_axis_world: Vector3 = knife.global_transform.basis.x.normalized()
	knife.angular_velocity = spin_axis_world * knife_spin_radians_per_second
