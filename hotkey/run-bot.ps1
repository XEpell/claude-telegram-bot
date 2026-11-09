# Запускает Claude Code с Telegram и перезапускает его, когда бот сам
# просит очистить память сессии (файл restart.request). Если вы закрыли
# Claude Code сами (Ctrl+C), окно просто остаётся открытым — без перезапуска.
param(
    [string]$WorkDir   = (Join-Path $env:USERPROFILE 'claude-telegram'),
    [string]$ClaudeExe = (Join-Path $env:USERPROFILE '.local\bin\claude.exe')
)

$ClaudeArgs = @('--channels', 'plugin:telegram@claude-plugins-official')
$StateDir   = if ($env:TELEGRAM_STATE_DIR) { $env:TELEGRAM_STATE_DIR } else { Join-Path $env:USERPROFILE '.claude\channels\telegram' }
$Flag       = Join-Path $StateDir 'restart.request'

New-Item -ItemType Directory -Force $WorkDir | Out-Null
Set-Location $WorkDir

while ($true) {
    Remove-Item $Flag -ErrorAction SilentlyContinue
    & $ClaudeExe @ClaudeArgs
    if (-not (Test-Path $Flag)) { break }
    Write-Host ''
    Write-Host 'Бот очищает память сессии — перезапуск через 3 секунды...'
    Start-Sleep -Seconds 3
    Clear-Host
}
