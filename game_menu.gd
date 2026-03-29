extends Node

## 主菜单：按悬停项旋转 Axis，最短路径 + 过冲回弹

@onready var axis: Control = %Axis
@onready var button_new_game: TextureButton = %Button_NewGame
@onready var button_rank: TextureButton = %Button_Rank
@onready var button_quit: TextureButton = %Button_Quit

const ANGLE_IDLE := -PI * 0.5
const ANGLE_NEW := 0.0
const ANGLE_RANK := PI * 0.5
const ANGLE_QUIT := PI

const TWEEN_SEC := 0.52
const TWEEN_TRANS := Tween.TRANS_BACK
const TWEEN_EASE := Tween.EASE_OUT
const SCALE_PUNCH := 1.06

var _axis_tween: Tween


func _ready() -> void:
	axis.rotation = ANGLE_IDLE
	button_new_game.mouse_entered.connect(_on_new_entered)
	button_rank.mouse_entered.connect(_on_rank_entered)
	button_quit.mouse_entered.connect(_on_quit_entered)
	button_new_game.mouse_exited.connect(_on_any_exited)
	button_rank.mouse_exited.connect(_on_any_exited)
	button_quit.mouse_exited.connect(_on_any_exited)


func _on_new_entered() -> void:
	_tween_axis_to(ANGLE_NEW)


func _on_rank_entered() -> void:
	_tween_axis_to(ANGLE_RANK)


func _on_quit_entered() -> void:
	_tween_axis_to(ANGLE_QUIT)


func _on_any_exited() -> void:
	call_deferred("_resolve_hover_after_exit")


func _resolve_hover_after_exit() -> void:
	var mouse := get_viewport().get_mouse_position()
	if button_new_game.get_global_rect().has_point(mouse):
		_tween_axis_to(ANGLE_NEW)
	elif button_rank.get_global_rect().has_point(mouse):
		_tween_axis_to(ANGLE_RANK)
	elif button_quit.get_global_rect().has_point(mouse):
		_tween_axis_to(ANGLE_QUIT)
	else:
		_tween_axis_to(ANGLE_IDLE)


func _tween_axis_to(target_rad: float) -> void:
	if _axis_tween != null and _axis_tween.is_valid():
		_axis_tween.kill()
	axis.scale = Vector2.ONE
	var from := axis.rotation
	var delta := fposmod(target_rad - from + PI, TAU) - PI
	var end := from + delta
	_axis_tween = create_tween()
	_axis_tween.set_parallel(true)
	_axis_tween.tween_property(axis, "rotation", end, TWEEN_SEC).set_trans(TWEEN_TRANS).set_ease(TWEEN_EASE)
	var punch := Vector2(SCALE_PUNCH, SCALE_PUNCH)
	_axis_tween.tween_property(axis, "scale", punch, TWEEN_SEC * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_axis_tween.chain()
	_axis_tween.tween_property(axis, "scale", Vector2.ONE, TWEEN_SEC * 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
