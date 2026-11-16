# Открывает Claude Code с Telegram в новом окне PowerShell:
#  • сам — через 5 секунд после входа в Windows;
#  • по Alt+Win+F5 — в любой момент (если окно ещё не открыто).
# Работает в фоне без окна; запускается при входе в Windows (ярлык в папке «Автозагрузка»).
param([switch]$Detached)

$ErrorActionPreference = 'Stop'

# Запускаемся заново «отдельно» (через WMI) и БЕЗ окна (conhost --headless):
# Windows Terminal игнорирует -WindowStyle Hidden и показывает пустое окно,
# закрыв которое, пользователь убивал и горячую клавишу.
if (-not $Detached) {
    try {
        $cmd = "conhost.exe --headless powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Detached"
        $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd }
        if ($r.ReturnValue -eq 0) { exit }
    } catch {}
    # Не получилось — просто работаем в этом процессе.
}

$ClaudeExe  = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
$WorkDir    = Join-Path $env:USERPROFILE 'claude-telegram'
$ClaudeArgs = '--channels plugin:telegram@claude-plugins-official'

Add-Type -AssemblyName System.Windows.Forms

# Только одна копия фоновой программы.
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\ClaudeHotkeyAltWinF5', [ref]$created)
if (-not $created) { exit }

Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public class ClaudeHotkeyForm : Form {
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr h, int id, uint mods, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr h, int id);

    const uint MOD_ALT = 0x1, MOD_WIN = 0x8, MOD_NOREPEAT = 0x4000, VK_F5 = 0x74;
    const int WM_HOTKEY = 0x0312;

    public event EventHandler Pressed;
    public bool Registered;

    public ClaudeHotkeyForm() {
        ShowInTaskbar = false;
        FormBorderStyle = FormBorderStyle.FixedToolWindow;
        Opacity = 0;
    }

    // Окно никогда не показывается, но нужно для получения сообщений.
    protected override void SetVisibleCore(bool value) {
        if (!IsHandleCreated) {
            CreateHandle();
            Registered = RegisterHotKey(Handle, 1, MOD_ALT | MOD_WIN | MOD_NOREPEAT, VK_F5);
        }
        base.SetVisibleCore(false);
    }

    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY && Pressed != null) Pressed(this, EventArgs.Empty);
        base.WndProc(ref m);
    }

    protected override void OnFormClosed(FormClosedEventArgs e) {
        UnregisterHotKey(Handle, 1);
        base.OnFormClosed(e);
    }
}
'@

function Show-Note([string]$text) {
    [System.Windows.Forms.MessageBox]::Show($text, 'Claude Code', 'OK', 'Information') | Out-Null
}

# Через сколько секунд после входа в Windows открыть бота сам
# (время на подключение интернета и VPN). 0 — не открывать автоматически.
$AutoStartDelaySec = 5

# Открывает окно Claude Code с Telegram. $quiet — не показывать окно
# «уже запущен» (для автозапуска).
function Start-ClaudeBot([bool]$quiet) {
    try {
        $running = Get-CimInstance Win32_Process -Filter "Name='claude.exe'" |
            Where-Object { $_.CommandLine -match '--channels' }
        if ($running) {
            if (-not $quiet) {
                Show-Note 'Claude Code с Telegram уже запущен. Второе окно открывать нельзя: два окна мешают друг другу получать сообщения бота.'
            }
            return
        }
        if (-not (Test-Path $ClaudeExe)) {
            Show-Note "Не найден Claude Code: $ClaudeExe"
            return
        }
        New-Item -ItemType Directory -Force $WorkDir | Out-Null
        # run-bot.ps1 перезапускает Claude Code, когда бот очищает память сессии.
        $runBot = Join-Path $PSScriptRoot 'run-bot.ps1'
        Start-Process powershell.exe -WorkingDirectory $WorkDir -ArgumentList @(
            '-ExecutionPolicy', 'Bypass', '-File', "`"$runBot`"",
            '-WorkDir', "`"$WorkDir`"", '-ClaudeExe', "`"$ClaudeExe`"")
    } catch {
        Show-Note "Не удалось запустить Claude Code: $_"
    }
}

$form = New-Object ClaudeHotkeyForm
$form.add_Pressed({ Start-ClaudeBot $false })

# Создаём окно и регистрируем сочетание клавиш.
$form.Show()
if (-not $form.Registered) {
    Show-Note 'Сочетание Alt+Win+F5 уже занято другой программой. Быстрый запуск по клавишам не работает, но бот всё равно откроется автоматически.'
    if ($AutoStartDelaySec -gt 0) {
        Start-Sleep -Seconds $AutoStartDelaySec
        Start-ClaudeBot $true
    }
    exit
}

# Автозапуск: один раз, через $AutoStartDelaySec секунд.
if ($AutoStartDelaySec -gt 0) {
    $autoTimer = New-Object System.Windows.Forms.Timer
    $autoTimer.Interval = $AutoStartDelaySec * 1000
    $autoTimer.add_Tick({
        $autoTimer.Stop()
        Start-ClaudeBot $true
    })
    $autoTimer.Start()
}

# Сторож: если окно бота закрыли (крестиком, Ctrl+C или оно упало), бот сам
# не всегда успевает написать «🔴 остановлен». Тогда это сообщение отправляет
# эта программа. Плановая очистка памяти (бот возвращается за секунды) — не в счёт.
$StateDir = if ($env:TELEGRAM_STATE_DIR) { $env:TELEGRAM_STATE_DIR } else { Join-Path $env:USERPROFILE '.claude\channels\telegram' }
$script:botSeen = $false
$script:goneSince = $null

function Send-OwnerNotice([string]$text) {
    try {
        $token = (Get-Content (Join-Path $StateDir '.env') -ErrorAction Stop |
            Where-Object { $_ -match '^TELEGRAM_BOT_TOKEN=' } | Select-Object -First 1) -replace '^TELEGRAM_BOT_TOKEN=', ''
        $owners = (Get-Content (Join-Path $StateDir 'access.json') -Raw -Encoding UTF8 | ConvertFrom-Json).allowFrom
        foreach ($id in $owners) {
            $body = @{ chat_id = "$id"; text = $text } | ConvertTo-Json -Compress
            Invoke-RestMethod -Uri "https://api.telegram.org/bot$($token.Trim())/sendMessage" -Method Post `
                -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 15 | Out-Null
        }
    } catch {}
}

$watchTimer = New-Object System.Windows.Forms.Timer
$watchTimer.Interval = 5000
$watchTimer.add_Tick({
    try {
        $running = @(Get-CimInstance Win32_Process -Filter "Name='claude.exe'" |
            Where-Object { $_.CommandLine -match '--channels' }).Count -gt 0
        if ($running) { $script:botSeen = $true; $script:goneSince = $null; return }
        if (-not $script:botSeen) { return }
        if (-not $script:goneSince) { $script:goneSince = Get-Date; return }
        if (((Get-Date) - $script:goneSince).TotalSeconds -lt 20) { return }   # мог быть перезапуск
        $script:botSeen = $false
        $script:goneSince = $null
        if (Test-Path (Join-Path $StateDir 'restart.request')) { return }       # плановая очистка памяти
        $marker = Join-Path $StateDir 'stop-notified'
        if ((Test-Path $marker) -and ((Get-Date) - (Get-Item $marker).LastWriteTime).TotalMinutes -lt 3) { return } # бот успел сам
        Send-OwnerNotice ("🔴 Бот остановлен: окно Claude Code закрыто ({0}).`nСообщения в личных чатах сейчас не обрабатываются.`nAlt+Win+F5 — запустить снова." -f (Get-Date -Format 'dd.MM.yyyy HH:mm'))
    } catch {}
})
$watchTimer.Start()

[System.Windows.Forms.Application]::Run($form)
