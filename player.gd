extends Node

const PROJECTILE_SCENE := preload("res://knife_projectile.tscn")
const THROW_AUDIO_STREAMS: Array[AudioStream] = [
	preload("res://Audios/唰.wav"),
	preload("res://Audios/唰2.wav"),
	preload("res://Audios/唰3.wav"),
]

## 开始蓄力时发出（桌面左键 / 触控投掷钮共用），供关卡做表情等反馈
signal charge_started

@export var min_throw_speed: float = 5.0
@export var max_throw_speed: float = 32.0
@export var max_charge_seconds: float = 1.25
@export var ui_fade_seconds: float = 0.15
## 相对摄像机右侧偏移，避免从镜头中心穿出
@export var spawn_offset_right: float = 0.35
## 沿视线向前推出，避免生在相机体内
@export var spawn_offset_forward: float = 0.4
## 初速度向上分量 = throw_speed * 该系数，形成抛物线感
@export var arc_up_factor: float = 0.15
## 绕飞刀刚体局部 X 轴自旋角速度（弧度/秒，写入世界空间 angular_velocity）
@export var knife_spin_radians_per_second: float = 7.0

var _charging: bool = false
var _charge_elapsed_seconds: float = 0.0
var _ui_fade_tween: Tween
## 触控/Web：用投掷按钮蓄力；桌面原生：左键蓄力
var _use_throw_button: bool = false
## 当前按在投掷钮上的触点（用于松手在钮外仍能投出）
var _throw_touch_index: int = -1
var _throw_mouse_held: bool = false

@onready var camera_3d: Camera3D = $CameraYaw/Camera3D
@onready var progress_root: Control = %Progress
@onready var strength_bar: TextureRect = %Strength
@onready var throw_button: BaseButton = %ThrowButton
@onready var throw_audio_player: AudioStreamPlayer = %ThrowAudioPlayer


func _ready() -> void:
	strength_bar.progress = 1.0
	_use_throw_button = TouchControls.is_preferred()
	_setup_throw_button()


func _setup_throw_button() -> void:
	# 力度条不拦截触控/拖拽，避免挡住转视角
	progress_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strength_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _use_throw_button:
		throw_button.visible = true
		throw_button.mouse_filter = Control.MOUSE_FILTER_STOP
		# 手指移出按钮仍保持按下态（配合下方全局松手检测）
		throw_button.keep_pressed_outside = true
		throw_button.button_down.connect(_on_throw_button_down)
		throw_button.button_up.connect(_on_throw_button_up)
		throw_button.gui_input.connect(_on_throw_button_gui_input)
		# 布局：力度条让出右下角更大的拇指热区
		progress_root.offset_right = -212.0
		progress_root.offset_bottom = -28.0
	else:
		throw_button.visible = false
		throw_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _charging:
		_charge_elapsed_seconds = minf(
			_charge_elapsed_seconds + delta,
			max_charge_seconds
		)
		var charge_ratio := 0.0
		if max_charge_seconds > 0.0:
			charge_ratio = clampf(_charge_elapsed_seconds / max_charge_seconds, 0.0, 1.0)
		strength_bar.progress = charge_ratio


func _fade_progress_ui(target_alpha: float) -> void:
	if _ui_fade_tween != null:
		_ui_fade_tween.kill()
	_ui_fade_tween = create_tween()
	_ui_fade_tween.tween_property(
		progress_root,
		^"modulate",
		Color(1.0, 1.0, 1.0, target_alpha),
		ui_fade_seconds
	)


func _begin_charge() -> void:
	if _charging:
		return
	_charging = true
	_charge_elapsed_seconds = 0.0
	strength_bar.progress = 1.0
	_fade_progress_ui(1.0)
	charge_started.emit()


func _end_charge_and_throw() -> void:
	if not _charging:
		return
	_throw_knife()
	_charging = false
	_throw_touch_index = -1
	_throw_mouse_held = false
	# 兜底松手时强制复位按下外观，避免按钮卡在 pressed
	if _use_throw_button and throw_button != null:
		throw_button.set_pressed_no_signal(false)
	_fade_progress_ui(0.0)


func _on_throw_button_down() -> void:
	_begin_charge()


func _on_throw_button_up() -> void:
	# 移出按钮后松手仍应投出（keep_pressed_outside + button_up）
	_end_charge_and_throw()


func _on_throw_button_gui_input(event: InputEvent) -> void:
	# 记录触点 index，供松手落到按钮外时仍能结束蓄力
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_throw_touch_index = touch.index
			_begin_charge()
			throw_button.accept_event()
		elif touch.index == _throw_touch_index:
			_end_charge_and_throw()
			throw_button.accept_event()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_throw_mouse_held = true
			_begin_charge()
		else:
			_end_charge_and_throw()
		throw_button.accept_event()


func _input(event: InputEvent) -> void:
	if not _use_throw_button or not _charging:
		return
	# Web/触控：触点在按钮外松开时，gui 可能收不到 release，这里兜底投出。
	# 故意不 set_input_as_handled：CameraYaw._input 需收到同指 release 以清黑名单。
	if _throw_touch_index >= 0 and event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed and touch.index == _throw_touch_index:
			_end_charge_and_throw()
	elif _throw_mouse_held and event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_end_charge_and_throw()


func _unhandled_input(event: InputEvent) -> void:
	# 触控/Web 路径只认投掷按钮，避免拖拽/点击误触发投掷
	if _use_throw_button:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		if mouse_event.pressed:
			_begin_charge()
		else:
			_end_charge_and_throw()


func _throw_knife() -> void:
	var charge_ratio: float = 0.0
	if max_charge_seconds > 0.0:
		charge_ratio = clampf(_charge_elapsed_seconds / max_charge_seconds, 0.0, 1.0)
	var throw_speed: float = lerpf(min_throw_speed, max_throw_speed, charge_ratio)
	var throw_audio_stream: AudioStream = THROW_AUDIO_STREAMS.pick_random()
	throw_audio_player.stream = throw_audio_stream
	throw_audio_player.play()

	var camera_basis: Basis = camera_3d.global_transform.basis
	var spawn_origin: Vector3 = (
		camera_3d.global_position
		+ camera_basis.x * spawn_offset_right
		- camera_basis.z * spawn_offset_forward
	)

	var forward: Vector3 = -camera_basis.z.normalized()
	var initial_velocity: Vector3 = forward * throw_speed + Vector3.UP * (throw_speed * arc_up_factor)

	var knife: RigidBody3D = PROJECTILE_SCENE.instantiate() as RigidBody3D
	add_child(knife)
	knife.global_position = spawn_origin
	knife.linear_velocity = initial_velocity
	var spin_axis_world: Vector3 = knife.global_transform.basis.x.normalized()
	knife.angular_velocity = spin_axis_world * knife_spin_radians_per_second
