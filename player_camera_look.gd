extends Node3D

## 鼠标移动灵敏度（弧度/像素）——桌面捕获模式
@export var mouse_look_sensitivity: float = 0.0022
## 触控/拖拽灵敏度（弧度/像素），通常略高于鼠标
@export var touch_look_sensitivity: float = 0.0040
## 相对进入场景时朝向：左右偏航最大偏转（弧度）
@export var yaw_limit_radians: float = deg_to_rad(20.0)
## 相对进入场景时朝向：上下俯仰最大偏转（弧度）
@export var pitch_limit_radians: float = deg_to_rad(20.0)
## 视角朝目标角度靠拢的速度（越大越跟手；帧率无关指数平滑）
@export var view_angle_smoothing: float = 5.0

var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _yaw_center: float = 0.0
var _pitch_center: float = 0.0

## 触控/Web：不捕获鼠标，用拖拽转视角
var _touch_look_mode: bool = false
## 正在用于转视角的触点 index；-1 表示无
var _look_touch_index: int = -1
## 点在投掷按钮上的触点：其拖拽绝不能转视角（多指时尤为关键）
var _ui_blocked_touch_indices: Dictionary = {}
## Web 桌面：按住左键拖拽转视角（不捕获指针）
var _mouse_drag_looking: bool = false

@onready var camera_3d: Camera3D = $Camera3D
@onready var _throw_button: Control = %ThrowButton


func _ready() -> void:
	_touch_look_mode = TouchControls.is_preferred()
	if _touch_look_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_yaw_center = rotation.y
	_pitch_center = camera_3d.rotation.x
	_look_yaw = _yaw_center
	_look_pitch = _pitch_center
	_target_yaw = _yaw_center
	_target_pitch = _pitch_center


func _process(delta: float) -> void:
	var smooth_weight: float = 1.0 - exp(-view_angle_smoothing * delta)
	_look_yaw = lerpf(_look_yaw, _target_yaw, smooth_weight)
	_look_pitch = lerpf(_look_pitch, _target_pitch, smooth_weight)
	rotation.y = _look_yaw
	camera_3d.rotation.x = _look_pitch


func _apply_look_delta(relative: Vector2, sensitivity: float) -> void:
	_target_yaw -= relative.x * sensitivity
	_target_pitch -= relative.y * sensitivity
	_target_yaw = clampf(
		_target_yaw,
		_yaw_center - yaw_limit_radians,
		_yaw_center + yaw_limit_radians
	)
	_target_pitch = clampf(
		_target_pitch,
		_pitch_center - pitch_limit_radians,
		_pitch_center + pitch_limit_radians
	)


func _is_position_on_throw_button(screen_position: Vector2) -> bool:
	if _throw_button == null or not _throw_button.visible:
		return false
	return _throw_button.get_global_rect().has_point(screen_position)


func _input(event: InputEvent) -> void:
	if not _touch_look_mode:
		return
	# GUI 之前标记投掷钮触点，防止其 ScreenDrag 漏到 unhandled 转视角
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _is_position_on_throw_button(touch.position):
				_ui_blocked_touch_indices[touch.index] = true
		else:
			_ui_blocked_touch_indices.erase(touch.index)


func _unhandled_input(event: InputEvent) -> void:
	if _touch_look_mode:
		_handle_touch_look_input(event)
	else:
		_handle_desktop_look_input(event)


func _handle_touch_look_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if _ui_blocked_touch_indices.has(touch.index):
			return
		if touch.pressed:
			# 多指：已有视角指时，不抢占第二指（留给别的用途 / 忽略）
			if _look_touch_index < 0:
				_look_touch_index = touch.index
				# 触屏手势进行中时，打断可能残留的鼠标拖拽态
				_mouse_drag_looking = false
				get_viewport().set_input_as_handled()
		elif touch.index == _look_touch_index:
			_look_touch_index = -1
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _ui_blocked_touch_indices.has(drag.index):
			return
		if _look_touch_index < 0:
			_look_touch_index = drag.index
			_mouse_drag_looking = false
		if drag.index != _look_touch_index:
			return
		_apply_look_delta(drag.relative, touch_look_sensitivity)
		get_viewport().set_input_as_handled()
		return

	# 仅当「本手势来自触屏」时忽略伴生鼠标，避免双倍转视角。
	# 不可用 is_touchscreen_available()：Web 桌面 Chrome 也常为 true，会掐死鼠标拖拽。
	if _look_touch_index >= 0:
		return

	# Web 桌面（及无活跃触屏手势时）：按住左键拖拽转视角
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		_mouse_drag_looking = mouse_event.pressed
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _mouse_drag_looking:
		var motion := event as InputEventMouseMotion
		_apply_look_delta(motion.relative, touch_look_sensitivity)
		get_viewport().set_input_as_handled()


func _handle_desktop_look_input(event: InputEvent) -> void:
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
		_apply_look_delta(motion.relative, mouse_look_sensitivity)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_viewport().set_input_as_handled()
