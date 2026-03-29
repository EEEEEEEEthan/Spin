extends Node

const _OVERLAY_HIDE_SEC := 0.45
const _TRANSITION_SHADER_INDEX := 1


func _ready() -> void:
	Transition.clear_caption()
	await Transition.switch_overlay(_TRANSITION_SHADER_INDEX, true, _OVERLAY_HIDE_SEC)
	Transition.set_overlay_blocks_input(false)
