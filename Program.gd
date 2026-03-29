extends Node

const _NEW_GAME_INTRO_TEXT := "消灭气球"
const _DELAY_BEFORE_TYPEWRITER_SEC := 1.0
const _HOLD_AFTER_TYPEWRITER_SEC := 2.0
const _TYPEWRITER_CHAR_SEC := 0.1
const _OVERLAY_SHOW_SEC := 0.35
const _OVERLAY_HIDE_SEC := 0.45
const _TRANSITION_SHADER_INDEX := 1

@onready var _button_new_game: BaseButton = $MainMenu/Control/Button_NewGame

var _new_game_sequence_running: bool = false


func _ready() -> void:
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
	Transition.set_overlay_blocks_input(true)
	Transition.switch_overlay(_TRANSITION_SHADER_INDEX, false, _OVERLAY_SHOW_SEC)
	await get_tree().create_timer(_DELAY_BEFORE_TYPEWRITER_SEC).timeout
	await Transition.typewriter_display(_NEW_GAME_INTRO_TEXT, _TYPEWRITER_CHAR_SEC)
	await get_tree().create_timer(_HOLD_AFTER_TYPEWRITER_SEC).timeout
	Transition.clear_caption()
	await Transition.switch_overlay(_TRANSITION_SHADER_INDEX, true, _OVERLAY_HIDE_SEC)
	Transition.set_overlay_blocks_input(false)
