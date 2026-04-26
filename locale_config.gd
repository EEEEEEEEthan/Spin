extends Node

## 将所选语言存于 user://，读失败或无效时使用系统语言映射。

const _SETTINGS_FILE := "user://language_settings.json"
## 不写入 project.godot 的 translation 列表，避免启动器/编辑器预解析 PO 时崩或版本差异。
const _PO_REGISTRATIONS: Array[Dictionary] = [
	{"path": "res://localization/spin_en.po", "locale": "en"},
	{"path": "res://localization/spin_zh_TW.po", "locale": "zh_TW"},
	{"path": "res://localization/spin_ja.po", "locale": "ja"},
	{"path": "res://localization/spin_ko.po", "locale": "ko"},
	{"path": "res://localization/spin_es.po", "locale": "es"},
	{"path": "res://localization/spin_fr.po", "locale": "fr"},
	{"path": "res://localization/spin_de.po", "locale": "de"},
	{"path": "res://localization/spin_pt_BR.po", "locale": "pt_BR"},
]
## 与各 .po 中 msgid 及项目内 tr 一致，防止仅有外语表时 zh_CN 走 fallback 仍成英文
const _MSGIDS_ZH: PackedStringArray = [
	"新游戏",
	"名人堂",
	"退出",
	"消灭气球",
	"还没有成绩",
	"玩家",
	"请输入姓名",
	"英语",
	"简体中文",
	"繁体中文",
	"日语",
	"韩语",
	"西班牙语",
	"法语",
	"德语",
	"葡萄牙语",
	"游戏结束喽！",
	"你中了%d刀！",
]
const SUPPORTED_LOCALES: Array[String] = [
	"zh_CN",
	"zh_TW",
	"en",
	"ja",
	"ko",
	"es",
	"fr",
	"de",
	"pt_BR",
]

signal locale_changed(locale: String)


func _enter_tree() -> void:
	_register_chinese_identity_translation()
	for entry in _PO_REGISTRATIONS:
		_register_translation_from_po(String(entry.path), String(entry.locale))
	apply_startup_locale_from_save_or_system()


func _register_chinese_identity_translation() -> void:
	var t := Translation.new()
	t.locale = "zh_CN"
	for s in _MSGIDS_ZH:
		t.add_message(s, s)
	TranslationServer.add_translation(t)


func _register_translation_from_po(res_path: String, forced_locale: String) -> void:
	if not ResourceLoader.exists(res_path):
		push_warning("未找到翻译资源: %s" % res_path)
		return
	var loaded: Resource = load(res_path) as Resource
	if loaded is Translation:
		var tr_res: Translation = loaded as Translation
		tr_res.locale = forced_locale
		TranslationServer.add_translation(tr_res)
		return
	push_warning("资源不是 Translation，已跳过: %s" % res_path)


func get_language_button_caption() -> String:
	match TranslationServer.get_locale():
		"zh_CN":
			return tr("简体中文")
		"zh_TW":
			return tr("繁体中文")
		"en":
			return tr("英语")
		"ja":
			return tr("日语")
		"ko":
			return tr("韩语")
		"es":
			return tr("西班牙语")
		"fr":
			return tr("法语")
		"de":
			return tr("德语")
		"pt_BR":
			return tr("葡萄牙语")
		_:
			return TranslationServer.get_locale()


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
	else:
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
	if normalized.begins_with("ja"):
		return "ja"
	if normalized.begins_with("ko"):
		return "ko"
	if normalized.begins_with("es"):
		return "es"
	if normalized.begins_with("fr"):
		return "fr"
	if normalized.begins_with("de"):
		return "de"
	if normalized.begins_with("pt"):
		return "pt_BR"
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
