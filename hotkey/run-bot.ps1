# Запускает Claude Code с Telegram и перезапускает его, когда бот сам
# просит очистить память сессии (файл restart.request). Если вы закрыли
# Claude Code сами (Ctrl+C дважды), окно закрывается. Если Claude Code упал
# с ошибкой в первые секунды — окно остаётся, чтобы ошибку было видно.
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
    $started = Get-Date
    & $ClaudeExe @ClaudeArgs
    $code = $LASTEXITCODE
    if (-not (Test-Path $Flag)) {
        if ($code -ne 0 -and ((Get-Date) - $started).TotalSeconds -lt 20) {
            Write-Host ''
            Write-Host "Claude Code завершился с ошибкой (код $code). Нажмите Enter, чтобы закрыть окно."
            [void](Read-Host)
        }
        break
    }
    Write-Host ''
    Write-Host 'Бот очищает память сессии — перезапуск через 3 секунды...'
    Start-Sleep -Seconds 3
    Clear-Host
}
exit 0
