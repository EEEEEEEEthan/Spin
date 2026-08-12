extends Object
class_name TouchControls

## 是否走触控/Web 优先的操作路径（拖拽视角 + 投掷按钮）。
## Web、移动端或系统报告有触屏时启用；桌面原生无触屏仍用鼠标捕获。
static func is_preferred() -> bool:
	return (
		OS.has_feature("web")
		or OS.has_feature("mobile")
		or DisplayServer.is_touchscreen_available()
	)
