---
name: spin-project-config
description: Spin 项目环境与工具链：Windows、Blender 5.1.0、Godot 4.7-dev3 Mono，引擎位于 .engine/.engine.exe，含 .engine-prepare / .engine-edit 批处理。在配置开发环境、运行 Godot 命令行、Blender 导出或与 Spin 仓库相关的引擎路径问题时使用。
---

# Spin 项目配置

## 平台与版本（约定）

| 组件 | 版本 / 说明 |
|------|-------------|
| 操作系统 | Windows（本仓库脚本与路径按 Win 编写） |
| Godot | **4.7-dev3**，**Mono**（`project.godot` 中 `config/features` 含 `4.7`） |
| Blender | **5.1.0** |

## Godot 引擎路径

- 引擎目录：项目根下的 `.engine/`（已 `.gitignore`，需本地准备）。
- 可执行文件：优先使用 **`.engine/.engine.exe`**（由准备脚本生成的硬链接，指向实际 `Godot_v4.7-dev3_mono_win64.exe`）。
- 首次或更新引擎：在项目根运行 **`.engine-prepare.bat`**（下载并解压到 `.engine`，并创建 `.engine.exe`）。
- 启动编辑器：运行 **`.engine-edit.bat`**（等价于先 prepare 再 `start .\.engine\.engine.exe --editor`）。

命令行示例（在项目根 `C:\Projects\Spin`）：

```text
.\.engine\.engine.exe --path . --editor
.\.engine\.engine.exe --path . --headless --quit-after 1
```

路径与参数按实际需要调整；始终用 **正斜杠或 Windows 反斜杠** 与当前 shell 一致即可。

## Blender

- 文档与自动化中假定 **Blender 5.1.0**；批处理/脚本若调用 `blender`，应使用本机安装路径或 `PATH` 中的 5.1.0，避免混用旧主版本。

## 对 Agent 的约束

- 需要运行 Godot 时：优先引用 **`.engine/.engine.exe`**，不要假设系统全局安装的 Godot 版本与项目一致。
- 不要提交 `.engine/` 或 `.tmp/` 内容。
- 修改与引擎版本相关的脚本时，应与 **`.engine-prepare.bat`** 中的 `versionNumber` / `flavor` 保持一致。
