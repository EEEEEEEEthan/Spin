extends Node

## GodotSteam GDExtension 桥接：排行榜上传与拉取。
## 插件安装：在项目根执行 `powershell -File tools/install_godotsteam_gde.ps1`
## Steamworks 后台需存在与 `steam/leaderboard/human_hits_internal_name` 同名的排行榜（降序、数值）。

signal ranking_mode_ready(use_steam: bool)

const _SETTING_APP_ID := "steam/initialization/app_id"
const _SETTING_BOARD_NAME := "steam/leaderboard/human_hits_internal_name"

var _steam: Object
var _initialized: bool = false
var _leaderboard_ready: bool = false
var _cached_rows: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_begin_steam_init")


func _begin_steam_init() -> void:
	_steam = Engine.get_singleton("Steam")
	if _steam == null:
		ranking_mode_ready.emit(false)
		return
	var app_id: int = int(ProjectSettings.get_setting(_SETTING_APP_ID, 0))
	if not _steam.steamInit(app_id, false):
		push_warning("Steam 初始化失败，排行榜将使用本地存档。")
		ranking_mode_ready.emit(false)
		return
	_initialized = true
	var board_name: String = String(ProjectSettings.get_setting(_SETTING_BOARD_NAME, "SPIN_HUMAN_HITS"))
	_steam.findOrCreateLeaderboard(board_name, 2, 1)
	var find_args: Variant = await _steam.leaderboard_find_result
	var found: int = int(find_args[1])
	if found == 0:
		push_warning("Steam 排行榜未找到或未创建: %s，将使用本地存档。" % board_name)
		_initialized = false
		ranking_mode_ready.emit(false)
		return
	_leaderboard_ready = true
	ranking_mode_ready.emit(true)


func _process(_delta: float) -> void:
	if not _initialized or _steam == null:
		return
	_steam.run_callbacks()


func is_active() -> bool:
	return _initialized and _leaderboard_ready


func get_cached_rank_rows() -> Array:
	var out: Array = []
	for row in _cached_rows:
		out.append(row.duplicate(true))
	return out


func get_local_user_id_for_ui() -> int:
	if _steam == null:
		return -1
	return int(_steam.getSteamID())


func queue_upload_score(score: int) -> void:
	if not is_active():
		return
	call_deferred("_upload_score_task", score)


func _upload_score_task(score: int) -> void:
	if not is_active():
		return
	_steam.uploadLeaderboardScore(score, true)
	var upload_args: Variant = await _steam.leaderboard_score_uploaded
	var success: bool = bool(upload_args[0])
	if not success:
		push_warning("Steam 排行榜分数上传失败。")


func request_global_leaderboard_async() -> void:
	if not is_active():
		return
	_steam.downloadLeaderboardEntries(0, 99, 0)
	var download_args: Variant = await _steam.leaderboard_scores_downloaded
	var raw_entries: Variant = download_args[2]
	if typeof(raw_entries) != TYPE_ARRAY:
		_cached_rows.clear()
		return
	_cached_rows.clear()
	for entry_variant in raw_entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var steam_id: int = int(entry.get("steam_id", 0))
		var score_value: int = int(entry.get("score", 0))
		var global_rank: int = int(entry.get("global_rank", 0))
		var persona: String = _steam.getFriendPersonaName(steam_id)
		if persona.is_empty():
			persona = "玩家"
		var display_name: String = persona
		if global_rank > 0:
			display_name = "%d. %s" % [global_rank, persona]
		_cached_rows.append(
			{
				"id": steam_id,
				"name": display_name,
				"score": score_value,
			}
		)
	_cached_rows.sort_custom(_sort_rows)


func _sort_rows(left: Dictionary, right: Dictionary) -> bool:
	var left_score: int = int(left.get("score", 0))
	var right_score: int = int(right.get("score", 0))
	if left_score != right_score:
		return left_score > right_score
	return int(left.get("id", -1)) > int(right.get("id", -1))
