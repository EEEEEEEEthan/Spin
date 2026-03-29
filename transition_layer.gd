extends CanvasLayer

const _default_layer := 100

@onready var _overlay: ColorRect = $Transition
@onready var _caption_label: Label = $Transition/TransitionLabel
@onready var _typewriter_tick: AudioStreamPlayer = $TypewriterTick


func _ready() -> void:
	layer = _default_layer
	clear_caption()
	set_overlay_blocks_input(false)


func set_overlay_blocks_input(blocking: bool) -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if blocking else Control.MOUSE_FILTER_IGNORE


## shader 转场；可 await。
func switch_overlay(shader_index: int, reveal: bool, duration_seconds: float) -> void:
	await _overlay.switch(shader_index, reveal, duration_seconds)


## 延迟后揭开幕布并恢复输入；供换场景后仍由 autoload 执行（勿 await 调用处）。
func begin_delayed_overlay_reveal(
	shader_index: int, delay_seconds: float, hide_duration_seconds: float
) -> void:
	await get_tree().create_timer(delay_seconds).timeout
	clear_caption()
	await switch_overlay(shader_index, true, hide_duration_seconds)
	set_overlay_blocks_input(false)


## 打字机显示完整文案；可 await。
func typewriter_display(full_text: String, seconds_per_character: float) -> void:
	_caption_label.text = ""
	for end_index in range(1, full_text.length() + 1):
		_caption_label.text = full_text.substr(0, end_index)
		_typewriter_tick.play()
		await get_tree().create_timer(seconds_per_character).timeout


func clear_caption() -> void:
	_caption_label.text = ""
