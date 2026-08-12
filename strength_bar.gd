@tool
extends TextureRect

var _progress: float = 0.705

@export_range(0, 1) var progress: float:
	get:
		return _progress
	set(value):
		_progress = value
		if material != null:
			material.set_shader_parameter(&"progress", _progress)
