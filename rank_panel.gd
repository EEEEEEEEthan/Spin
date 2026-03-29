class_name RankPanel
extends NinePatchRect

signal close_requested

const _RANK_ITEM_SCENE := preload("res://RankItem.tscn")
const _FOCUS_SCROLL_SEC := 0.58
const _ICON_PULSE_SEC := 0.32

@onready var _scroll_container: ScrollContainer = $ScrollContainer
@onready var _list_container: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var _close_button: TextureButton = $TextureButton

var _highlight_item: Control = null
var _highlight_icon: TextureRect = null
var _highlight_tween: Tween
var _scroll_tween: Tween


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)


func prepare_for_open(focus_entry_id: int) -> void:
	show()
	_rebuild_entries(focus_entry_id)
	call_deferred(&"_focus_highlight_entry")


func hide_instant() -> void:
	if _highlight_tween != null and _highlight_tween.is_valid():
		_highlight_tween.kill()
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	hide()


func _rebuild_entries(focus_entry_id: int) -> void:
	_highlight_item = null
	_highlight_icon = null
	for child in _list_container.get_children():
		child.free()
	var rank_entries: Array = PlayerSession.get_rank_entries()
	if rank_entries.is_empty():
		_add_empty_state()
		_scroll_container.scroll_vertical = 0
		return
	for rank_entry_variant in rank_entries:
		var rank_entry: Dictionary = rank_entry_variant
		var item_root: HBoxContainer = _RANK_ITEM_SCENE.instantiate() as HBoxContainer
		var icon: TextureRect = item_root.get_node("Icon") as TextureRect
		var name_label: Label = item_root.get_node("Name") as Label
		var score_label: Label = item_root.get_node("Score") as Label
		var is_highlighted: bool = int(rank_entry.get("id", -1)) == focus_entry_id
		icon.visible = is_highlighted
		name_label.text = String(rank_entry.get("name", "玩家"))
		score_label.text = str(int(rank_entry.get("score", 0)))
		_list_container.add_child(item_root)
		if is_highlighted:
			_highlight_item = item_root
			_highlight_icon = icon
	_scroll_container.scroll_vertical = 0


func _add_empty_state() -> void:
	var empty_label := Label.new()
	empty_label.text = "还没有成绩"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	empty_label.add_theme_font_size_override("font_size", 64)
	empty_label.custom_minimum_size = Vector2(0, 160)
	_list_container.add_child(empty_label)


func _focus_highlight_entry() -> void:
	if _highlight_item == null or _highlight_icon == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var target_scroll := _target_scroll_for_item(_highlight_item)
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = create_tween()
	_scroll_tween.tween_property(_scroll_container, ^"scroll_vertical", target_scroll, _FOCUS_SCROLL_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_highlight_icon.pivot_offset = _highlight_icon.size * 0.5
	_highlight_icon.scale = Vector2(0.7, 0.7)
	if _highlight_tween != null and _highlight_tween.is_valid():
		_highlight_tween.kill()
	_highlight_tween = create_tween()
	_highlight_tween.set_loops()
	_highlight_tween.tween_property(_highlight_icon, ^"scale", Vector2(1.18, 1.18), _ICON_PULSE_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(_highlight_icon, ^"scale", Vector2.ONE, _ICON_PULSE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _target_scroll_for_item(item_root: Control) -> int:
	var viewport_height: float = _scroll_container.get_rect().size.y
	var target_y: float = item_root.position.y - viewport_height * 0.5 + item_root.size.y * 0.5
	var max_scroll: float = maxf(0.0, _list_container.size.y - viewport_height)
	return int(clampf(target_y, 0.0, max_scroll))


func _on_close_pressed() -> void:
	close_requested.emit()
