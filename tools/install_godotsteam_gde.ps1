$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$zipPath = Join-Path $projectRoot ".tmp" "godotsteam-gde-plugin.zip"
$extractRoot = Join-Path $projectRoot ".tmp" "godotsteam-gde-unpack"
$url = "https://codeberg.org/godotsteam/godotsteam/releases/download/v4.18.1-gde/godotsteam-4.18.1-gdextension-plugin-4.4.zip"

New-Item -ItemType Directory -Path (Split-Path $zipPath) -Force | Out-Null
Write-Host "正在下载 GodotSteam GDExtension..."
Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
if ((Get-Item $zipPath).Length -lt 20MB) {
    throw "下载文件过小，可能不完整: $zipPath"
}
if (Test-Path $extractRoot) {
    Remove-Item -Recurse -Force $extractRoot
}
Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force
$inner = Get-ChildItem $extractRoot -Directory | Select-Object -First 1
if ($null -eq $inner) {
    throw "解压后未找到子目录: $extractRoot"
}
$target = Join-Path $projectRoot "addons" "godotsteam"
if (Test-Path $target) {
    Remove-Item -Recurse -Force $target
}
New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
Move-Item -Path $inner.FullName -Destination $target
Write-Host "已安装到 $target ，请在编辑器中重新加载项目。"
