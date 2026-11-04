# Устанавливает быстрый запуск Claude Code по Alt+Win+F5:
# кладёт ярлык в папку «Автозагрузка» и сразу запускает фоновую программу.
# Удалить: удалите ярлык «Claude Code hotkey (Alt+Win+F5)» из shell:startup.

$ps1 = Join-Path $PSScriptRoot 'claude-hotkey.ps1'
$psExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$psArgs = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ps1`""

$startup = [Environment]::GetFolderPath('Startup')
$lnk = Join-Path $startup 'Claude Code hotkey (Alt+Win+F5).lnk'
$ws = New-Object -ComObject WScript.Shell
$s = $ws.CreateShortcut($lnk)
$s.TargetPath = $psExe
$s.Arguments = $psArgs
$s.WorkingDirectory = Split-Path $PSScriptRoot
$s.WindowStyle = 7
$s.Description = 'Alt+Win+F5 запускает Claude Code с Telegram'
$s.Save()

Start-Process -FilePath $psExe -ArgumentList $psArgs -WindowStyle Hidden
Write-Host "Готово. Ярлык автозагрузки: $lnk"
Write-Host 'Нажмите Alt+Win+F5, чтобы запустить Claude Code.'
