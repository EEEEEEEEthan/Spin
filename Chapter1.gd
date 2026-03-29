extends Node3D

signal all_balloons_cleared

var _completion_started: bool = false


func _process(_delta: float) -> void:
	if _completion_started:
		return
	if get_tree().get_nodes_in_group("balloon").is_empty():
		_completion_started = true
		all_balloons_cleared.emit()
