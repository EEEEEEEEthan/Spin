extends Node

const _NEW_GAME_INTRO_TEXT := "消灭气球"
const _DELAY_BEFORE_TYPEWRITER_SEC := 1.0
const _HOLD_AFTER_TYPEWRITER_SEC := 2.0
const _TYPEWRITER_CHAR_SEC := 0.1
const _OVERLAY_SHOW_SEC := 0.35
const _OVERLAY_HIDE_SEC := 0.45
const _TRANSITION_SHADER_INDEX := 1

@onready var _button_new_game: BaseButton = $MainMenu/Control/Button_NewGame
@onready var _transition: ColorRect = %Transition
@onready var _transition_label: Label = %TransitionLabel

var _new_game_sequence_running: bool = false


func _ready() -> void:
	_transition_label.text = ""
	_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button_new_game.pressed.connect(_on_new_game_pressed)


func _on_new_game_pressed() -> void:
	if _new_game_sequence_running:
		return
	_new_game_sequence_running = true
	_button_new_game.disabled = true
	await _run_new_game_intro_transition()
	_button_new_game.disabled = false
	_new_game_sequence_running = false


func _run_new_game_intro_transition() -> void:
	_transition.mouse_filter = Control.MOUSE_FILTER_STOP
	_transition.call("switch", _TRANSITION_SHADER_INDEX, false, _OVERLAY_SHOW_SEC)
	await get_tree().create_timer(_DELAY_BEFORE_TYPEWRITER_SEC).timeout
	await _typewriter_show_text(_NEW_GAME_INTRO_TEXT, _TYPEWRITER_CHAR_SEC)
	await get_tree().create_timer(_HOLD_AFTER_TYPEWRITER_SEC).timeout
	_transition_label.text = ""
	_transition.call("switch", _TRANSITION_SHADER_INDEX, true, _OVERLAY_HIDE_SEC)
	await get_tree().create_timer(_OVERLAY_HIDE_SEC).timeout
	_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _typewriter_show_text(full_text: String, seconds_per_character: float) -> void:
	_transition_label.text = ""
	for end_index in range(1, full_text.length() + 1):
		_transition_label.text = full_text.substr(0, end_index)
		await get_tree().create_timer(seconds_per_character).timeout
