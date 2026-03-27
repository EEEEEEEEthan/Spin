extends Node3D

## 鼠标移动灵敏度（弧度/像素）
@export var mouse_look_sensitivity: float = 0.0022
## 俯仰角限制（弧度，略小于 ±90°）
@export var pitch_limit_radians: float = 1.553343
## 视角朝目标角度靠拢的速度（越大越跟手；帧率无关指数平滑）
@export var view_angle_smoothing: float = 5.0

var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0

@onready var camera_3d: Camera3D = $Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_look_yaw = rotation.y
	_look_pitch = camera_3d.rotation.x
	_target_yaw = _look_yaw
	_target_pitch = _look_pitch


func _process(delta: float) -> void:
	var smooth_weight: float = 1.0 - exp(-view_angle_smoothing * delta)
	_look_yaw = lerpf(_look_yaw, _target_yaw, smooth_weight)
	_look_pitch = lerpf(_look_pitch, _target_pitch, smooth_weight)
	rotation.y = _look_yaw
	camera_3d.rotation.x = _look_pitch


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
		_target_yaw -= motion.relative.x * mouse_look_sensitivity
		_target_pitch -= motion.relative.y * mouse_look_sensitivity
		_target_pitch = clampf(_target_pitch, -pitch_limit_radians, pitch_limit_radians)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_viewport().set_input_as_handled()
