extends Node

## 将所选语言存于 user://，读失败或无效时使用系统语言映射。

const _SETTINGS_FILE := "user://language_settings.json"
## 不写入 project.godot 的 translation 列表，避免启动器/编辑器预解析 PO 时崩或版本差异。
const _EN_TRANSLATION_PATH := "res://localization/spin_en.po"
const _ZH_TW_TRANSLATION_PATH := "res://localization/spin_zh_TW.po"
## 与 spin_en.po 中 msgid 及项目内 tr 一致，防止仅有 en 时 zh_CN 走 fallback 仍成英文
const _MSGIDS_ZH: PackedStringArray = [
	"新游戏", "名人堂", "退出", "消灭气球", "还没有成绩", "玩家", "请输入姓名", "英语", "简体中文", "繁体中文",
	"游戏结束喽！", "你中了%d刀！",
]
const SUPPORTED_LOCALES: Array[String] = ["zh_CN", "zh_TW", "en"]

signal locale_changed(locale: String)

func _enter_tree() -> void:
	_register_chinese_identity_translation()
	_register_translation_from_po(_EN_TRANSLATION_PATH)
	_register_translation_from_po(_ZH_TW_TRANSLATION_PATH)
	apply_startup_locale_from_save_or_system()


func _register_chinese_identity_translation() -> void:
	var t := Translation.new()
	t.locale = "zh_CN"
	for s in _MSGIDS_ZH:
		t.add_message(s, s)
	TranslationServer.add_translation(t)


func _register_translation_from_po(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("未找到翻译资源: %s" % path)
		return
	var loaded: Resource = load(path) as Resource
	if loaded is Translation:
		var tr_res: Translation = loaded as Translation
		# spin_zh_TW.po 在部分引擎版本下解析为 en，会与 spin_en.po 冲突
		if path == _ZH_TW_TRANSLATION_PATH:
			tr_res.locale = "zh_TW"
		elif path == _EN_TRANSLATION_PATH:
			tr_res.locale = "en"
		TranslationServer.add_translation(tr_res)
		return
	push_warning("资源不是 Translation，已跳过: %s" % path)


func get_language_button_caption() -> String:
	match TranslationServer.get_locale():
		"en":
			return tr("英语")
		"zh_TW":
			return tr("繁体中文")
		_:
			return tr("简体中文")


func set_locale_code(locale: String) -> void:
	if locale not in SUPPORTED_LOCALES:
		return
	TranslationServer.set_locale(locale)
	_persist_locale(locale)
	locale_changed.emit(locale)


func apply_startup_locale_from_save_or_system() -> void:
	var from_save := _read_saved_locale_code()
	if from_save.is_empty():
		TranslationServer.set_locale(_map_system_locale(OS.get_locale()))
		return
	TranslationServer.set_locale(from_save)


func _persist_locale(locale: String) -> void:
	var data := {"locale": locale}
	var text := JSON.stringify(data)
	var file_access: FileAccess = FileAccess.open(_SETTINGS_FILE, FileAccess.WRITE)
	if file_access == null:
		push_warning("无法写入语言设置: %s" % _SETTINGS_FILE)
		return
	file_access.store_string(text)
	file_access.close()


func _read_saved_locale_code() -> String:
	if not FileAccess.file_exists(_SETTINGS_FILE):
		return ""
	var text := FileAccess.get_file_as_string(_SETTINGS_FILE)
	if text.is_empty():
		return ""
	var json := JSON.new()
	if json.parse(text) != OK:
		return ""
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	var locale: String = String((data as Dictionary).get("locale", ""))
	if locale.is_empty() or locale not in SUPPORTED_LOCALES:
		return ""
	return locale


func _map_system_locale(os_locale: String) -> String:
	var normalized: String = os_locale.to_lower().replace("-", "_")
	if normalized == "zh_tw" or normalized == "zh_hk" or normalized == "zh_mo":
		return "zh_TW"
	if normalized.begins_with("zh"):
		return "zh_CN"
	if normalized.begins_with("en"):
		return "en"
	return "en"


func cycle_to_next_supported_locale() -> void:
	var current: String = TranslationServer.get_locale()
	var index: int = SUPPORTED_LOCALES.find(current)
	if index < 0:
		index = 0
	else:
		index = (index + 1) % SUPPORTED_LOCALES.size()
	set_locale_code(SUPPORTED_LOCALES[index])
