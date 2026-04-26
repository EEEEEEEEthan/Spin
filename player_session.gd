extends Node

## 开场输入的玩家显示名（第四关 Label3D 等读取）。
var display_name: String = ""
var current_human_hit_count: int = 0

const _LEADERBOARD_SAVE_PATH := "user://leaderboard.json"

const _HUMAN_HIT_SFX: Array[AudioStream] = [
	preload("res://Audios/受击.wav"),
	preload("res://Audios/受击2.wav"),
]

var _leaderboard_entries: Array[Dictionary] = []
var _counted_human_hit_knife_ids: Dictionary = {}
var _next_entry_id: int = 1
var _pending_rank_entry_id: int = -1


func _ready() -> void:
	SteamBridge.ranking_mode_ready.connect(_on_steam_ranking_mode_ready, CONNECT_ONE_SHOT)


func _on_steam_ranking_mode_ready(use_steam: bool) -> void:
	if use_steam:
		return
	_load_leaderboard()


func begin_new_run() -> void:
	current_human_hit_count = 0
	_counted_human_hit_knife_ids.clear()
	_pending_rank_entry_id = -1


func register_human_hit(knife: Node, play_hit_sfx: bool = true, hit_sfx_volume_db: float = 0.0) -> void:
	var knife_id: int = knife.get_instance_id()
	if _counted_human_hit_knife_ids.has(knife_id):
		return
	_counted_human_hit_knife_ids[knife_id] = true
	current_human_hit_count += 1
	if play_hit_sfx:
		_play_human_hit_sfx(hit_sfx_volume_db)


func _play_human_hit_sfx(volume_db: float) -> void:
	var stream_index: int = randi() % _HUMAN_HIT_SFX.size()
	var hit_player := AudioStreamPlayer.new()
	add_child(hit_player)
	hit_player.stream = _HUMAN_HIT_SFX[stream_index]
	hit_player.volume_db = volume_db
	hit_player.finished.connect(hit_player.queue_free)
	hit_player.play()


func submit_current_score_and_prepare_focus() -> int:
	if SteamBridge.is_active():
		var local_steam_id: int = SteamBridge.get_local_user_id_for_ui()
		SteamBridge.queue_upload_score(current_human_hit_count)
		_pending_rank_entry_id = local_steam_id
		return local_steam_id
	var entry_id: int = _next_entry_id
	_next_entry_id += 1
	var score_entry := {
		"id": entry_id,
		"name": display_name,
		"score": current_human_hit_count,
	}
	_leaderboard_entries.append(score_entry)
	_leaderboard_entries.sort_custom(_sort_rank_entries)
	_pending_rank_entry_id = entry_id
	_save_leaderboard()
	return entry_id


func get_rank_entries() -> Array:
	if SteamBridge.is_active():
		return SteamBridge.get_cached_rank_rows()
	return _leaderboard_entries.duplicate(true)


func consume_pending_rank_entry_id() -> int:
	var pending_rank_entry_id: int = _pending_rank_entry_id
	_pending_rank_entry_id = -1
	return pending_rank_entry_id


func _sort_rank_entries(left_entry: Dictionary, right_entry: Dictionary) -> bool:
	var left_score: int = int(left_entry.get("score", 0))
	var right_score: int = int(right_entry.get("score", 0))
	if left_score != right_score:
		return left_score > right_score
	return int(left_entry.get("id", -1)) > int(right_entry.get("id", -1))


func _load_leaderboard() -> void:
	if not FileAccess.file_exists(_LEADERBOARD_SAVE_PATH):
		return
	var save_text: String = FileAccess.get_file_as_string(_LEADERBOARD_SAVE_PATH)
	if save_text == "":
		return
	var parsed_data: Variant = JSON.parse_string(save_text)
	if typeof(parsed_data) != TYPE_DICTIONARY:
		push_warning("排行榜存档格式不正确，已忽略。")
		return
	var save_dict: Dictionary = parsed_data
	_next_entry_id = max(1, int(save_dict.get("next_entry_id", 1)))
	_leaderboard_entries.clear()
	var loaded_entries: Variant = save_dict.get("entries", [])
	if loaded_entries is Array:
		for loaded_entry_variant in loaded_entries:
			if typeof(loaded_entry_variant) != TYPE_DICTIONARY:
				continue
			var loaded_entry: Dictionary = loaded_entry_variant
			var entry_id: int = int(loaded_entry.get("id", _next_entry_id))
			var score_entry := {
				"id": entry_id,
				"name": String(loaded_entry.get("name", "玩家")),
				"score": int(loaded_entry.get("score", 0)),
			}
			_leaderboard_entries.append(score_entry)
			_next_entry_id = max(_next_entry_id, entry_id + 1)
	_leaderboard_entries.sort_custom(_sort_rank_entries)


func _save_leaderboard() -> void:
	var save_file: FileAccess = FileAccess.open(_LEADERBOARD_SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_warning("排行榜存档写入失败。")
		return
	var save_dict := {
		"next_entry_id": _next_entry_id,
		"entries": _leaderboard_entries,
	}
	save_file.store_string(JSON.stringify(save_dict, "\t"))
