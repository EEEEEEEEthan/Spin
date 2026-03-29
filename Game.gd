extends Node

const _OVERLAY_HIDE_SEC := 0.45
const _OVERLAY_SHOW_SEC := 0.35
const _TRANSITION_SHADER_INDEX := 1
const _TYPEWRITER_CHAR_SEC := 0.1


func _ready() -> void:
	Transition.clear_caption()
	await Transition.switch_overlay(_TRANSITION_SHADER_INDEX, true, _OVERLAY_HIDE_SEC)
	Transition.set_overlay_blocks_input(false)
	_connect_chapter1_balloon_clear_if_any()


func _connect_chapter1_balloon_clear_if_any() -> void:
	var chapter_root: Node = get_node_or_null("Game2")
	if chapter_root and chapter_root.has_signal(&"all_balloons_cleared"):
		chapter_root.all_balloons_cleared.connect(_on_chapter1_all_balloons_cleared)


func _on_chapter1_all_balloons_cleared() -> void:
	await _run_chapter1_cleared_sequence()


func _run_chapter1_cleared_sequence() -> void:
	Transition.set_overlay_blocks_input(true)
	await Transition.switch_overlay(_TRANSITION_SHADER_INDEX, false, _OVERLAY_SHOW_SEC)
	await get_tree().create_timer(1.0).timeout
	await Transition.typewriter_display("击中靶子", _TYPEWRITER_CHAR_SEC)
	var old_chapter: Node = $Game2
	old_chapter.name = "_Chapter1_done"
	var chapter2_root: Node = preload("res://Chapter2.tscn").instantiate()
	chapter2_root.name = "Game2"
	add_child(chapter2_root)
	old_chapter.queue_free()
	await get_tree().create_timer(3.0).timeout
	await Transition.switch_overlay(_TRANSITION_SHADER_INDEX, true, _OVERLAY_HIDE_SEC)
	Transition.set_overlay_blocks_input(false)
