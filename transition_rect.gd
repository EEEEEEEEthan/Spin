@tool
extends ColorRect

@export var materials: Array[Material] = []

var _material_index: int = 0

@export var index: int = 0:
	get:
		return _material_index
	set(value):
		_material_index = value
		if not materials.is_empty():
			material = materials[posmod(_material_index, materials.size())]

var _switch_tween: Tween


## shader：modulate.a 1=全黑 0=全透；reveal 为 true 表示揭开（变透）。可 await。
func switch(shader_index: int, reveal: bool, duration_seconds: float) -> void:
	self.index = shader_index
	# 从隐藏切到显示（盖住画面）时清空字幕，避免上一段文案残留
	if not reveal:
		var caption := get_node_or_null("TransitionLabel")
		if caption is Label:
			caption.text = ""
	if _switch_tween != null and _switch_tween.is_valid():
		_switch_tween.kill()
	var target_alpha := 0.0 if reveal else 1.0
	_switch_tween = create_tween()
	_switch_tween.tween_property(self, "modulate:a", target_alpha, duration_seconds)
	await _switch_tween.finished
