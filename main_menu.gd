extends Node

const ANGLE_IDLE := -PI * 0.5
const ANGLE_NEW := 0.0
const ANGLE_RANK := PI * 0.5
const ANGLE_QUIT := PI

const TWEEN_SEC := 0.52
const TWEEN_TRANS := Tween.TRANS_BACK
const TWEEN_EASE := Tween.EASE_OUT
const SCALE_PUNCH := 1.06

const BTN_SCALE_IDLE := 0.82
const BTN_SCALE_HOVER := 1.1
const BTN_SCALE_PRESS := 0.88
const BTN_HOVER_SEC := 0.24
const BTN_PRESS_SEC := 0.07

const _NEW_GAME_INTRO_TEXT := "消灭气球"
const _OVERLAY_SHOW_SEC := 0.35
const _DELAY_AFTER_NAME_BEFORE_TYPEWRITER_SEC := 2.0
const _INPUT_NAME_CANVAS_LAYER := 101
const _NAME_INPUT_SCENE := preload("res://InputName.tscn")
const _TYPEWRITER_CHAR_SEC := 0.1
const _HOLD_AFTER_INTRO_SEC := 3.0
const _TRANSITION_SHADER_INDEX := 1

const _PANEL_SLIDE_SEC := 0.62
const _PANEL_SLIDE_RATIO := 1.18
const _RANK_ENTRY_AUTO_OPEN_DELAY_SEC := 0.08

const _MENU_HOVER_SFX: Array[AudioStream] = [
	preload("res://Audios/唰.wav"),
	preload("res://Audios/唰2.wav"),
	preload("res://Audios/唰3.wav"),
]
const _MENU_CLICK_SFX: AudioStream = preload("res://Audios/咚.wav")
## 主菜单点击咚相对默认响度（约 8 倍）
const _MENU_CLICK_VOLUME_DB := 18.0

@onready var axis: Control = %Axis
@onready var button_new_game: BaseButton = %Button_NewGame
@onready var button_rank: BaseButton = %Button_Rank
@onready var button_quit: BaseButton = %Button_Quit
@onready var menu_root: Control = $Control
@onready var rank_panel = $Rank

var _axis_tween: Tween
var _menu_hover_angle: float = ANGLE_IDLE
var _buttons: Array[BaseButton] = []
var _button_tweens: Array[Tween] = []
var _pressed_index: int = -1
var _new_game_sequence_running: bool = false
var _panel_transition_running: bool = false
var _rank_open: bool = false
var _pending_rank_entry_id: int = -1

var _menu_panels: Array[Control] = []
var _menu_panel_base_positions: Array[Vector2] = []
var _menu_panel_tweens: Array[Tween] = []
var _rank_panel_base_position: Vector2 = Vector2.ZERO
var _menu_hover_audio: AudioStreamPlayer
var _menu_click_audio: AudioStreamPlayer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	axis.rotation = ANGLE_IDLE
	_menu_hover_angle = ANGLE_IDLE
	_buttons = [button_new_game, button_rank, button_quit]
	_button_tweens.resize(_buttons.size())
	_menu_panels = [menu_root, axis]
	_menu_panel_tweens.resize(_menu_panels.size())
	for menu_panel in _menu_panels:
		_menu_panel_base_positions.append(menu_panel.position)
	_rank_panel_base_position = rank_panel.position
	for index in range(_buttons.size()):
		var button: BaseButton = _buttons[index]
		var idle_scale := Vector2(BTN_SCALE_IDLE, BTN_SCALE_IDLE)
		button.scale = idle_scale
		button.button_down.connect(_on_button_down.bind(index))
		button.button_up.connect(_on_button_up.bind(index))
	button_new_game.pressed.connect(_on_new_game_pressed)
	button_rank.pressed.connect(_on_rank_pressed)
	button_quit.pressed.connect(_on_quit_pressed)
	rank_panel.close_requested.connect(_on_rank_close_requested)
	rank_panel.hide_instant()
	set_process(true)
	call_deferred(&"_sync_button_pivots")
	_pending_rank_entry_id = PlayerSession.consume_pending_rank_entry_id()
	if _pending_rank_entry_id >= 0:
		call_deferred(&"_auto_open_rank_after_game_end")
	_menu_hover_audio = AudioStreamPlayer.new()
	_menu_hover_audio.name = "MenuHoverSfx"
	add_child(_menu_hover_audio)
	_menu_click_audio = AudioStreamPlayer.new()
	_menu_click_audio.name = "MenuClickSfx"
	_menu_click_audio.volume_db = _MENU_CLICK_VOLUME_DB
	add_child(_menu_click_audio)


func _sync_button_pivots() -> void:
	for button in _buttons:
		button.pivot_offset = button.size * 0.5


func _process(_delta: float) -> void:
	if _rank_open or _panel_transition_running:
		return
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var target_angle: float = _hover_angle_for_mouse(mouse_position)
	if not is_equal_approx(target_angle, _menu_hover_angle):
		if _hover_index(target_angle) >= 0:
			_play_menu_hover_sfx()
		_menu_hover_angle = target_angle
		_tween_axis_to(target_angle)
		if _pressed_index < 0:
			_tween_buttons_for_hover(target_angle)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		if not is_equal_approx(_menu_hover_angle, ANGLE_IDLE):
			_menu_hover_angle = ANGLE_IDLE
			_tween_axis_to(ANGLE_IDLE)
		if _pressed_index < 0 and not _rank_open and not _panel_transition_running:
			_tween_buttons_for_hover(ANGLE_IDLE)


func _hover_angle_for_mouse(mouse_position: Vector2) -> float:
	if button_new_game.get_global_rect().has_point(mouse_position):
		return ANGLE_NEW
	if button_rank.get_global_rect().has_point(mouse_position):
		return ANGLE_RANK
	if button_quit.get_global_rect().has_point(mouse_position):
		return ANGLE_QUIT
	return ANGLE_IDLE


func _hover_index(angle: float) -> int:
	if is_equal_approx(angle, ANGLE_NEW):
		return 0
	if is_equal_approx(angle, ANGLE_RANK):
		return 1
	if is_equal_approx(angle, ANGLE_QUIT):
		return 2
	return -1


func _kill_button_tween(index: int) -> void:
	var tween: Tween = _button_tweens[index]
	if tween != null and tween.is_valid():
		tween.kill()
	_button_tweens[index] = null


func _tween_button_scale(index: int, scale_value: float, duration: float, trans: int, ease_type: int) -> void:
	_kill_button_tween(index)
	var button: BaseButton = _buttons[index]
	var tween := create_tween()
	_button_tweens[index] = tween
	var target_scale := Vector2(scale_value, scale_value)
	tween.tween_property(button, ^"scale", target_scale, duration).set_trans(trans).set_ease(ease_type)


func _tween_buttons_for_hover(angle: float) -> void:
	var hover_index: int = _hover_index(angle)
	for index in range(_buttons.size()):
		var target_scale_value := BTN_SCALE_HOVER if index == hover_index else BTN_SCALE_IDLE
		_tween_button_scale(index, target_scale_value, BTN_HOVER_SEC, Tween.TRANS_BACK, Tween.EASE_OUT)


func _on_button_down(index: int) -> void:
	if _rank_open or _panel_transition_running:
		return
	_play_menu_click_sfx()
	_pressed_index = index
	_kill_button_tween(index)
	var button: BaseButton = _buttons[index]
	var tween := create_tween()
	_button_tweens[index] = tween
	tween.tween_property(button, ^"scale", Vector2(BTN_SCALE_PRESS, BTN_SCALE_PRESS), BTN_PRESS_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _on_button_up(index: int) -> void:
	if _rank_open or _panel_transition_running:
		return
	if _pressed_index != index:
		return
	_pressed_index = -1
	var hover_index: int = _hover_index(_menu_hover_angle)
	var target_scale_value := BTN_SCALE_HOVER if index == hover_index else BTN_SCALE_IDLE
	_tween_button_scale(index, target_scale_value, BTN_HOVER_SEC * 0.85, Tween.TRANS_BACK, Tween.EASE_OUT)


func _tween_axis_to(target_rad: float) -> void:
	if _axis_tween != null and _axis_tween.is_valid():
		_axis_tween.kill()
	axis.scale = Vector2.ONE
	var from_rotation := axis.rotation
	var rotation_delta := fposmod(target_rad - from_rotation + PI, TAU) - PI
	var end_rotation := from_rotation + rotation_delta
	_axis_tween = create_tween()
	_axis_tween.set_parallel(true)
	_axis_tween.tween_property(axis, ^"rotation", end_rotation, TWEEN_SEC).set_trans(TWEEN_TRANS).set_ease(TWEEN_EASE)
	var punch_scale := Vector2(SCALE_PUNCH, SCALE_PUNCH)
	_axis_tween.tween_property(axis, ^"scale", punch_scale, TWEEN_SEC * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_axis_tween.chain()
	_axis_tween.tween_property(axis, ^"scale", Vector2.ONE, TWEEN_SEC * 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_new_game_pressed() -> void:
	if _new_game_sequence_running or _panel_transition_running:
		return
	_new_game_sequence_running = true
	PlayerSession.begin_new_run()
	button_new_game.disabled = true
	await _run_new_game_transition()


func _run_new_game_transition() -> void:
	Transition.set_overlay_blocks_input(true)
	await Transition.switch_overlay(_TRANSITION_SHADER_INDEX, false, _OVERLAY_SHOW_SEC)
	Transition.set_overlay_blocks_input(false)
	var name_layer := CanvasLayer.new()
	name_layer.layer = _INPUT_NAME_CANVAS_LAYER
	var input_name_root: Control = _NAME_INPUT_SCENE.instantiate()
	name_layer.add_child(input_name_root)
	add_child(name_layer)
	var line_edit: LineEdit = input_name_root.get_node("LineEdit") as LineEdit
	line_edit.grab_focus()
	var chosen_name: String = await input_name_root.name_confirmed
	PlayerSession.display_name = chosen_name
	name_layer.queue_free()
	Transition.set_overlay_blocks_input(true)
	await get_tree().create_timer(_DELAY_AFTER_NAME_BEFORE_TYPEWRITER_SEC).timeout
	await Transition.typewriter_display(_NEW_GAME_INTRO_TEXT, _TYPEWRITER_CHAR_SEC)
	await get_tree().create_timer(_HOLD_AFTER_INTRO_SEC).timeout
	get_tree().change_scene_to_packed(preload("res://Game.tscn"))


func _on_rank_pressed() -> void:
	if _rank_open or _panel_transition_running or _new_game_sequence_running:
		return
	await _open_rank_panel(-1)


func _on_rank_close_requested() -> void:
	if not _rank_open or _panel_transition_running:
		return
	await _close_rank_panel()


func _on_quit_pressed() -> void:
	if _panel_transition_running or _new_game_sequence_running:
		return
	get_tree().quit()


func _auto_open_rank_after_game_end() -> void:
	await get_tree().create_timer(_RANK_ENTRY_AUTO_OPEN_DELAY_SEC).timeout
	await _open_rank_panel(_pending_rank_entry_id)


func _open_rank_panel(focus_entry_id: int) -> void:
	_panel_transition_running = true
	_rank_open = true
	_set_main_menu_buttons_disabled(true)
	_menu_hover_angle = ANGLE_IDLE
	_pressed_index = -1
	_tween_buttons_for_hover(ANGLE_IDLE)
	rank_panel.prepare_for_open(focus_entry_id)
	rank_panel.position = _rank_hidden_left_position()
	rank_panel.scale = Vector2(0.96, 0.96)
	for index in range(_menu_panels.size()):
		var menu_panel: Control = _menu_panels[index]
		if index < _menu_panel_base_positions.size():
			menu_panel.position = _menu_panel_base_positions[index]
		menu_panel.scale = Vector2.ONE
		_kill_menu_panel_tween(index)
	var rank_tween := create_tween()
	rank_tween.set_parallel(true)
	rank_tween.tween_property(rank_panel, ^"position", _rank_panel_base_position, _PANEL_SLIDE_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rank_tween.tween_property(rank_panel, ^"scale", Vector2.ONE, _PANEL_SLIDE_SEC * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for index in range(_menu_panels.size()):
		var menu_panel: Control = _menu_panels[index]
		var tween := create_tween()
		_menu_panel_tweens[index] = tween
		tween.set_parallel(true)
		tween.tween_property(menu_panel, ^"position", _hidden_right_position(_menu_panel_base_positions[index]), _PANEL_SLIDE_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(menu_panel, ^"scale", Vector2(0.95, 0.95), _PANEL_SLIDE_SEC * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await rank_tween.finished
	_panel_transition_running = false


func _close_rank_panel() -> void:
	_panel_transition_running = true
	_set_main_menu_buttons_disabled(true)
	for index in range(_menu_panels.size()):
		_kill_menu_panel_tween(index)
	var rank_tween := create_tween()
	rank_tween.set_parallel(true)
	rank_tween.tween_property(rank_panel, ^"position", _rank_hidden_left_position(), _PANEL_SLIDE_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	rank_tween.tween_property(rank_panel, ^"scale", Vector2(0.96, 0.96), _PANEL_SLIDE_SEC * 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for index in range(_menu_panels.size()):
		var menu_panel: Control = _menu_panels[index]
		var tween := create_tween()
		_menu_panel_tweens[index] = tween
		tween.set_parallel(true)
		tween.tween_property(menu_panel, ^"position", _menu_panel_base_positions[index], _PANEL_SLIDE_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(menu_panel, ^"scale", Vector2.ONE, _PANEL_SLIDE_SEC * 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await rank_tween.finished
	rank_panel.hide_instant()
	_rank_open = false
	_panel_transition_running = false
	_set_main_menu_buttons_disabled(false)


func _set_main_menu_buttons_disabled(disabled: bool) -> void:
	for button in _buttons:
		button.disabled = disabled


func _hidden_right_position(base_position: Vector2) -> Vector2:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	return base_position + Vector2(viewport_width * _PANEL_SLIDE_RATIO, 0.0)


func _rank_hidden_left_position() -> Vector2:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	return _rank_panel_base_position - Vector2(viewport_width * _PANEL_SLIDE_RATIO, 0.0)


func _kill_menu_panel_tween(index: int) -> void:
	var tween: Tween = _menu_panel_tweens[index]
	if tween != null and tween.is_valid():
		tween.kill()
	_menu_panel_tweens[index] = null


func _play_menu_hover_sfx() -> void:
	var stream_index: int = randi() % _MENU_HOVER_SFX.size()
	_menu_hover_audio.stream = _MENU_HOVER_SFX[stream_index]
	_menu_hover_audio.play()


func _play_menu_click_sfx() -> void:
	_menu_click_audio.stream = _MENU_CLICK_SFX
	_menu_click_audio.play()
