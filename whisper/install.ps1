# Устанавливает локальную расшифровку голосовых (faster-whisper) для бота.
# Запуск: powershell -ExecutionPolicy Bypass -File whisper\install.ps1 [-Model medium]
# Ставит всё в %USERPROFILE%\claude-telegram\whisper и скачивает модель (medium ≈ 1,5 ГБ, small ≈ 480 МБ).
param([string]$Model = 'medium')

$ErrorActionPreference = 'Stop'
$Dest = Join-Path $env:USERPROFILE 'claude-telegram\whisper'
New-Item -ItemType Directory -Force $Dest | Out-Null
if ($PSScriptRoot -ne $Dest) { Copy-Item (Join-Path $PSScriptRoot 'transcribe_worker.py') $Dest -Force }

# Нужен Python 3.10+ (py launcher). Берём самый новый рабочий.
$py = $null
foreach ($v in '3.14', '3.13', '3.12', '3.11', '3.10') {
    try { & py "-$v" -c "import sys" 2>$null; if ($LASTEXITCODE -eq 0) { $py = $v; break } } catch {}
}
if (-not $py) { throw 'Не найден Python 3.10+. Установите его с python.org (галочка «py launcher»).' }

Write-Host "Python $py → создаю окружение..."
& py "-$py" -m venv (Join-Path $Dest '.venv')
$venvPy = Join-Path $Dest '.venv\Scripts\python.exe'
& $venvPy -m pip install --disable-pip-version-check -q --upgrade pip
& $venvPy -m pip install --disable-pip-version-check -q faster-whisper

Write-Host "Скачиваю модель $Model (один раз)..."
$env:WHISPER_MODEL = $Model
'' | & $venvPy (Join-Path $Dest 'transcribe_worker.py')
Write-Host "Готово. Если модель не medium, задайте переменную окружения WHISPER_MODEL=$Model для Claude Code."
