<# : batch launcher part - the PowerShell part follows
@echo off
setlocal DisableDelayedExpansion
title Ukrainizator Half-Life 2
set "HL2UA_SELF=%~f0"
set "HL2UA_ARG=%~1"
set "HL2UA_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "HL2UA_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%HL2UA_PS%" set "HL2UA_PS=powershell.exe"
"%HL2UA_PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -Command "$global:HL2UA_ScriptText=[IO.File]::ReadAllText($env:HL2UA_SELF,[Text.Encoding]::UTF8); . ([ScriptBlock]::Create($global:HL2UA_ScriptText))"
set "HL2UA_RC=%ERRORLEVEL%"
if %HL2UA_RC% GEQ 200 pause
exit /b %HL2UA_RC%
#>

# =============================================================================
#  Українізатор Half-Life 2 — встановлює українське озвучення та переклад
#  від HamUA Studio (офіційна папка авторів на Google Drive).
#
#  Один файл = два світи: зверху — cmd-запускач, далі — PowerShell 5.1.
#  UI (WinForms) крутиться в головному потоці, вся робота — у фоновому
#  runspace; спілкуються через синхронізовану хеш-таблицю $HL2UA_State.
# =============================================================================

$global:HL2UA_Config = @{
    Version          = '1.0.0'
    # Офіційна папка HamUA Studio (на неї посилаються їхні сторінки в Steam Workshop).
    DriveFolderId    = '1fIiZz8xwNdMX7tzOpxOGTlilDqkg3pVa'
    # Запасний варіант, якщо список файлів папки колись не вдасться отримати:
    # @{ Part = 'hl2'; Type = 'full'; Id = '<id файлу на Drive>'; Name = 'Half-Life 2 UKR (озвучення+текст).zip' }
    KnownFiles       = @()
    WorkshopItems    = @{ hl2 = '3374817799'; ep1 = '3547695650'; ep2 = '3583786172' }
    SteamAppId       = '220'
    ExtraSteamAppIds = @('380', '420')
    LaunchArgs       = '-language ukr +cc_lang ukr'
    DataDirName      = '_ukrainizator'
    IncludeEpisodes  = $true
    LogFileName      = 'HL2-UA-log.txt'
    # Адреси винесено в конфіг, щоб тести могли підмінити їх локальним сервером.
    EmbedListUrl     = 'https://drive.google.com/embeddedfolderview?id={0}'
    FolderPageUrl    = 'https://drive.google.com/drive/folders/{0}?hl=en'
    DownloadUrl      = 'https://drive.usercontent.google.com/download?id={0}&export=download&confirm=t'
    FileViewUrl      = 'https://drive.google.com/file/d/{0}/view'
    ClockCheckUrl    = 'http://www.google.com/generate_204'
    InternetProbes   = @('drive.google.com:443', 'www.google.com:443')
    ExtraSteamRoots  = @()
    SkipDiskScan     = $false
    AutoCloseMs      = 0
    AutoDialogMs     = 0
}

$global:HL2UA_Errors = @{
    11 = @('Windows не дозволяє запускати скрипти на цьому компʼютері (обмежений режим PowerShell).', 'Тут потрібна допомога сина — це налаштування безпеки Windows.')
    12 = @('Не отримано дозволу адміністратора.', 'Запустіть файл ще раз і у вікні Windows «Дозволити цій програмі вносити зміни?» натисніть «Так».')
    13 = @('Українізатор уже запущено в іншому вікні.', 'Дочекайтеся, поки те вікно завершить роботу.')
    14 = @('На компʼютері бракує потрібних компонентів Windows (.NET Framework 4.5 або новіший).', 'Оновіть Windows через «Центр оновлення Windows» і запустіть файл ще раз.')
    19 = @('Сталася непередбачена помилка.', 'Надішліть синові файл журналу з Робочого столу.')
    21 = @('Гру Half-Life 2 не знайдено на цьому компʼютері.', 'Перевірте, що гра встановлена і запускається, потім запустіть файл ще раз.')
    22 = @('Знайдено іншу гру серії Half-Life, а не Half-Life 2.', 'Цей українізатор підходить лише для Half-Life 2.')
    23 = @('Steam ще не до кінця встановив або оновлює Half-Life 2.', 'Відкрийте Steam, дочекайтеся кінця завантаження гри і запустіть файл ще раз.')
    24 = @('Гра Half-Life 2 запущена, і її не вдалося закрити.', 'Закрийте гру самостійно і запустіть файл ще раз.')
    31 = @('Немає підключення до інтернету.', 'Перевірте інтернет (чи відкриваються сайти) і запустіть файл ще раз.')
    32 = @('На компʼютері неправильна дата або час — через це захищені сайти не відкриваються.', 'Натисніть «Налаштувати час» нижче, увімкніть автоматичний час або натисніть «Синхронізувати», потім запустіть файл ще раз.')
    33 = @('Захищене зʼєднання з Google Drive заблоковане (можливо, антивірусом або налаштуваннями мережі).', 'Спробуйте тимчасово вимкнути антивірус і запустити файл ще раз.')
    34 = @('Не вдалося отримати список файлів українізатора з Google Drive.', 'Можливо, автори перемістили файли. Спробуйте пізніше.')
    35 = @('Google Drive тимчасово обмежив завантаження: цей файл сьогодні качало забагато людей.', 'Спробуйте ще раз через кілька годин або завтра — завантаження продовжиться з місця зупинки.')
    36 = @('Google Drive не дає доступу до файлу українізатора.', 'Можливо, автори замінили або видалили файл. Спробуйте пізніше.')
    37 = @('Завантаження постійно обривається.', 'Перевірте інтернет і запустіть файл ще раз — завантаження продовжиться з місця зупинки.')
    38 = @('Завантажений файл пошкоджений.', 'Запустіть файл ще раз — пошкоджений файл буде завантажено заново.')
    39 = @('Файл українізатора в незнайомому форматі (не ZIP).', 'Автори, мабуть, змінили формат архіву. Тут потрібна допомога сина.')
    41 = @('Недостатньо вільного місця на диску.', 'Звільніть місце на диску (подробиці нижче) і запустіть файл ще раз.')
    42 = @('Немає дозволу записувати файли в папку гри.', 'Запустіть файл ще раз і дозвольте зміни (кнопка «Так»).')
    43 = @('Файл гри зайнятий іншою програмою (можливо, антивірусом або самою грою).', 'Перезавантажте компʼютер і запустіть файл ще раз.')
    44 = @('Антивірус заблокував або видалив файли українізатора.', 'Тут потрібна допомога сина.')
    45 = @('Помилка запису на диск.', 'Перезавантажте компʼютер і запустіть файл ще раз.')
    51 = @('Файли українізатора мають незнайому будову (автори змінили архів).', 'Тут потрібна допомога сина.')
    52 = @('Не вдалося розпакувати українізатор. Усі зміни скасовано — гра залишилася як була.', 'Запустіть файл ще раз.')
    61 = @('Не вдалося закрити Steam, щоб увімкнути українську мову.', 'Закрийте Steam самостійно (правою кнопкою на значку Steam біля годинника → «Вихід») і запустіть файл ще раз.')
    62 = @('Не вдалося змінити налаштування Steam.', 'Тут потрібна допомога сина.')
    91 = @('Встановлення скасовано.', 'Щоб встановити українізатор, просто запустіть файл ще раз.')
}

try { Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop } catch { }
try { Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop } catch { }

$global:HL2UA_UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36'
$global:HL2UA_Cookies = New-Object System.Net.CookieContainer

# ============================================================== utilities ====

function Join-UaPath {
    param([string]$Base)
    $sep = [IO.Path]::DirectorySeparatorChar
    $p = $Base
    foreach ($x in $args) {
        if ([string]::IsNullOrEmpty($x)) { continue }
        $x = ([string]$x).Replace('/', $sep).Replace('\', $sep).TrimStart($sep)
        if ($x -eq '') { continue }
        $p = [IO.Path]::Combine($p, $x)
    }
    return $p
}

function Get-UaProp($Obj, [string]$Name) {
    if ($null -eq $Obj) { return $null }
    if ($Obj -is [System.Collections.IDictionary]) { return $Obj[$Name] }
    $p = $Obj.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    return $null
}

function Format-UaSize {
    param([double]$Bytes)
    $inv = [Globalization.CultureInfo]::InvariantCulture
    if ($Bytes -ge 1GB) { $t = ($Bytes / 1GB).ToString('0.0', $inv) + ' ГБ' }
    elseif ($Bytes -ge 1MB) { $t = ($Bytes / 1MB).ToString('0', $inv) + ' МБ' }
    elseif ($Bytes -ge 1KB) { $t = ($Bytes / 1KB).ToString('0', $inv) + ' КБ' }
    else { $t = ([long]$Bytes).ToString($inv) + ' Б' }
    return $t.Replace('.', ',')
}

function Format-UaDuration {
    param([double]$Seconds)
    if ([double]::IsNaN($Seconds) -or [double]::IsInfinity($Seconds) -or $Seconds -lt 0) { return '' }
    $s = [long][Math]::Ceiling($Seconds)
    if ($s -lt 60) { return ('{0} с' -f $s) }
    if ($s -lt 600) { return ('{0} хв {1} с' -f [long][Math]::Floor($s / 60), ($s % 60)) }
    $m = [long][Math]::Ceiling($s / 60.0)
    if ($m -lt 60) { return ('{0} хв' -f $m) }
    return ('{0} год {1} хв' -f [long][Math]::Floor($m / 60), ($m % 60))
}

function Write-UaLog {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff'), $Level, $Message
    $s = $global:HL2UA_State
    if ($s -and $s.LogPath) {
        for ($i = 0; $i -lt 3; $i++) {
            try { [IO.File]::AppendAllText($s.LogPath, $line + "`r`n", [Text.Encoding]::UTF8); break }
            catch { Start-Sleep -Milliseconds 30 }
        }
    }
    if ($global:HL2UA_EchoLog) { Write-Host $line }
}

function Remove-UaFileQuiet([string]$Path) {
    if (-not $Path) { return }
    try {
        if ([IO.File]::Exists($Path)) {
            Clear-UaReadOnly $Path
            [IO.File]::Delete($Path)
        }
    } catch { Write-UaLog ('Could not delete {0}: {1}' -f $Path, $_.Exception.Message) 'WARN' }
}

function Remove-UaDirQuiet([string]$Path) {
    if (-not $Path) { return }
    try { if ([IO.Directory]::Exists($Path)) { [IO.Directory]::Delete($Path, $true) } }
    catch { Write-UaLog ('Could not delete folder {0}: {1}' -f $Path, $_.Exception.Message) 'WARN' }
}

function Remove-UaEmptyDir([string]$Path) {
    try {
        if ([IO.Directory]::Exists($Path) -and @([IO.Directory]::GetFileSystemEntries($Path)).Count -eq 0) { [IO.Directory]::Delete($Path) }
    } catch { }
}

function Clear-UaReadOnly([string]$Path) {
    try {
        $a = [IO.File]::GetAttributes($Path)
        if ($a -band [IO.FileAttributes]::ReadOnly) { [IO.File]::SetAttributes($Path, ($a -band (-bnot [IO.FileAttributes]::ReadOnly))) }
    } catch { }
}

function Get-UaRegValue([string]$Key, [string]$Name) {
    try {
        $item = Get-ItemProperty -LiteralPath $Key -Name $Name -ErrorAction Stop
        return [string](Get-UaProp $item $Name)
    } catch { return $null }
}

function Get-UaFixedDrives {
    try {
        foreach ($d in [IO.DriveInfo]::GetDrives()) {
            try { if ($d.DriveType -eq [IO.DriveType]::Fixed -and $d.IsReady) { $d.RootDirectory.FullName } } catch { }
        }
    } catch { }
}

function Get-UaFreeSpace([string]$Path) {
    try {
        $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
        if (-not $root -or $root.StartsWith('\\')) { return -1L }
        return [long](New-Object IO.DriveInfo($root)).AvailableFreeSpace
    } catch { return -1L }
}

function Assert-UaFreeSpace([string]$Path, [long]$NeedBytes) {
    $free = Get-UaFreeSpace $Path
    if ($free -lt 0 -or $free -ge $NeedBytes) { return }
    $drive = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path)).TrimEnd('\', '/')
    $extra = 'Диск {0} — треба звільнити ще {1} (зараз вільно {2}, потрібно {3}).' -f $drive, (Format-UaSize ($NeedBytes - $free)), (Format-UaSize $free), (Format-UaSize $NeedBytes)
    throw (New-UaError -Code 41 -Detail $extra -Extra $extra)
}

function Test-UaWritable([string]$Dir) {
    try {
        $probe = Join-UaPath $Dir ('.hl2ua_write_test_' + [guid]::NewGuid().ToString('N'))
        [IO.File]::WriteAllText($probe, 'x')
        [IO.File]::Delete($probe)
        return $true
    } catch { return $false }
}

function Test-UaElevated {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Get-UaDesktop {
    $s = $global:HL2UA_State
    if ($s -and $s.Desktop) { return [string]$s.Desktop }
    try { return [Environment]::GetFolderPath('Desktop') } catch { return $null }
}

function Get-UaDownloadsDir {
    $v = Get-UaRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' '{374DE290-123F-4565-9164-39C4925E467B}'
    if ($v) {
        try { $p = [Environment]::ExpandEnvironmentVariables($v); if ([IO.Directory]::Exists($p)) { return $p } } catch { }
    }
    if ($env:USERPROFILE) {
        $p = Join-UaPath $env:USERPROFILE 'Downloads'
        if ([IO.Directory]::Exists($p)) { return $p }
    }
    return $null
}

function Invoke-UaShellOpen([string]$Target) {
    Write-UaLog ('Opening: ' + $Target)
    $s = $global:HL2UA_State
    if ($s -and $s.Headless) { return }
    try { Start-Process -FilePath $Target | Out-Null } catch { Write-UaLog ('Open failed: ' + $_.Exception.Message) 'WARN' }
}

function Start-UaSleep([double]$Seconds) {
    $end = [DateTime]::UtcNow.AddSeconds($Seconds)
    while ([DateTime]::UtcNow -lt $end) {
        Assert-UaNotCancelled
        Start-Sleep -Milliseconds 200
    }
}

# ================================================================= errors ====

function New-UaError {
    param([int]$Code, [string]$Detail = '', $Inner = $null, [string]$Extra = '')
    $msg = 'HL2UA error ' + $Code
    if ($Detail) { $msg += ': ' + $Detail }
    if ($Inner -is [Exception]) { $ex = New-Object System.Exception -ArgumentList $msg, $Inner }
    else { $ex = New-Object System.Exception -ArgumentList $msg }
    $ex.Data['UaCode'] = $Code
    if ($Extra) { $ex.Data['UaExtra'] = $Extra }
    return $ex
}

function Get-UaErrorInfo($ErrorObject) {
    $cur = $ErrorObject
    if ($cur -is [System.Management.Automation.ErrorRecord]) { $cur = $cur.Exception }
    $depth = 0
    while ($cur -and $depth -lt 10) {
        if ($cur.Data -and $cur.Data.Contains('UaCode')) {
            return @{ Code = [int]$cur.Data['UaCode']; Extra = [string]$cur.Data['UaExtra']; Exception = $cur }
        }
        $cur = $cur.InnerException
        $depth++
    }
    return $null
}

function Find-UaException($Ex, [type]$Type) {
    $cur = $Ex
    if ($cur -is [System.Management.Automation.ErrorRecord]) { $cur = $cur.Exception }
    $depth = 0
    while ($cur -and $depth -lt 10) {
        if ($cur -is $Type) { return $cur }
        $cur = $cur.InnerException
        $depth++
    }
    return $null
}

function Format-UaError($Err) {
    $sb = New-Object System.Text.StringBuilder
    $ex = $Err
    if ($Err -is [System.Management.Automation.ErrorRecord]) { $ex = $Err.Exception }
    $depth = 0
    while ($ex -and $depth -lt 8) {
        [void]$sb.Append(('[{0}] {1} (0x{2:X8}); ' -f $ex.GetType().FullName, $ex.Message, $ex.HResult))
        $ex = $ex.InnerException
        $depth++
    }
    if ($Err -is [System.Management.Automation.ErrorRecord]) {
        if ($Err.ScriptStackTrace) { [void]$sb.Append(' STACK: ' + ($Err.ScriptStackTrace -replace "`r?`n", ' <- ')) }
        if ($Err.InvocationInfo -and $Err.InvocationInfo.PositionMessage) { [void]$sb.Append(' AT: ' + ($Err.InvocationInfo.PositionMessage -replace "`r?`n", ' ')) }
    }
    return $sb.ToString()
}

# Disk-side exception -> coded error (or $null if it is not a disk problem).
function Convert-UaDiskError($Ex, [int]$Default = 0) {
    $info = Get-UaErrorInfo $Ex
    if ($info) { return $info.Exception }
    if (Find-UaException $Ex ([UnauthorizedAccessException])) { return (New-UaError 42 'access denied' $Ex) }
    if (Find-UaException $Ex ([IO.PathTooLongException])) { return (New-UaError 45 'path too long' $Ex -Extra 'Шлях до папки гри задовгий для Windows.') }
    if (Find-UaException $Ex ([IO.InvalidDataException])) { return (New-UaError 38 'corrupt archive data' $Ex) }
    $io = Find-UaException $Ex ([IO.IOException])
    if ($io) {
        $hr = $io.HResult -band 0xFFFF
        if ($hr -in 39, 112) { return (New-UaError 41 'disk full' $Ex) }
        if ($hr -in 32, 33) { return (New-UaError 43 'file in use' $Ex) }
        if ($hr -in 225, 226) { return (New-UaError 44 'blocked by antivirus' $Ex) }
        if ($hr -in 5) { return (New-UaError 42 'access denied' $Ex) }
        if ($Default) { return (New-UaError 45 $io.Message $Ex) }
    }
    if ($Default) { return (New-UaError $Default $Ex.Message $Ex) }
    return $null
}

# =================================================== worker <-> UI bridge ====

function New-UaState {
    return [hashtable]::Synchronized(@{
        Version       = 0
        Steps         = @()
        CurrentKey    = $null
        StepFraction  = 0.0
        Detail        = ''
        Prompt        = $null
        PromptSeq     = 0
        PromptAnswer  = $null
        Cancel        = $false
        Done          = $false
        Result        = $null
        LogPath       = $null
        Desktop       = $null
        ErrorLogCopy  = $null
        ActiveRequest = $null
        Headless      = $false
        AutoAnswers   = $null
    })
}

function Update-UaState {
    $s = $global:HL2UA_State
    if ($s) { $s.Version = [int]$s.Version + 1 }
}

function Initialize-UaSteps([object[]]$Defs) {
    $s = $global:HL2UA_State
    if (-not $s) { return }
    $old = @{}
    foreach ($st in @($s.Steps)) { if ($st) { $old[$st.Key] = $st } }
    $list = @()
    foreach ($d in $Defs) {
        if ($old.ContainsKey($d.Key)) {
            $st = $old[$d.Key]
            $st.Weight = $d.Weight
            $list += $st
        } else {
            $list += @{ Key = $d.Key; Title = $d.Title; Weight = [double]$d.Weight; Status = 'pending' }
        }
    }
    $s.Steps = $list
    Update-UaState
}

function Get-UaStep([string]$Key) {
    $s = $global:HL2UA_State
    if (-not $s) { return $null }
    foreach ($st in @($s.Steps)) { if ($st.Key -eq $Key) { return $st } }
    return $null
}

function Enter-UaStep([string]$Key) {
    $s = $global:HL2UA_State
    $st = Get-UaStep $Key
    if (-not $st) { return }
    $st.Status = 'running'
    $s.CurrentKey = $Key
    $s.StepFraction = 0.0
    $s.Detail = ''
    Write-UaLog ('--- STEP: ' + $st.Title)
    Update-UaState
}

function Complete-UaStep([string]$Key, [string]$Status = 'done') {
    $st = Get-UaStep $Key
    if (-not $st) { return }
    $st.Status = $Status
    Update-UaState
}

function Set-UaProgress {
    param([double]$Fraction = -1, [string]$Detail = $null)
    $s = $global:HL2UA_State
    if (-not $s) { return }
    if ($Fraction -ge 0) { $s.StepFraction = [Math]::Min(1.0, $Fraction) }
    if ($null -ne $Detail) { $s.Detail = $Detail }
    Update-UaState
}

function Get-UaOverallPercent($s) {
    $total = 0.0
    $done = 0.0
    foreach ($st in @($s.Steps)) {
        $w = [double]$st.Weight
        $total += $w
        if ($st.Status -in 'done', 'warn', 'skip') { $done += $w }
        elseif ($st.Status -eq 'running') { $done += $w * [double]$s.StepFraction }
    }
    if ($total -le 0) { return 0 }
    return [int][Math]::Floor(100.0 * $done / $total)
}

function Assert-UaNotCancelled {
    $s = $global:HL2UA_State
    if ($s -and $s.Cancel) { throw (New-UaError 91 'cancelled by user') }
}

# Shows a dialog on the UI thread and waits for the answer. Returns the index
# of the pressed button, or -1 if the dialog was closed with the X.
function Request-UaChoice {
    param([string]$Text, [string[]]$Buttons = @('OK'), [string]$Title = 'Українізатор Half-Life 2')
    $s = $global:HL2UA_State
    if (-not $s -or $s.Headless) {
        $ans = 0
        if ($s -and $s.AutoAnswers -and $s.AutoAnswers.Count -gt 0) { $ans = [int]$s.AutoAnswers.Dequeue() }
        Write-UaLog ('PROMPT (auto -> {0}): {1}' -f $ans, ($Text -replace "`r?`n", ' | '))
        return $ans
    }
    $id = [int]$s.PromptSeq + 1
    $s.PromptSeq = $id
    $s.PromptAnswer = $null
    $s.Prompt = @{ Id = $id; Text = $Text; Buttons = $Buttons; Title = $Title }
    Update-UaState
    Write-UaLog ('PROMPT: ' + ($Text -replace "`r?`n", ' | '))
    while ($true) {
        $a = $s.PromptAnswer
        if ($null -ne $a -and $a.Id -eq $id) {
            $s.Prompt = $null
            Write-UaLog ('ANSWER: ' + $a.Index)
            return [int]$a.Index
        }
        if ($s.Cancel) { throw (New-UaError 91 'cancelled while waiting for answer') }
        Start-Sleep -Milliseconds 150
    }
}

# ==================================================================== VDF ====
# Мінімальний парсер KeyValues (формат конфігів Steam), що запамʼятовує
# позиції токенів — щоб правити файл точково, не переписуючи його цілком.

function ConvertFrom-UaVdfEscaped([string]$s) {
    if ($s.IndexOf([char]92) -lt 0) { return $s }
    return [regex]::Replace($s, '\\(.)', {
            param($m)
            switch -CaseSensitive ($m.Groups[1].Value) {
                'n' { "`n" }
                't' { "`t" }
                'r' { "`r" }
                default { $m.Groups[1].Value }
            }
        })
}

function ConvertTo-UaVdfEscaped([string]$s) {
    return $s.Replace('\', '\\').Replace('"', '\"')
}

function ConvertFrom-UaVdf([string]$Text) {
    $rx = [regex]'"((?:[^"\\]|\\[\s\S])*)"|(\{)|(\})|(//[^\n]*)|([^\s{}"]+)'
    $root = @{ Key = ''; IsBlock = $true; Depth = -1; OpenEnd = 0; Children = (New-Object System.Collections.Generic.List[object]) }
    $stack = New-Object System.Collections.Stack
    $cur = $root
    $pending = $null
    foreach ($m in $rx.Matches($Text)) {
        if ($m.Groups[4].Success) { continue }
        if ($m.Groups[2].Success) {
            if (-not $pending) { throw 'VDF: unexpected {' }
            $node = @{ Key = $pending.Value; KeyStart = $pending.Start; IsBlock = $true; Depth = $cur.Depth + 1; OpenEnd = $m.Index + 1; Children = (New-Object System.Collections.Generic.List[object]) }
            $cur.Children.Add($node)
            $stack.Push($cur)
            $cur = $node
            $pending = $null
            continue
        }
        if ($m.Groups[3].Success) {
            if ($pending -or $stack.Count -eq 0) { throw 'VDF: unexpected }' }
            $cur = $stack.Pop()
            continue
        }
        if ($m.Groups[1].Success) {
            $val = ConvertFrom-UaVdfEscaped $m.Groups[1].Value
        } else {
            $val = $m.Groups[5].Value
            if ($val.StartsWith('[') -and $val.EndsWith(']')) { continue }
        }
        if ($pending) {
            $cur.Children.Add(@{ Key = $pending.Value; KeyStart = $pending.Start; IsBlock = $false; Depth = $cur.Depth + 1; Value = $val; ValueStart = $m.Index; ValueEnd = $m.Index + $m.Length })
            $pending = $null
        } else {
            $pending = @{ Value = $val; Start = $m.Index }
        }
    }
    if ($pending -or $stack.Count -ne 0) { throw 'VDF: unexpected end of file' }
    return $root
}

function Get-UaVdfChild($Node, [string]$Key) {
    if ($null -eq $Node -or -not $Node.IsBlock) { return $null }
    foreach ($c in $Node.Children) { if ($c.Key -ieq $Key) { return $c } }
    return $null
}

function Get-UaVdfValue($Node, [string]$Key) {
    $c = Get-UaVdfChild $Node $Key
    if ($c -and -not $c.IsBlock) { return $c.Value }
    return $null
}

# Змінює LaunchOptions гри AppId у тексті localconfig.vdf. $Transform отримує
# старе значення і повертає нове. Решта файлу лишається байт-у-байт.
function Set-UaVdfAppLaunchOptions {
    param([string]$Text, [string]$AppId, [scriptblock]$Transform, [switch]$CreateIfMissing, [switch]$RemoveIfEmpty)
    $root = ConvertFrom-UaVdf $Text
    $store = Get-UaVdfChild $root 'UserLocalConfigStore'
    if (-not $store -or -not $store.IsBlock) { throw 'localconfig.vdf: UserLocalConfigStore not found' }
    $nl = "`n"
    if ($Text.Contains("`r`n")) { $nl = "`r`n" }
    $path = @('Software', 'Valve', 'Steam', 'apps', $AppId)
    $node = $store
    $i = 0
    while ($i -lt $path.Count) {
        $child = Get-UaVdfChild $node $path[$i]
        if (-not $child -or -not $child.IsBlock) { break }
        $node = $child
        $i++
    }
    if ($i -lt $path.Count) {
        if (-not $CreateIfMissing) { return @{ Text = $Text; Changed = $false; Before = $null; After = $null } }
        $new = [string](& $Transform '')
        if (-not $new) { return @{ Text = $Text; Changed = $false; Before = ''; After = '' } }
        $d = $node.Depth + 1
        $sb = New-Object System.Text.StringBuilder
        for ($j = $i; $j -lt $path.Count; $j++) {
            $ind = "`t" * ($d + $j - $i)
            [void]$sb.Append($nl + $ind + '"' + $path[$j] + '"' + $nl + $ind + '{')
        }
        $ind = "`t" * ($d + $path.Count - $i)
        [void]$sb.Append($nl + $ind + '"LaunchOptions"' + "`t`t" + '"' + (ConvertTo-UaVdfEscaped $new) + '"')
        for ($j = $path.Count - 1; $j -ge $i; $j--) {
            $ind = "`t" * ($d + $j - $i)
            [void]$sb.Append($nl + $ind + '}')
        }
        return @{ Text = $Text.Insert($node.OpenEnd, $sb.ToString()); Changed = $true; Before = ''; After = $new }
    }
    $lo = Get-UaVdfChild $node 'LaunchOptions'
    if ($lo -and -not $lo.IsBlock) {
        $old = [string]$lo.Value
        $new = [string](& $Transform $old)
        if ($new -ceq $old) { return @{ Text = $Text; Changed = $false; Before = $old; After = $old } }
        if ($new -eq '' -and $RemoveIfEmpty) {
            # Прибираємо рядок цілком — так само, як ми його колись вставили.
            $cut = $Text.LastIndexOf("`n", $lo.KeyStart)
            if ($cut -gt 0 -and $Text[$cut - 1] -eq "`r") { $cut-- }
            if ($cut -ge 0) { return @{ Text = ($Text.Substring(0, $cut) + $Text.Substring($lo.ValueEnd)); Changed = $true; Before = $old; After = '' } }
        }
        $out = $Text.Substring(0, $lo.ValueStart) + '"' + (ConvertTo-UaVdfEscaped $new) + '"' + $Text.Substring($lo.ValueEnd)
        return @{ Text = $out; Changed = $true; Before = $old; After = $new }
    }
    $new = [string](& $Transform '')
    if (-not $new) { return @{ Text = $Text; Changed = $false; Before = ''; After = '' } }
    $ind = "`t" * ($node.Depth + 1)
    $ins = $nl + $ind + '"LaunchOptions"' + "`t`t" + '"' + (ConvertTo-UaVdfEscaped $new) + '"'
    return @{ Text = $Text.Insert($node.OpenEnd, $ins); Changed = $true; Before = ''; After = $new }
}

function Remove-UaLaunchArgs([string]$Existing) {
    if (-not $Existing) { return '' }
    $s = ' ' + $Existing + ' '
    $s = [regex]::Replace($s, '(?i)(?<=\s)-language\s+("[^"]*"|\S+)(?=\s)', ' ')
    $s = [regex]::Replace($s, '(?i)(?<=\s)\+cc_lang\s+("[^"]*"|\S+)(?=\s)', ' ')
    return ([regex]::Replace($s, '\s{2,}', ' ')).Trim()
}

function Add-UaLaunchArgs([string]$Existing) {
    $ours = $global:HL2UA_Config.LaunchArgs
    $s = Remove-UaLaunchArgs $Existing
    if ($s -match '%command%') {
        $rx = New-Object System.Text.RegularExpressions.Regex('%command%')
        return $rx.Replace($s, '%command% ' + $ours, 1).Trim()
    }
    if ($s) { return ($s + ' ' + $ours) }
    return $ours
}

# ========================================================== game discovery ====

function Add-UaUniqueDir($List, [string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $sep = [IO.Path]::DirectorySeparatorChar
    try {
        $p = $Path.Trim().Trim('"').Replace('/', $sep).Replace('\', $sep)
        $p = [IO.Path]::GetFullPath($p)
        if ($p.Length -gt 3) { $p = $p.TrimEnd($sep) }
    } catch { return }
    if (-not [IO.Directory]::Exists($p)) { return }
    foreach ($x in $List) { if ($x -ieq $p) { return } }
    $List.Add($p)
}

function Test-UaHl2Dir([string]$Dir) {
    if (-not $Dir) { return $false }
    try {
        if (-not [IO.File]::Exists((Join-UaPath $Dir 'hl2' 'gameinfo.txt'))) { return $false }
        foreach ($exe in @('hl2.exe', 'hl2_win64.exe', 'hl2.sh', 'hl2_linux')) {
            if ([IO.File]::Exists((Join-UaPath $Dir $exe))) { return $true }
        }
        return [IO.Directory]::Exists((Join-UaPath $Dir 'bin'))
    } catch { return $false }
}

function Get-UaGameExe([string]$Dir) {
    foreach ($exe in @('hl2.exe', 'hl2_win64.exe')) {
        $p = Join-UaPath $Dir $exe
        if ([IO.File]::Exists($p)) { return $p }
    }
    return $null
}

function Get-UaGameParts([string]$GameDir) {
    'hl2'
    if ([IO.File]::Exists((Join-UaPath $GameDir 'episodic' 'gameinfo.txt'))) { 'ep1' }
    if ([IO.File]::Exists((Join-UaPath $GameDir 'ep2' 'gameinfo.txt'))) { 'ep2' }
}

function Get-UaPartName([string]$Part) {
    switch ($Part) {
        'hl2' { return 'Half-Life 2' }
        'ep1' { return 'Епізод 1' }
        'ep2' { return 'Епізод 2' }
    }
    return $Part
}

function Get-UaSteamRoots {
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($p in @($global:HL2UA_Config.ExtraSteamRoots)) { Add-UaUniqueDir $list $p }
    Add-UaUniqueDir $list (Get-UaRegValue 'HKCU:\Software\Valve\Steam' 'SteamPath')
    Add-UaUniqueDir $list (Get-UaRegValue 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' 'InstallPath')
    Add-UaUniqueDir $list (Get-UaRegValue 'HKLM:\SOFTWARE\Valve\Steam' 'InstallPath')
    try {
        foreach ($sp in @(Get-Process -Name 'steam' -ErrorAction SilentlyContinue)) {
            try { if ($sp.Path) { Add-UaUniqueDir $list ([IO.Path]::GetDirectoryName($sp.Path)) } } catch { }
        }
    } catch { }
    foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramW6432, $env:ProgramFiles)) {
        if ($base) { Add-UaUniqueDir $list (Join-UaPath $base 'Steam') }
    }
    foreach ($d in @(Get-UaFixedDrives)) {
        Add-UaUniqueDir $list (Join-UaPath $d 'Steam')
        Add-UaUniqueDir $list (Join-UaPath $d 'Program Files (x86)' 'Steam')
        Add-UaUniqueDir $list (Join-UaPath $d 'Games' 'Steam')
    }
    foreach ($p in $list) { if ([IO.Directory]::Exists((Join-UaPath $p 'steamapps'))) { $p } }
}

function Get-UaSteamLibraries([string]$SteamRoot) {
    $list = New-Object System.Collections.Generic.List[string]
    Add-UaUniqueDir $list $SteamRoot
    foreach ($f in @((Join-UaPath $SteamRoot 'steamapps' 'libraryfolders.vdf'), (Join-UaPath $SteamRoot 'config' 'libraryfolders.vdf'))) {
        if (-not [IO.File]::Exists($f)) { continue }
        try {
            $root = ConvertFrom-UaVdf ([IO.File]::ReadAllText($f, [Text.Encoding]::UTF8))
            $lf = Get-UaVdfChild $root 'libraryfolders'
            if (-not $lf) { continue }
            foreach ($c in $lf.Children) {
                if ($c.IsBlock) { Add-UaUniqueDir $list (Get-UaVdfValue $c 'path') }
                elseif ($c.Key -match '^\d+$') { Add-UaUniqueDir $list $c.Value }
            }
        } catch { Write-UaLog ('libraryfolders.vdf parse failed ({0}): {1}' -f $f, $_.Exception.Message) 'WARN' }
    }
    foreach ($x in $list) { $x }
}

function Read-UaAppManifest([string]$Path) {
    try {
        $root = ConvertFrom-UaVdf ([IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8))
        $st = Get-UaVdfChild $root 'AppState'
        if (-not $st) { return $null }
        $r = @{ Name = Get-UaVdfValue $st 'name'; InstallDir = Get-UaVdfValue $st 'installdir' }
        foreach ($k in @('StateFlags', 'buildid', 'BytesToDownload', 'BytesDownloaded', 'SizeOnDisk')) {
            $v = 0L
            [void][long]::TryParse([string](Get-UaVdfValue $st $k), [ref]$v)
            $r[$k] = $v
        }
        return $r
    } catch { return $null }
}

function Get-UaSteamGameCandidates {
    foreach ($root in @(Get-UaSteamRoots)) {
        foreach ($lib in @(Get-UaSteamLibraries $root)) {
            $apps = Join-UaPath $lib 'steamapps'
            foreach ($appId in @('220', '380', '420', '340')) {
                $acf = Join-UaPath $apps ('appmanifest_' + $appId + '.acf')
                if (-not [IO.File]::Exists($acf)) { continue }
                $m = Read-UaAppManifest $acf
                if (-not $m) { continue }
                $dirName = $m.InstallDir
                if (-not $dirName) { $dirName = 'Half-Life 2' }
                $dir = Join-UaPath $apps 'common' $dirName
                if (Test-UaHl2Dir $dir) {
                    @{ Dir = $dir; Kind = 'steam'; SteamRoot = $root; Library = $lib; AppId = $appId; Manifest = $acf }
                } elseif ($appId -eq '220') {
                    Write-UaLog ('appmanifest_220 found but game folder is incomplete: {0} (StateFlags={1})' -f $dir, $m.StateFlags) 'WARN'
                    $global:HL2UA_BrokenSteamInstall = $acf
                }
            }
            $dir = Join-UaPath $apps 'common' 'Half-Life 2'
            if (Test-UaHl2Dir $dir) { @{ Dir = $dir; Kind = 'steam'; SteamRoot = $root; Library = $lib; AppId = '220'; Manifest = $null } }
        }
    }
}

function Select-UaUniqueCandidates($Cands) {
    $seen = @{}
    foreach ($c in @($Cands)) {
        if (-not $c) { continue }
        $k = ([string]$c.Dir).ToLowerInvariant()
        if (-not $seen.ContainsKey($k)) { $seen[$k] = $true; $c }
    }
}

function Find-UaOtherHalfLife {
    $known = [ordered]@{ '70' = 'Half-Life'; '280' = 'Half-Life: Source'; '50' = 'Half-Life: Opposing Force'; '130' = 'Half-Life: Blue Shift'; '362890' = 'Black Mesa'; '546560' = 'Half-Life: Alyx' }
    foreach ($root in @(Get-UaSteamRoots)) {
        foreach ($lib in @(Get-UaSteamLibraries $root)) {
            foreach ($id in $known.Keys) {
                if ([IO.File]::Exists((Join-UaPath $lib 'steamapps' ('appmanifest_' + $id + '.acf')))) { return $known[$id] }
            }
        }
    }
    return $null
}

function Get-UaShortcutTargets {
    $shell = $null
    try { $shell = New-Object -ComObject WScript.Shell } catch { return }
    $dirs = @()
    foreach ($sf in @('Desktop', 'CommonDesktopDirectory', 'StartMenu', 'CommonStartMenu')) {
        try { $p = [Environment]::GetFolderPath($sf); if ($p -and [IO.Directory]::Exists($p)) { $dirs += $p } } catch { }
    }
    foreach ($d in $dirs) {
        $files = @()
        try { $files = @(Get-ChildItem -LiteralPath $d -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue) } catch { }
        foreach ($f in $files) {
            try {
                $sc = $shell.CreateShortcut($f.FullName)
                @{ Path = $f.FullName; Target = [string]$sc.TargetPath; Arguments = [string]$sc.Arguments }
            } catch { }
        }
    }
}

function Get-UaNonSteamCandidates {
    $dirs = New-Object System.Collections.Generic.List[string]
    foreach ($k in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall')) {
        $subs = @()
        try { $subs = @(Get-ChildItem -LiteralPath $k -ErrorAction Stop) } catch { continue }
        foreach ($sub in $subs) {
            try {
                $p = Get-ItemProperty -LiteralPath $sub.PSPath -ErrorAction Stop
                if ([string](Get-UaProp $p 'DisplayName') -notmatch '(?i)half[\s-]*life\s*2') { continue }
                Add-UaUniqueDir $dirs ([string](Get-UaProp $p 'InstallLocation'))
                foreach ($v in @([string](Get-UaProp $p 'DisplayIcon'), [string](Get-UaProp $p 'UninstallString'))) {
                    if (-not $v) { continue }
                    $f = ($v -replace '^\s*"([^"]+)".*$', '$1') -replace ',\s*-?\d+\s*$', ''
                    try { Add-UaUniqueDir $dirs ([IO.Path]::GetDirectoryName($f)) } catch { }
                }
            } catch { }
        }
    }
    foreach ($t in @(Get-UaShortcutTargets)) {
        if ($t.Target -match '(?i)[\\/]hl2(_win64)?\.exe$') { Add-UaUniqueDir $dirs ([IO.Path]::GetDirectoryName($t.Target)) }
    }
    foreach ($d in @(Get-UaFixedDrives)) {
        foreach ($base in @($d, (Join-UaPath $d 'Games'), (Join-UaPath $d 'Ігри'), (Join-UaPath $d 'Игры'), (Join-UaPath $d 'Program Files (x86)'), (Join-UaPath $d 'Program Files'))) {
            try {
                foreach ($sub in [IO.Directory]::GetDirectories($base)) {
                    if ([IO.Path]::GetFileName($sub) -match '(?i)half[\s._-]*life[\s._-]*2|^hl2|халф') { Add-UaUniqueDir $dirs $sub }
                }
            } catch { }
        }
    }
    foreach ($x in $dirs) {
        if (Test-UaHl2Dir $x) { @{ Dir = $x; Kind = 'other' }; continue }
        try { foreach ($sub in [IO.Directory]::GetDirectories($x)) { if (Test-UaHl2Dir $sub) { @{ Dir = $sub; Kind = 'other' } } } } catch { }
    }
}

# Остання надія: обхід дисків у ширину (до 5 рівнів, не довше 3 хвилин).
function Search-UaDisksForHl2 {
    if ($global:HL2UA_Config.SkipDiskScan) { return }
    $skip = @('windows', '$recycle.bin', 'system volume information', 'programdata', 'recovery', 'perflogs', 'appdata', 'config.msi', 'msocache', 'windowsapps', 'winsxs', '$windows.~bt', '$windows.~ws', 'onedrivetemp', 'node_modules', '.git')
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $lastUi = 0L
    foreach ($drive in @(Get-UaFixedDrives)) {
        $queue = New-Object System.Collections.Queue
        $queue.Enqueue(@($drive, 0))
        while ($queue.Count -gt 0) {
            if ($sw.Elapsed.TotalSeconds -gt 180) { Write-UaLog 'Disk scan time budget exhausted' 'WARN'; return }
            $item = $queue.Dequeue()
            $dir = [string]$item[0]
            $depth = [int]$item[1]
            if ($sw.ElapsedMilliseconds - $lastUi -gt 400) {
                $lastUi = $sw.ElapsedMilliseconds
                Assert-UaNotCancelled
                Set-UaProgress -Detail ('Шукаю гру на дисках: ' + $dir)
            }
            if ([IO.File]::Exists((Join-UaPath $dir 'hl2.exe')) -and (Test-UaHl2Dir $dir)) { @{ Dir = $dir; Kind = 'other' }; continue }
            if ($depth -ge 5) { continue }
            $subs = @()
            try { $subs = [IO.Directory]::GetDirectories($dir) } catch { continue }
            foreach ($sub in $subs) {
                $name = [IO.Path]::GetFileName($sub).ToLowerInvariant()
                if ($skip -contains $name) { continue }
                try { if (([IO.File]::GetAttributes($sub) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue } } catch { continue }
                $queue.Enqueue(@($sub, ($depth + 1)))
            }
        }
    }
}

function Find-UaGame {
    Set-UaProgress -Detail 'Шукаю Steam і бібліотеки ігор...'
    $global:HL2UA_BrokenSteamInstall = $null
    $cands = @(Select-UaUniqueCandidates @(Get-UaSteamGameCandidates))
    foreach ($c in $cands) { Write-UaLog ('Candidate (steam): {0} [app {1}]' -f $c.Dir, $c.AppId) }
    if ($cands.Count -gt 0) {
        $best = $cands | Sort-Object @{ Expression = { if ($_.AppId -eq '220' -and $_.Manifest) { 0 } elseif ($_.Manifest) { 1 } else { 2 } } } | Select-Object -First 1
        return $best
    }
    if ($global:HL2UA_BrokenSteamInstall) { throw (New-UaError 23 ('game folder incomplete, manifest ' + $global:HL2UA_BrokenSteamInstall)) }
    Set-UaProgress -Detail 'У Steam гру не знайдено. Шукаю в інших місцях...'
    $cands = @(Select-UaUniqueCandidates @(Get-UaNonSteamCandidates))
    if ($cands.Count -eq 0) { $cands = @(Select-UaUniqueCandidates @(Search-UaDisksForHl2)) }
    foreach ($c in $cands) { Write-UaLog ('Candidate (other): ' + $c.Dir) }
    if ($cands.Count -eq 1) { return $cands[0] }
    if ($cands.Count -gt 1) {
        foreach ($c in $cands) {
            $idx = Request-UaChoice -Text ("Знайдено Half-Life 2 у папці:`n`n{0}`n`nВстановити українізатор сюди?" -f $c.Dir) -Buttons @('Так, сюди', 'Ні, це не та')
            if ($idx -eq 0) { return $c }
        }
        throw (New-UaError 21 'user rejected all candidates')
    }
    $other = Find-UaOtherHalfLife
    if ($other) { throw (New-UaError -Code 22 -Detail $other -Extra ('Знайдено: ' + $other + '.')) }
    if (@(Get-UaSteamRoots).Count -gt 0) {
        $idx = Request-UaChoice -Text "Steam на компʼютері є, але гри Half-Life 2 у ньому не знайдено.`n`nВідкрити Steam, щоб встановити гру? Після встановлення запустіть цей файл ще раз." -Buttons @('Відкрити Steam', 'Ні')
        if ($idx -eq 0) { Invoke-UaShellOpen ('steam://install/' + $global:HL2UA_Config.SteamAppId) }
    }
    throw (New-UaError 21 'no candidates')
}

function Wait-UaSteamAppReady($Game) {
    if (-not $Game.Manifest) { return }
    $busyMask = 256 -bor 1024 -bor 131072 -bor 1048576 -bor 2097152 -bor 4194304
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        $m = Read-UaAppManifest $Game.Manifest
        if (-not $m) { return }
        $flags = [long]$m.StateFlags
        $installed = ($flags -band 4) -ne 0
        $busy = ($flags -band $busyMask) -ne 0
        if ($installed -and -not $busy) { return }
        $steamRunning = @(Get-Process -Name 'steam' -ErrorAction SilentlyContinue).Count -gt 0
        if (-not $steamRunning -or $sw.Elapsed.TotalMinutes -gt 30) {
            Write-UaLog ('Steam app state: StateFlags={0}, steam running={1}' -f $flags, $steamRunning) 'WARN'
            if ($installed) { return }
            throw (New-UaError 23 ('StateFlags=' + $flags))
        }
        $txt = 'Steam зараз оновлює Half-Life 2 — чекаю, поки закінчить'
        if ($m.BytesToDownload -gt 0) { $txt += (' ({0} з {1})' -f (Format-UaSize $m.BytesDownloaded), (Format-UaSize $m.BytesToDownload)) }
        Set-UaProgress -Detail ($txt + '...')
        Start-UaSleep 5
    }
}

# ============================================================== processes ====

function Get-UaGameProcesses([string]$GameDir) {
    $prefix = $GameDir.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    foreach ($p in @(Get-Process -ErrorAction SilentlyContinue)) {
        $hit = $p.ProcessName -in 'hl2', 'hl2_win64'
        if (-not $hit) {
            try {
                $path = $p.Path
                if ($path -and $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { $hit = $true }
            } catch { }
        }
        if ($hit) { $p }
    }
}

function Close-UaRunningGame($ctx) {
    $procs = @(Get-UaGameProcesses $ctx.GameDir)
    if ($procs.Count -eq 0) { return }
    Write-UaLog ('Game processes running: ' + (($procs | ForEach-Object { $_.ProcessName + ':' + $_.Id }) -join ', '))
    $idx = Request-UaChoice -Title 'Гра запущена' -Text "Гра Half-Life 2 зараз запущена.`nЩоб встановити українізатор, її треба закрити.`n`nЗакрити гру автоматично? Незбережений прогрес від останньої контрольної точки буде втрачено." -Buttons @('Закрити гру', 'Я закрию сам', 'Скасувати')
    if ($idx -ne 0 -and $idx -ne 1) { throw (New-UaError 91 'user declined closing the game') }
    if ($idx -eq 0) { foreach ($p in $procs) { try { [void]$p.CloseMainWindow() } catch { } } }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (@(Get-UaGameProcesses $ctx.GameDir).Count -gt 0) {
        Assert-UaNotCancelled
        if ($idx -eq 0 -and $sw.Elapsed.TotalSeconds -gt 6) {
            foreach ($p in @(Get-UaGameProcesses $ctx.GameDir)) { try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch { } }
        }
        if ($sw.Elapsed.TotalSeconds -gt 300) { throw (New-UaError 24 'game still running') }
        Set-UaProgress -Detail 'Чекаю, поки гра закриється...'
        Start-Sleep -Milliseconds 700
    }
    Start-Sleep -Seconds 1
}

function Get-UaSteamProcesses { @(Get-Process -Name 'steam' -ErrorAction SilentlyContinue) }

# Повертає $true, якщо Steam був запущений (і його треба буде запустити знову).
function Stop-UaSteam([string]$SteamRoot) {
    $procs = @(Get-UaSteamProcesses)
    if ($procs.Count -eq 0) { return $false }
    $exe = $null
    try { $exe = $procs[0].Path } catch { }
    if (-not $exe) { $exe = Join-UaPath $SteamRoot 'steam.exe' }
    Write-UaLog ('Steam is running ({0}); asking it to shut down' -f $exe)
    Set-UaProgress -Detail 'Закриваю Steam, щоб увімкнути українську мову (потім запущу знову)...'
    try { Start-Process -FilePath $exe -ArgumentList '-shutdown' | Out-Null } catch { Write-UaLog ('steam -shutdown failed: ' + $_.Exception.Message) 'WARN' }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (@(Get-UaSteamProcesses).Count -gt 0) {
        Assert-UaNotCancelled
        if ($sw.Elapsed.TotalSeconds -gt 45) {
            Write-UaLog 'Steam did not exit in time; killing' 'WARN'
            foreach ($p in @(Get-UaSteamProcesses)) { try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch { } }
        }
        if ($sw.Elapsed.TotalSeconds -gt 75) { throw (New-UaError 61 'steam still running') }
        Start-Sleep -Milliseconds 700
    }
    # Steam записує localconfig.vdf під час виходу — даємо йому дописати.
    Start-Sleep -Seconds 3
    $global:HL2UA_SteamExe = $exe
    return $true
}

function Start-UaSteam([string]$SteamRoot) {
    $exe = $global:HL2UA_SteamExe
    if (-not $exe) { $exe = Join-UaPath $SteamRoot 'steam.exe' }
    if (-not [IO.File]::Exists($exe)) { return }
    Set-UaProgress -Detail 'Запускаю Steam знову...'
    Write-UaLog ('Starting Steam: ' + $exe)
    try {
        if (Test-UaElevated) {
            # Через explorer Steam стартує зі звичайними правами, а не адміністраторськими.
            Start-Process -FilePath (Join-UaPath $env:WINDIR 'explorer.exe') -ArgumentList ('"' + $exe + '"') | Out-Null
        } else {
            Start-Process -FilePath $exe | Out-Null
        }
    } catch {
        Write-UaLog ('Could not start Steam: ' + $_.Exception.Message) 'WARN'
        $global:HL2UA_Ctx.Warnings.Add('Steam не вдалося запустити автоматично — запустіть його самостійно.')
    }
}

# =============================================================== network ====

function Enable-UaNetDefaults {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 }
    catch { Write-UaLog ('TLS 1.2 setup failed: ' + $_.Exception.Message) 'WARN' }
    try { [Net.ServicePointManager]::DefaultConnectionLimit = 16; [Net.ServicePointManager]::Expect100Continue = $false } catch { }
    try {
        $proxy = [Net.WebRequest]::DefaultWebProxy
        if ($proxy) { $proxy.Credentials = [Net.CredentialCache]::DefaultNetworkCredentials }
    } catch { }
}

function New-UaRequest {
    param([string]$Url, [long]$From = 0, [switch]$Html, [string]$Method = 'GET', [int]$TimeoutMs = 30000)
    $req = [System.Net.HttpWebRequest]([System.Net.WebRequest]::Create($Url))
    $req.Method = $Method
    $req.UserAgent = $global:HL2UA_UserAgent
    $req.AllowAutoRedirect = $true
    $req.MaximumAutomaticRedirections = 10
    $req.CookieContainer = $global:HL2UA_Cookies
    $req.Timeout = $TimeoutMs
    $req.ReadWriteTimeout = 60000
    try { $req.Headers.Add('Accept-Language', 'en-US,en;q=0.9') } catch { }
    if ($Html) {
        $req.Accept = 'text/html,application/xhtml+xml,*/*;q=0.8'
        $req.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
    } else {
        $req.Accept = '*/*'
    }
    if ($From -gt 0) { $req.AddRange($From) }
    $s = $global:HL2UA_State
    if ($s) { $s.ActiveRequest = $req }
    return $req
}

# Повертає відповідь навіть для 4xx/5xx, щоб викликач сам розібрав статус.
function Get-UaResponse($Req) {
    try { return $Req.GetResponse() }
    catch {
        $we = Find-UaException $_.Exception ([Net.WebException])
        if ($we -and $we.Response) { return $we.Response }
        throw
    }
}

function Read-UaBody($Resp, [int]$MaxChars = 4000000) {
    $sr = New-Object IO.StreamReader($Resp.GetResponseStream(), [Text.Encoding]::UTF8)
    try {
        $buf = New-Object char[] 65536
        $sb = New-Object System.Text.StringBuilder
        while ($sb.Length -lt $MaxChars) {
            $n = $sr.Read($buf, 0, $buf.Length)
            if ($n -le 0) { break }
            [void]$sb.Append($buf, 0, $n)
        }
        return $sb.ToString()
    } finally { $sr.Dispose() }
}

function Test-UaTransient($Ex) {
    if (Get-UaErrorInfo $Ex) { return $false }
    $we = Find-UaException $Ex ([Net.WebException])
    if ($we) {
        $st = $we.Status.ToString()
        if ($st -in 'TrustFailure', 'SecureChannelFailure', 'RequestCanceled') { return $false }
        if ($st -eq 'ProtocolError') {
            $code = 0
            try { $code = [int]$we.Response.StatusCode } catch { }
            return ($code -in 408, 429, 500, 502, 503, 504)
        }
        return $true
    }
    $io = Find-UaException $Ex ([IO.IOException])
    if ($io) { return -not (($io.HResult -band 0xFFFF) -in 5, 32, 33, 39, 112, 225, 226) }
    if (Find-UaException $Ex ([Net.Sockets.SocketException])) { return $true }
    if (Find-UaException $Ex ([TimeoutException])) { return $true }
    # System.Net.Http у Windows PowerShell 5.1 може бути не завантажений — тип перевіряємо обережно.
    $httpEx = 'System.Net.Http.HttpRequestException' -as [type]
    if ($httpEx -and (Find-UaException $Ex $httpEx)) { return $true }
    return $false
}

function Test-UaInternet {
    foreach ($probe in @($global:HL2UA_Config.InternetProbes)) {
        $h = ([string]$probe).Split(':')[0]
        $port = [int]([string]$probe).Split(':')[1]
        $c = New-Object Net.Sockets.TcpClient
        try {
            $iar = $c.BeginConnect($h, $port, $null, $null)
            if ($iar.AsyncWaitHandle.WaitOne(6000) -and $c.Connected) { return $true }
        } catch { } finally { try { $c.Close() } catch { } }
    }
    # Можливо, інтернет іде через проксі — пробуємо звичайний HTTP-запит.
    try {
        $resp = Get-UaResponse (New-UaRequest -Url $global:HL2UA_Config.ClockCheckUrl -Method 'HEAD' -TimeoutMs 8000)
        $resp.Close()
        return $true
    } catch { return $false }
}

function Wait-UaInternet([int]$MaxSeconds = 300) {
    Set-UaProgress -Detail 'Перевіряю підключення до інтернету...'
    if (Test-UaInternet) { return }
    Write-UaLog 'No internet; waiting' 'WARN'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $MaxSeconds) {
        $left = Format-UaDuration ($MaxSeconds - $sw.Elapsed.TotalSeconds)
        Set-UaProgress -Detail ('Немає інтернету. Перевірте Wi-Fi або кабель — я чекаю на зʼєднання (ще {0})...' -f $left)
        Start-UaSleep 5
        if (Test-UaInternet) {
            Write-UaLog 'Internet is back'
            Set-UaProgress -Detail 'Інтернет зʼявився, продовжую.'
            return
        }
    }
    throw (New-UaError 31 'no internet after waiting')
}

function Get-UaClockSkew {
    try {
        $resp = Get-UaResponse (New-UaRequest -Url $global:HL2UA_Config.ClockCheckUrl -Method 'HEAD' -TimeoutMs 10000)
        try { $d = [string]$resp.Headers['Date'] } finally { $resp.Close() }
        if (-not $d) { return $null }
        $server = [DateTime]::ParseExact($d, 'r', [Globalization.CultureInfo]::InvariantCulture)
        return ([DateTime]::UtcNow - $server)
    } catch { return $null }
}

# Мережевий виняток -> кодована помилка, зрозуміла людині.
function Convert-UaNetError($Ex, [int]$Default = 37) {
    $info = Get-UaErrorInfo $Ex
    if ($info) { return $info.Exception }
    $disk = Convert-UaDiskError $Ex
    if ($disk) { return $disk }
    $we = Find-UaException $Ex ([Net.WebException])
    $st = ''
    if ($we) { $st = $we.Status.ToString() }
    $tls = ($st -in 'TrustFailure', 'SecureChannelFailure') -or (Find-UaException $Ex ([Security.Authentication.AuthenticationException]))
    if ($tls) {
        $skew = Get-UaClockSkew
        Write-UaLog ('TLS failure; clock skew: ' + $skew) 'WARN'
        if ($null -ne $skew -and [Math]::Abs($skew.TotalHours) -ge 12) {
            return (New-UaError -Code 32 -Detail ('clock skew ' + $skew) -Inner $Ex -Extra ('Годинник компʼютера показує {0}.' -f (Get-Date).ToString('dd.MM.yyyy HH:mm')))
        }
        return (New-UaError 33 $st $Ex)
    }
    if ($st -eq 'ProtocolError') {
        $code = 0
        try { $code = [int]$we.Response.StatusCode } catch { }
        if ($code -eq 429) { return (New-UaError 35 'HTTP 429' $Ex) }
        if ($code -in 401, 403, 404, 410) { return (New-UaError 36 ('HTTP ' + $code) $Ex) }
    }
    if (-not (Test-UaInternet)) { return (New-UaError 31 $Ex.Message $Ex) }
    return (New-UaError $Default $Ex.Message $Ex)
}

function Get-UaWebText([string]$Url, [int]$Attempts = 3) {
    for ($a = 1; $a -le $Attempts; $a++) {
        Assert-UaNotCancelled
        try {
            $resp = Get-UaResponse (New-UaRequest -Url $Url -Html)
            try {
                $status = [int]$resp.StatusCode
                $body = Read-UaBody $resp
                return @{ Status = $status; Body = $body; Url = [string]$resp.ResponseUri }
            } finally { $resp.Close() }
        } catch {
            if ((Get-UaErrorInfo $_) -or -not (Test-UaTransient $_.Exception) -or $a -ge $Attempts) { throw }
            Write-UaLog ('GET {0} failed (attempt {1}): {2}' -f $Url, $a, $_.Exception.Message) 'WARN'
            Start-UaSleep (2 * $a)
        }
    }
}

# ---------------------------------------------------------- Google Drive ----

function ConvertFrom-UaJsString([string]$s) {
    if ($s.IndexOf([char]92) -lt 0) { return $s }
    return [regex]::Replace($s, '\\(x[0-9a-fA-F]{2}|u[0-9a-fA-F]{4}|.)', {
            param($m)
            $t = $m.Groups[1].Value
            if ($t.Length -eq 3 -and $t.StartsWith('x')) { return [string][char][Convert]::ToInt32($t.Substring(1), 16) }
            if ($t.Length -eq 5 -and $t.StartsWith('u')) { return [string][char][Convert]::ToInt32($t.Substring(1), 16) }
            switch -CaseSensitive ($t) {
                'n' { return "`n" }
                't' { return "`t" }
                'r' { return "`r" }
                'b' { return [string][char]8 }
                'f' { return [string][char]12 }
            }
            return $t
        })
}

function Get-UaDriveIdFromHref([string]$Href) {
    foreach ($rx in @('/file/d/([\w-]{10,})', '/folders/([\w-]{10,})', '[?&]id=([\w-]{10,})')) {
        $m = [regex]::Match($Href, $rx)
        if ($m.Success) { return $m.Groups[1].Value }
    }
    return $null
}

# Сторінка https://drive.google.com/embeddedfolderview?id=... (простий HTML).
function ConvertFrom-UaDriveEmbedHtml([string]$Html) {
    foreach ($chunk in [regex]::Split($Html, '(?=<div[^>]*class="flip-entry(?:\s[^"]*)?")')) {
        $mId = [regex]::Match($chunk, '^<div[^>]*\bid="entry-([^"]+)"')
        if (-not $mId.Success) { continue }
        $mTitle = [regex]::Match($chunk, '(?s)<div class="flip-entry-title">(.*?)</div>')
        if (-not $mTitle.Success) { continue }
        $mHref = [regex]::Match($chunk, '<a\s[^>]*href="([^"]+)"')
        $href = ''
        if ($mHref.Success) { $href = [Net.WebUtility]::HtmlDecode($mHref.Groups[1].Value) }
        $id = Get-UaDriveIdFromHref $href
        if (-not $id) { $id = $mId.Groups[1].Value }
        $name = [Net.WebUtility]::HtmlDecode(($mTitle.Groups[1].Value -replace '<[^>]+>', '')).Trim()
        @{ Id = $id; Name = $name; IsFolder = ($href -match '/folders/'); Path = $name }
    }
}

# Повна сторінка папки: дані лежать у JS-рядку window['_DRIVE_ivd'].
function ConvertFrom-UaDriveIvdHtml([string]$Html) {
    $m = [regex]::Match($Html, "window\['_DRIVE_ivd'\]\s*=\s*'((?:[^'\\]|\\.)*)'")
    if (-not $m.Success) { return }
    $data = ConvertFrom-UaJsString $m.Groups[1].Value
    $rx = [regex]'\["([\w-]{10,})",\["[\w-]+"\],"((?:[^"\\]|\\.)*)","([^"]+)"'
    foreach ($e in $rx.Matches($data)) {
        $name = ConvertFrom-UaJsString $e.Groups[2].Value
        @{ Id = $e.Groups[1].Value; Name = $name; IsFolder = ($e.Groups[3].Value -eq 'application/vnd.google-apps.folder'); Path = $name }
    }
}

function Get-UaDriveListing {
    param([string]$FolderId = $global:HL2UA_Config.DriveFolderId, [string]$Prefix = '', [int]$Depth = 0)
    $cfg = $global:HL2UA_Config
    $entries = @()
    $lastErr = $null
    try {
        $r = Get-UaWebText ($cfg.EmbedListUrl -f $FolderId)
        if ($r.Status -eq 200) { $entries = @(ConvertFrom-UaDriveEmbedHtml $r.Body) }
        Write-UaLog ('Drive listing (embed) {0}: HTTP {1}, {2} entries' -f $FolderId, $r.Status, $entries.Count)
    } catch { $lastErr = $_; Write-UaLog ('Drive listing (embed) failed: ' + (Format-UaError $_)) 'WARN' }
    if ($entries.Count -eq 0) {
        try {
            $r = Get-UaWebText ($cfg.FolderPageUrl -f $FolderId)
            if ($r.Status -eq 200) { $entries = @(ConvertFrom-UaDriveIvdHtml $r.Body) }
            Write-UaLog ('Drive listing (page) {0}: HTTP {1}, {2} entries' -f $FolderId, $r.Status, $entries.Count)
        } catch { $lastErr = $_; Write-UaLog ('Drive listing (page) failed: ' + (Format-UaError $_)) 'WARN' }
    }
    if ($entries.Count -eq 0) {
        if ($lastErr) { throw (Convert-UaNetError $lastErr.Exception 34) }
        throw (New-UaError 34 ('empty listing for folder ' + $FolderId))
    }
    foreach ($e in $entries) {
        $e.Path = $Prefix + $e.Name
        $e
        if ($e.IsFolder -and $Depth -lt 2) {
            try { Get-UaDriveListing -FolderId $e.Id -Prefix ($e.Path + '/') -Depth ($Depth + 1) }
            catch {
                if ((Get-UaErrorInfo $_) -and (Get-UaErrorInfo $_).Code -eq 91) { throw }
                Write-UaLog ('Subfolder listing failed ({0}): {1}' -f $e.Path, $_.Exception.Message) 'WARN'
            }
        }
    }
}

function Get-UaDrivePageKind([string]$Html) {
    if ($Html -match 'id="download-form"' -or $Html -match '(?i)action="https://drive\.usercontent\.google\.com/download"') { return 'confirm' }
    if ($Html -match '(?i)quota exceeded|too many users have viewed or downloaded|download quota') { return 'quota' }
    if ($Html -match '(?i)accounts\.google\.com/(ServiceLogin|v3/signin|AccountChooser)|you need access|request access|need permission') { return 'denied' }
    if ($Html -match '(?i)<title>[^<]*(not found|404)|file does not exist|the requested url was not found') { return 'notfound' }
    if ($Html -match '(?i)href="[^"]*[?&]confirm=[\w-]+') { return 'confirm' }
    return 'unknown'
}

# Сторінка «Google Drive can't scan this file for viruses»: збираємо форму у URL.
function Get-UaDriveConfirmUrl([string]$Html) {
    $form = [regex]::Match($Html, '(?is)<form[^>]*id="download-form"[^>]*>.*?</form>')
    if (-not $form.Success) { $form = [regex]::Match($Html, '(?is)<form[^>]*action="[^"]*download[^"]*"[^>]*>.*?</form>') }
    if ($form.Success) {
        $action = [Net.WebUtility]::HtmlDecode([regex]::Match($form.Value, '(?i)action="([^"]+)"').Groups[1].Value)
        if (-not $action) { $action = 'https://drive.usercontent.google.com/download' }
        $pairs = @()
        foreach ($inp in [regex]::Matches($form.Value, '(?i)<input[^>]*>')) {
            if ($inp.Value -notmatch '(?i)type="hidden"') { continue }
            $n = [regex]::Match($inp.Value, '(?i)name="([^"]*)"')
            if (-not $n.Success) { continue }
            $v = [regex]::Match($inp.Value, '(?i)value="([^"]*)"')
            $val = ''
            if ($v.Success) { $val = [Net.WebUtility]::HtmlDecode($v.Groups[1].Value) }
            $pairs += [Uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($n.Groups[1].Value)) + '=' + [Uri]::EscapeDataString($val)
        }
        if ($pairs.Count -gt 0) {
            $sep = '?'
            if ($action.Contains('?')) { $sep = '&' }
            return $action + $sep + ($pairs -join '&')
        }
    }
    $legacy = [regex]::Match($Html, '(?i)href="(/uc\?export=download[^"]*confirm=[^"]*)"')
    if ($legacy.Success) { return 'https://drive.google.com' + [Net.WebUtility]::HtmlDecode($legacy.Groups[1].Value) }
    return $null
}

function Get-UaContentRangeTotal([string]$Header) {
    if ($Header -match '/(\d+)\s*$') { return [long]$Matches[1] }
    return -1L
}

function Get-UaContentRangeStart([string]$Header) {
    if ($Header -match 'bytes\s+(\d+)-') { return [long]$Matches[1] }
    return -1L
}

function New-UaSpeedMeter {
    return @{ Sw = [Diagnostics.Stopwatch]::StartNew(); LastTick = -100000L; Samples = (New-Object System.Collections.Queue) }
}

function Test-UaTick($Meter, [int]$Ms = 250) {
    $t = $Meter.Sw.ElapsedMilliseconds
    if ($t - $Meter.LastTick -ge $Ms) { $Meter.LastTick = $t; return $true }
    return $false
}

function Get-UaSpeed($Meter, [long]$Done) {
    $t = $Meter.Sw.Elapsed.TotalSeconds
    $Meter.Samples.Enqueue(@($t, $Done))
    while ($Meter.Samples.Count -gt 2 -and ($t - $Meter.Samples.Peek()[0]) -gt 8) { [void]$Meter.Samples.Dequeue() }
    $first = $Meter.Samples.Peek()
    $dt = $t - $first[0]
    if ($dt -lt 0.8) { return -1.0 }
    return ($Done - $first[1]) / $dt
}

# Прогрес кроку-архіву: 0..0.8 — завантаження, 0.8..1 — розпакування.
function Set-UaJobProgress($Job, [string]$Phase, [double]$Fraction, [string]$Detail) {
    if ($Fraction -lt 0) { $Fraction = 0 }
    if ($Fraction -gt 1) { $Fraction = 1 }
    if ($Phase -eq 'download') { $f = 0.8 * $Fraction } else { $f = 0.8 + 0.2 * $Fraction }
    Set-UaProgress -Fraction $f -Detail $Detail
}

# Мінімальний запит (байт 0), щоб дізнатись розмір і пройти сторінку-попередження.
function Resolve-UaDriveFile($Job) {
    $url = $global:HL2UA_Config.DownloadUrl -f $Job.FileId
    for ($hop = 0; $hop -lt 4; $hop++) {
        Assert-UaNotCancelled
        $req = New-UaRequest -Url $url
        $req.AddRange([long]0, [long]0)
        $resp = Get-UaResponse $req
        try {
            $status = [int]$resp.StatusCode
            if ([string]$resp.ContentType -match '(?i)text/html') {
                $html = Read-UaBody $resp 2000000
                $kind = Get-UaDrivePageKind $html
                Write-UaLog ('Probe {0}: HTTP {1}, html page "{2}"' -f $Job.FileId, $status, $kind)
                if ($kind -eq 'confirm') {
                    $u = Get-UaDriveConfirmUrl $html
                    if ($u) { $url = $u; continue }
                }
                if ($kind -eq 'quota') { throw (New-UaError 35 'quota exceeded (probe)') }
                throw (New-UaError 36 ('unexpected page on probe: ' + $kind))
            }
            if ($status -eq 429) { throw (New-UaError 35 'HTTP 429') }
            if ($status -ge 500) { throw (New-Object IO.IOException ('HTTP ' + $status)) }
            if ($status -ge 400) { throw (New-UaError 36 ('HTTP ' + $status)) }
            $total = -1L
            if ($status -eq 206) { $total = Get-UaContentRangeTotal ([string]$resp.Headers['Content-Range']) }
            else { $total = [long]$resp.ContentLength }
            $Job.Url = $url
            if ($total -gt 0) { $Job.Size = $total }
            Write-UaLog ('Probe {0}: HTTP {1}, size {2}' -f $Job.FileId, $status, $total)
            return
        } finally {
            try { $req.Abort() } catch { }
            try { $resp.Close() } catch { }
        }
    }
    throw (New-UaError 36 'too many confirmation pages')
}

function Receive-UaHttpToFile($Job, [string]$Url, [string]$PartFile, [long]$Offset) {
    $req = New-UaRequest -Url $Url -From $Offset
    $resp = Get-UaResponse $req
    $fs = $null
    try {
        $status = [int]$resp.StatusCode
        if ([string]$resp.ContentType -match '(?i)text/html') { return @{ Kind = 'html'; Html = (Read-UaBody $resp 2000000) } }
        if ($status -eq 416) {
            $total = Get-UaContentRangeTotal ([string]$resp.Headers['Content-Range'])
            if ($total -gt 0 -and $Offset -eq $total) { return @{ Kind = 'done'; Total = $total } }
            return @{ Kind = 'restart' }
        }
        if ($status -eq 429) { throw (New-UaError 35 'HTTP 429') }
        if ($status -ge 500) { throw (New-Object IO.IOException ('HTTP ' + $status)) }
        if ($status -ge 400) { throw (New-UaError 36 ('HTTP ' + $status)) }
        $append = ($status -eq 206)
        if ($append) {
            $cr = [string]$resp.Headers['Content-Range']
            if ((Get-UaContentRangeStart $cr) -ne $Offset) { return @{ Kind = 'restart' } }
            $total = Get-UaContentRangeTotal $cr
        } else {
            if ($Offset -gt 0) { Write-UaLog 'Server ignored Range; restarting from 0' 'WARN' }
            $Offset = 0
            $total = [long]$resp.ContentLength
        }
        if ($total -gt 0) {
            $Job.Size = $total
            Assert-UaFreeSpace $PartFile ($total - $Offset + 64MB)
        }
        if ($append) { $mode = [IO.FileMode]::Append } else { $mode = [IO.FileMode]::Create }
        $fs = New-Object IO.FileStream($PartFile, $mode, [IO.FileAccess]::Write, [IO.FileShare]::Read, 262144)
        $rs = $resp.GetResponseStream()
        $buf = New-Object byte[] 262144
        $done = $Offset
        $meter = New-UaSpeedMeter
        while ($true) {
            $n = $rs.Read($buf, 0, $buf.Length)
            if ($n -le 0) { break }
            $fs.Write($buf, 0, $n)
            $done += $n
            if (Test-UaTick $meter) {
                Assert-UaNotCancelled
                $speed = Get-UaSpeed $meter $done
                $txt = 'Завантаження: ' + (Format-UaSize $done)
                if ($total -gt 0) { $txt += ' з ' + (Format-UaSize $total) }
                if ($speed -gt 0) {
                    $txt += ' · ' + (Format-UaSize $speed) + '/с'
                    if ($total -gt 0) { $txt += ' · залишилось ≈ ' + (Format-UaDuration (($total - $done) / $speed)) }
                }
                $frac = 0.0
                if ($total -gt 0) { $frac = [double]$done / $total }
                Set-UaJobProgress $Job 'download' $frac $txt
            }
        }
        $fs.Flush()
        if ($total -gt 0 -and $done -lt $total) { throw (New-Object IO.IOException ('Connection closed early: {0} of {1}' -f $done, $total)) }
        return @{ Kind = 'done'; Total = $done }
    } finally {
        if ($fs) { $fs.Dispose() }
        try { $resp.Close() } catch { }
        if ($global:HL2UA_State) { $global:HL2UA_State.ActiveRequest = $null }
    }
}

function Receive-UaDriveFile($Job, [string]$OutFile) {
    $part = $OutFile + '.part'
    $url = $Job.Url
    if (-not $url) { $url = $global:HL2UA_Config.DownloadUrl -f $Job.FileId }
    $attempt = 0
    $hops = 0
    $maxAttempts = 8
    $offlineWaits = 0
    while ($true) {
        Assert-UaNotCancelled
        $attempt++
        $offset = 0L
        if ([IO.File]::Exists($part)) { $offset = (New-Object IO.FileInfo($part)).Length }
        if ($Job.Size -gt 0 -and $offset -gt $Job.Size) { Remove-UaFileQuiet $part; $offset = 0L }
        if ($offset -gt 0) { Write-UaLog ('Resuming download from byte {0}' -f $offset) }
        try {
            $r = Receive-UaHttpToFile $Job $url $part $offset
            if ($r.Kind -eq 'html') {
                $kind = Get-UaDrivePageKind $r.Html
                Write-UaLog ('Download got html page "{0}"' -f $kind) 'WARN'
                if ($kind -eq 'confirm' -and $hops -lt 3) {
                    $u = Get-UaDriveConfirmUrl $r.Html
                    if ($u) { $url = $u; $hops++; $attempt--; continue }
                }
                if ($kind -eq 'quota') { throw (New-UaError 35 'quota exceeded') }
                throw (New-UaError 36 ('unexpected page: ' + $kind))
            }
            if ($r.Kind -eq 'restart') {
                Remove-UaFileQuiet $part
                if ($attempt -lt $maxAttempts) { continue }
                throw (New-UaError 37 'server keeps rejecting resume')
            }
            Remove-UaFileQuiet $OutFile
            [IO.File]::Move($part, $OutFile)
            Write-UaLog ('Downloaded {0} ({1} bytes)' -f $OutFile, $r.Total)
            return
        } catch {
            if (Get-UaErrorInfo $_) { throw }
            $ex = $_.Exception
            if (-not (Test-UaTransient $ex)) { throw (Convert-UaNetError $ex 37) }
            Write-UaLog ('Download attempt {0} failed: {1}' -f $attempt, (Format-UaError $_)) 'WARN'
            if (-not (Test-UaInternet)) {
                $offlineWaits++
                if ($offlineWaits -gt 3) { throw (New-UaError 31 'connection lost') }
                Wait-UaInternet 600
                $attempt--
                continue
            }
            if ($attempt -ge $maxAttempts) { throw (Convert-UaNetError $ex 37) }
            $delay = @(2, 4, 8, 15, 30, 30, 30, 30)[[Math]::Min($attempt - 1, 7)]
            Set-UaProgress -Detail ('Звʼязок перервався. Продовжу завантаження через {0} с (спроба {1} з {2})...' -f $delay, ($attempt + 1), $maxAttempts)
            Start-UaSleep $delay
        }
    }
}

# ================================================================ archives ====

function Get-UaArchiveInfo([string]$Path) {
    $n = $Path.ToLowerInvariant()
    $ext = [IO.Path]::GetExtension($n)
    $part = 'hl2'
    $lead = '(?<![a-zа-яіїєґ])(епізод|эпизод|episode|ep|еп)[\s._-]*'
    if ($n -match ($lead + '(2|два|two|ii)(?![0-9a-zа-я])') -or $n -match '(?<![a-z])ep2(?![0-9])') { $part = 'ep2' }
    elseif ($n -match ($lead + '(1|один|one|i)(?![0-9a-zа-я])') -or $n -match '(?<![a-z])(ep1|episodic)(?![0-9])') { $part = 'ep1' }
    elseif ($n -match 'lost\s*coast') { $part = 'lostcoast' }
    $type = 'other'
    if ($n -match 'озвуч|дубляж|voice|dub') { $type = 'full' }
    elseif ($n -match 'текст(?!ур)|text(?!ure)|субтитр') { $type = 'text' }
    elseif ($n -match 'текстур|texture') { $type = 'textures' }
    return @{ Part = $part; Type = $type; Ext = $ext }
}

function Compare-UaVersionName([string]$A, [string]$B) {
    $va = [regex]::Match($A, '(?i)v?(\d+(?:\.\d+)+)')
    $vb = [regex]::Match($B, '(?i)v?(\d+(?:\.\d+)+)')
    if ($va.Success -and $vb.Success) {
        try { return ([version]$va.Groups[1].Value).CompareTo([version]$vb.Groups[1].Value) } catch { }
    }
    if ($va.Success) { return 1 }
    return 0
}

function Select-UaArchives($Listing, [string[]]$Parts) {
    $sel = @{}
    foreach ($p in $Parts) { $sel[$p] = @{ Full = $null; Text = $null; Other = $null; Unsupported = $null } }
    foreach ($e in @($Listing)) {
        if (-not $e -or $e.IsFolder) { continue }
        $info = Get-UaArchiveInfo $e.Path
        if (-not $sel.ContainsKey($info.Part)) { continue }
        $slot = $sel[$info.Part]
        if ($info.Ext -notin '.zip', '.7z', '.rar') { continue }
        if ($info.Ext -ne '.zip') {
            if ($info.Type -in 'full', 'other') { $slot.Unsupported = $e }
            continue
        }
        $key = $null
        if ($info.Type -eq 'full') { $key = 'Full' }
        elseif ($info.Type -eq 'text') { $key = 'Text' }
        elseif ($info.Type -eq 'other') { $key = 'Other' }
        if (-not $key) { continue }
        if (-not $slot[$key] -or (Compare-UaVersionName $e.Name $slot[$key].Name) -gt 0) { $slot[$key] = $e }
    }
    foreach ($p in $Parts) {
        $slot = $sel[$p]
        if (-not $slot.Full -and $slot.Other) {
            Write-UaLog ('No explicit voice archive for {0}; using "{1}"' -f $p, $slot.Other.Path) 'WARN'
            $slot.Full = $slot.Other
        }
    }
    return $sel
}

function Get-UaArchiveType([string]$Path) {
    $fs = [IO.File]::OpenRead($Path)
    try {
        $b = New-Object byte[] 16
        $n = $fs.Read($b, 0, 16)
    } finally { $fs.Dispose() }
    if ($n -ge 4 -and $b[0] -eq 0x50 -and $b[1] -eq 0x4B -and $b[2] -in 3, 5, 7) { return 'zip' }
    if ($n -ge 6 -and $b[0] -eq 0x37 -and $b[1] -eq 0x7A -and $b[2] -eq 0xBC -and $b[3] -eq 0xAF) { return '7z' }
    if ($n -ge 4 -and $b[0] -eq 0x52 -and $b[1] -eq 0x61 -and $b[2] -eq 0x72 -and $b[3] -eq 0x21) { return 'rar' }
    $head = [Text.Encoding]::ASCII.GetString($b, 0, $n).TrimStart()
    if ($head -match '(?i)^<(!doctype|html)') { return 'html' }
    return 'unknown'
}

function Test-UaZipOpens([string]$Path) {
    try {
        $z = [IO.Compression.ZipFile]::OpenRead($Path)
        try { return ($z.Entries.Count -gt 0) } finally { $z.Dispose() }
    } catch { return $false }
}

# Шукаємо в архіві «корінь гри»: теку, де лежать hl2/, platform/, *_ukr/ тощо.
function Find-UaZipRootPrefix([string[]]$Names) {
    # Теки, що бувають лише в корені гри (bin трапляється й усередині hl2/, тому окремо).
    $rootOnly = '^(hl2|hl2_complete|episodic|ep2|lostcoast|platform|hl2mp|[a-z0-9_]+_(ukr|ukrainian|ua))$'
    $best = $null
    $bestDepth = [int]::MaxValue
    foreach ($n in $Names) {
        $parts = $n.Split('/')
        $limit = [Math]::Min($parts.Length - 1, $bestDepth)
        for ($k = 0; $k -lt $limit; $k++) {
            if ($parts[$k] -match $rootOnly -or $parts[$k] -eq 'bin') {
                # «HL2/hl2_ukr/...» — зовнішня HL2 лише обгортка архіву.
                while ($k + 1 -lt $parts.Length - 1 -and $parts[$k + 1] -match $rootOnly) { $k++ }
                if ($k -lt $bestDepth) {
                    $bestDepth = $k
                    if ($k -eq 0) { $best = '' } else { $best = ($parts[0..($k - 1)] -join '/') + '/' }
                }
                break
            }
        }
    }
    return $best
}

function Test-UaSafeRelPath([string]$Rel) {
    if (-not $Rel) { return $false }
    if ($Rel.StartsWith('/') -or $Rel.Contains(':')) { return $false }
    foreach ($seg in $Rel.Split('/')) {
        if ($seg -eq '' -or $seg -eq '.' -or $seg -eq '..') { return $false }
    }
    if ($Rel.IndexOfAny([IO.Path]::GetInvalidPathChars()) -ge 0) { return $false }
    return $true
}

function Test-UaJunkEntry([string]$Rel) {
    if ($Rel -match '(^|/)__MACOSX/') { return $true }
    $leaf = $Rel.Split('/')[-1]
    if ($leaf -in '.DS_Store', 'Thumbs.db', 'desktop.ini') { return $true }
    if ($leaf.StartsWith('._')) { return $true }
    # Файли прямо в корені (readme, інструкції) у папку гри не кладемо.
    if (-not $Rel.Contains('/')) { return $true }
    return $false
}

function Get-UaZipPlan($Zip) {
    $all = New-Object System.Collections.Generic.List[object]
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($e in $Zip.Entries) {
        $n = $e.FullName.Replace('\', '/')
        if ($n.EndsWith('/') -or $e.Name -eq '') { continue }
        $all.Add(@($e, $n))
        $names.Add($n)
    }
    $top = @($names | ForEach-Object { $_.Split('/')[0] } | Select-Object -Unique | Select-Object -First 15)
    $plan = @{ Prefix = $null; Items = (New-Object System.Collections.Generic.List[object]); TotalBytes = 0L; Skipped = 0; TopLevel = $top }
    $prefix = Find-UaZipRootPrefix $names.ToArray()
    if ($null -eq $prefix) { return $plan }
    $plan.Prefix = $prefix
    foreach ($pair in $all) {
        $e = $pair[0]
        $n = [string]$pair[1]
        $ok = $n.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
        $rel = $null
        if ($ok) {
            $rel = $n.Substring($prefix.Length)
            $ok = (Test-UaSafeRelPath $rel) -and -not (Test-UaJunkEntry $rel)
        }
        if (-not $ok) {
            $plan.Skipped++
            if ($plan.Skipped -le 30) { Write-UaLog ('  skipped archive entry: ' + $n) }
            continue
        }
        $plan.Items.Add(@{ Entry = $e; Rel = $rel; Length = [long]$e.Length })
        $plan.TotalBytes += [long]$e.Length
    }
    return $plan
}

# ------------------------------------------------ install data & journal ----
# <гра>\_ukrainizator\journal.txt — що створено/замінено (для відкату й видалення),
# backup\ — оригінали замінених файлів, manifest.json — підсумок встановлення.

function Get-UaDataDir($ctx) { return (Join-UaPath $ctx.GameDir $global:HL2UA_Config.DataDirName) }

function Add-UaJournal($ctx, $Txn, [string]$Kind, [string]$Rel) {
    $line = $Kind + "`t" + $Rel
    $ctx.Journal.Add($line)
    if ($Txn) { $Txn.Lines.Add($line) }
    [IO.File]::AppendAllText($ctx.JournalPath, $line + "`r`n", (New-Object Text.UTF8Encoding($false)))
}

function Save-UaJournal($ctx) {
    if (-not $ctx.JournalPath) { return }
    if ($ctx.Journal.Count -eq 0) { Remove-UaFileQuiet $ctx.JournalPath; return }
    [IO.File]::WriteAllLines($ctx.JournalPath, $ctx.Journal.ToArray(), (New-Object Text.UTF8Encoding($false)))
}

function Get-UaRelPath([string]$Root, [string]$Path) {
    $r = $Root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if ($Path.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) { return $Path.Substring($r.Length).Replace('\', '/') }
    return $null
}

function New-UaDirTracked($ctx, $Txn, [string]$Dir) {
    $missing = New-Object System.Collections.Generic.List[string]
    $d = $Dir
    while ($d -and -not [IO.Directory]::Exists($d)) {
        $missing.Insert(0, $d)
        $d = [IO.Path]::GetDirectoryName($d)
    }
    foreach ($m in $missing) {
        [void][IO.Directory]::CreateDirectory($m)
        $Txn.Dirs.Add($m)
        $rel = Get-UaRelPath $ctx.GameDir $m
        if ($rel) { Add-UaJournal $ctx $Txn 'D' $rel }
    }
}

function Open-UaOutputFile([string]$Path) {
    for ($a = 1; ; $a++) {
        try { return (New-Object IO.FileStream($Path, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None, 65536)) }
        catch {
            $io = Find-UaException $_.Exception ([IO.IOException])
            $hr = 0
            if ($io) { $hr = $io.HResult -band 0xFFFF }
            if ($a -ge 5 -or $hr -notin 32, 33) { throw }
            Start-Sleep -Milliseconds (600 * $a)
        }
    }
}

function Undo-UaTransaction($ctx, $Txn, [string]$BackupDir) {
    for ($i = $Txn.New.Count - 1; $i -ge 0; $i--) { Remove-UaFileQuiet (Join-UaPath $ctx.GameDir $Txn.New[$i]) }
    foreach ($rel in $Txn.Replaced) {
        $b = Join-UaPath $BackupDir $rel
        if (-not [IO.File]::Exists($b)) { continue }
        try {
            $t = Join-UaPath $ctx.GameDir $rel
            Clear-UaReadOnly $t
            [IO.File]::Copy($b, $t, $true)
            [IO.File]::Delete($b)
        } catch { Write-UaLog ('Rollback: could not restore {0}: {1}' -f $rel, $_.Exception.Message) 'ERROR' }
    }
    for ($i = $Txn.Dirs.Count - 1; $i -ge 0; $i--) { Remove-UaEmptyDir $Txn.Dirs[$i] }
    foreach ($k in $Txn.Keys) { [void]$ctx.Tracked.Remove($k) }
    $drop = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($l in $Txn.Lines) { [void]$drop.Add($l) }
    $keep = New-Object System.Collections.Generic.List[string]
    foreach ($l in $ctx.Journal) { if (-not $drop.Contains($l)) { $keep.Add($l) } }
    $ctx.Journal = $keep
    Save-UaJournal $ctx
    if ($ctx.Journal.Count -eq 0) {
        Remove-UaDirQuiet $BackupDir
        Remove-UaEmptyDir (Get-UaDataDir $ctx)
    }
    Write-UaLog ('Rollback done: removed {0} new files, restored {1}' -f $Txn.New.Count, $Txn.Replaced.Count)
}

function Install-UaArchive($ctx, $Job, [string]$ZipPath) {
    $zip = $null
    try { $zip = [IO.Compression.ZipFile]::OpenRead($ZipPath) }
    catch { throw (New-UaError 38 ('cannot open zip: ' + $_.Exception.Message) $_.Exception) }
    try {
        Set-UaJobProgress $Job 'install' 0 'Перевіряю вміст архіву...'
        $plan = Get-UaZipPlan $zip
        Write-UaLog ('Archive plan: prefix="{0}", {1} files, {2} bytes, {3} skipped, top-level: {4}' -f $plan.Prefix, $plan.Items.Count, $plan.TotalBytes, $plan.Skipped, ($plan.TopLevel -join ', '))
        if ($plan.Items.Count -eq 0) { throw (New-UaError 51 ('no installable entries; top-level: ' + ($plan.TopLevel -join ', '))) }
        $existing = 0L
        foreach ($it in $plan.Items) {
            $t = Join-UaPath $ctx.GameDir $it.Rel
            if (-not $ctx.Tracked.Contains($it.Rel.ToLowerInvariant()) -and [IO.File]::Exists($t)) { $existing += (New-Object IO.FileInfo($t)).Length }
        }
        $doBackup = $existing -le 2GB
        $need = [Math]::Max(0L, $plan.TotalBytes - $existing) + 200MB
        if ($doBackup) { $need += $existing }
        Assert-UaFreeSpace $ctx.GameDir $need
        if (-not $doBackup) { Write-UaLog ('Backup skipped: {0} bytes would be replaced' -f $existing) 'WARN' }
        Invoke-UaExtract $ctx $Job $plan $doBackup
    } finally { $zip.Dispose() }
}

function Invoke-UaExtract($ctx, $Job, $Plan, [bool]$DoBackup) {
    $data = Get-UaDataDir $ctx
    [void][IO.Directory]::CreateDirectory($data)
    $backup = Join-UaPath $data 'backup'
    if (-not $ctx.JournalPath) { $ctx.JournalPath = Join-UaPath $data 'journal.txt' }
    $txn = @{
        New      = (New-Object System.Collections.Generic.List[string])
        Replaced = (New-Object System.Collections.Generic.List[string])
        Dirs     = (New-Object System.Collections.Generic.List[string])
        Keys     = (New-Object System.Collections.Generic.List[string])
        Lines    = (New-Object System.Collections.Generic.List[string])
    }
    $buf = New-Object byte[] 262144
    $total = [Math]::Max(1L, [long]$Plan.TotalBytes)
    $count = [int]$Plan.Items.Count
    $done = 0L
    $i = 0
    $meter = New-UaSpeedMeter
    try {
        foreach ($it in $Plan.Items) {
            $rel = [string]$it.Rel
            $target = Join-UaPath $ctx.GameDir $rel
            $dir = [IO.Path]::GetDirectoryName($target)
            if (-not [IO.Directory]::Exists($dir)) { New-UaDirTracked $ctx $txn $dir }
            $key = $rel.ToLowerInvariant()
            $exists = [IO.File]::Exists($target)
            if (-not $ctx.Tracked.Contains($key)) {
                if ($exists) {
                    if ($DoBackup) {
                        $b = Join-UaPath $backup $rel
                        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($b))
                        [IO.File]::Copy($target, $b, $true)
                        Add-UaJournal $ctx $txn 'R' $rel
                    } else {
                        Add-UaJournal $ctx $txn 'X' $rel
                    }
                    $txn.Replaced.Add($rel)
                } else {
                    Add-UaJournal $ctx $txn 'N' $rel
                    $txn.New.Add($rel)
                }
                [void]$ctx.Tracked.Add($key)
                $txn.Keys.Add($key)
            }
            if ($exists) { Clear-UaReadOnly $target }
            $out = Open-UaOutputFile $target
            try {
                $in = $it.Entry.Open()
                try {
                    while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                        $out.Write($buf, 0, $n)
                        $done += $n
                        if (Test-UaTick $meter 250) {
                            Assert-UaNotCancelled
                            Set-UaJobProgress $Job 'install' ([double]$done / $total) ('Встановлення файлів: {0} з {1} ({2}%)' -f $i, $count, [int](100.0 * $done / $total))
                        }
                    }
                } finally { $in.Dispose() }
            } finally { $out.Dispose() }
            try { [IO.File]::SetLastWriteTime($target, $it.Entry.LastWriteTime.DateTime) } catch { }
            $i++
        }
    } catch {
        $err = $_
        Write-UaLog ('Extraction failed at file #{0}: {1}' -f $i, (Format-UaError $err)) 'ERROR'
        Set-UaProgress -Detail 'Сталася помилка — повертаю все як було...'
        try { Undo-UaTransaction $ctx $txn $backup } catch { Write-UaLog ('Rollback problem: ' + $_.Exception.Message) 'ERROR' }
        if (Get-UaErrorInfo $err) { throw $err }
        throw (Convert-UaDiskError $err.Exception 52)
    }
    Set-UaJobProgress $Job 'install' 1.0 ('Встановлено файлів: {0}' -f $count)
    Write-UaLog ('Installed {0} files ({1} new, {2} replaced)' -f $count, $txn.New.Count, $txn.Replaced.Count)
}

# ============================================== launch options / shortcuts ====

function Get-UaLocalConfigs([string]$SteamRoot) {
    $ud = Join-UaPath $SteamRoot 'userdata'
    if (-not [IO.Directory]::Exists($ud)) { return }
    foreach ($d in [IO.Directory]::GetDirectories($ud)) {
        $name = [IO.Path]::GetFileName($d)
        if ($name -notmatch '^\d+$' -or $name -eq '0') { continue }
        $f = Join-UaPath $d 'config' 'localconfig.vdf'
        if ([IO.File]::Exists($f)) { $f }
    }
}

function Write-UaTextAtomic([string]$Path, [string]$Text) {
    $tmp = $Path + '.hl2ua.tmp'
    [IO.File]::WriteAllText($tmp, $Text, (New-Object Text.UTF8Encoding($false)))
    [IO.File]::Copy($tmp, $Path, $true)
    [IO.File]::Delete($tmp)
}

# Рахує новий текст localconfig.vdf. Mode 'add' — додає -language ukr;
# 'remove' — повертає параметри запуску такими, як були до нас.
function Get-UaLaunchOptionsEdit([string]$File, [string]$Text, [string]$Mode, $Records) {
    $newText = $Text
    $changes = New-Object System.Collections.Generic.List[object]
    $apps = @($global:HL2UA_Config.SteamAppId) + @($global:HL2UA_Config.ExtraSteamAppIds)
    foreach ($appId in $apps) {
        if ($Mode -eq 'add') {
            $transform = { param($old) Add-UaLaunchArgs $old }
        } else {
            $rec = $null
            foreach ($rr in @($Records)) { if ($rr -and (Get-UaProp $rr 'File') -ieq $File -and [string](Get-UaProp $rr 'AppId') -eq $appId) { $rec = $rr } }
            $transform = {
                param($old)
                if ($rec -and $old -ceq [string](Get-UaProp $rec 'After')) { return [string](Get-UaProp $rec 'Before') }
                return Remove-UaLaunchArgs $old
            }.GetNewClosure()
        }
        $create = ($Mode -eq 'add' -and $appId -eq $global:HL2UA_Config.SteamAppId)
        $res = Set-UaVdfAppLaunchOptions -Text $newText -AppId $appId -Transform $transform -CreateIfMissing:$create -RemoveIfEmpty:($Mode -eq 'remove')
        if ($res.Changed) {
            $newText = $res.Text
            $changes.Add(@{ File = $File; AppId = $appId; Before = $res.Before; After = $res.After })
        }
    }
    return @{ Text = $newText; Changes = $changes; Changed = ($newText -cne $Text) }
}

function Update-UaSteamLaunchOptions($ctx, [string]$Mode, $Records) {
    $root = $ctx.Game.SteamRoot
    $files = @(Get-UaLocalConfigs $root)
    Write-UaLog ('localconfig.vdf files: ' + ($files -join '; '))
    if ($files.Count -eq 0) {
        if ($Mode -eq 'add') { $ctx.Warnings.Add('Не знайдено налаштувань Steam. Увімкніть мову вручну: Steam → правою кнопкою на Half-Life 2 → Властивості → Параметри запуску: -language ukr') }
        return
    }
    # Спершу «на сухо»: якщо все вже налаштовано, Steam не чіпаємо.
    $needed = $false
    foreach ($f in $files) {
        try {
            $plan = Get-UaLaunchOptionsEdit $f ([IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)) $Mode $Records
            if ($plan.Changed) { $needed = $true }
        } catch { $needed = $true }
    }
    if (-not $needed) { Write-UaLog 'Launch options already in the desired state'; return }
    $wasRunning = Stop-UaSteam $root
    try {
        foreach ($f in $files) {
            # Перечитуємо ПІСЛЯ закриття Steam: він переписує цей файл під час виходу.
            $text = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)
            $edit = Get-UaLaunchOptionsEdit $f $text $Mode $Records
            if (-not $edit.Changed) { continue }
            [void](ConvertFrom-UaVdf $edit.Text)
            $bak = $f + '.hl2ua.bak'
            if ($Mode -eq 'add' -and -not [IO.File]::Exists($bak)) { [IO.File]::Copy($f, $bak, $false) }
            Write-UaTextAtomic $f $edit.Text
            foreach ($c in $edit.Changes) {
                Write-UaLog ('LaunchOptions [{0}] {1}: "{2}" -> "{3}"' -f $c.AppId, $f, $c.Before, $c.After)
                if ($Mode -eq 'add') { $ctx.LaunchChanges.Add($c) }
            }
            if ($Mode -eq 'remove') { Remove-UaFileQuiet $bak }
        }
    } catch {
        if (Get-UaErrorInfo $_) { throw }
        throw (New-UaError 62 $_.Exception.Message $_.Exception)
    } finally {
        if ($wasRunning) { Start-UaSteam $root }
    }
}

function Set-UaShortcutLanguage($ctx) {
    $shell = $null
    try { $shell = New-Object -ComObject WScript.Shell } catch { }
    if (-not $shell) { $ctx.Warnings.Add('Додайте до ярлика гри параметр запуску: -language ukr'); return }
    $found = 0
    foreach ($t in @(Get-UaShortcutTargets)) {
        if (-not $t.Target -or $t.Target -notmatch '(?i)\.exe$') { continue }
        if (-not ([IO.Path]::GetDirectoryName($t.Target)).StartsWith($ctx.GameDir, [StringComparison]::OrdinalIgnoreCase)) { continue }
        try {
            $sc = $shell.CreateShortcut($t.Path)
            $before = [string]$sc.Arguments
            $after = Add-UaLaunchArgs $before
            if ($after -cne $before) {
                $sc.Arguments = $after
                $sc.Save()
                $ctx.ShortcutChanges.Add(@{ Path = $t.Path; Before = $before; After = $after; Created = $false })
                Write-UaLog ('Shortcut {0}: "{1}" -> "{2}"' -f $t.Path, $before, $after)
            }
            $found++
        } catch { Write-UaLog ('Shortcut update failed {0}: {1}' -f $t.Path, $_.Exception.Message) 'WARN' }
    }
    if ($found -gt 0) { return }
    $exe = Get-UaGameExe $ctx.GameDir
    if (-not $exe) { $ctx.Warnings.Add('Додайте до ярлика гри параметр запуску: -language ukr'); return }
    $lnk = Join-UaPath (Get-UaDesktop) 'Half-Life 2 (українською).lnk'
    $sc = $shell.CreateShortcut($lnk)
    $sc.TargetPath = $exe
    $sc.Arguments = $global:HL2UA_Config.LaunchArgs
    $sc.WorkingDirectory = $ctx.GameDir
    $sc.IconLocation = $exe + ',0'
    $sc.Save()
    $ctx.ShortcutChanges.Add(@{ Path = $lnk; Before = ''; After = $global:HL2UA_Config.LaunchArgs; Created = $true })
    $ctx.Warnings.Add('Запускайте гру ярликом «Half-Life 2 (українською)» на Робочому столі.')
}

function Restore-UaShortcuts($Records) {
    $shell = $null
    foreach ($r in @($Records)) {
        try {
            $p = [string](Get-UaProp $r 'Path')
            if (-not [IO.File]::Exists($p)) { continue }
            if (Get-UaProp $r 'Created') { Remove-UaFileQuiet $p; continue }
            if (-not $shell) { $shell = New-Object -ComObject WScript.Shell }
            $sc = $shell.CreateShortcut($p)
            $cur = [string]$sc.Arguments
            if ($cur -ceq [string](Get-UaProp $r 'After')) { $sc.Arguments = [string](Get-UaProp $r 'Before') } else { $sc.Arguments = Remove-UaLaunchArgs $cur }
            $sc.Save()
        } catch { Write-UaLog ('Shortcut restore failed: ' + $_.Exception.Message) 'WARN' }
    }
}

function Invoke-UaWorkshopSubscribe($ctx) {
    $cfg = $global:HL2UA_Config
    foreach ($part in @($ctx.Parts)) {
        if ($ctx.InstalledFull.ContainsKey($part)) { continue }
        $id = $cfg.WorkshopItems[$part]
        if (-not $id) { continue }
        $name = Get-UaPartName $part
        Invoke-UaShellOpen ('steam://url/CommunityFilePage/' + $id)
        $idx = Request-UaChoice -Title 'Озвучка зі Steam' -Text ("У Steam відкрилася сторінка «{0} — Повна Українська Локалізація (HamUA Studio)».`n`nНатисніть там зелену кнопку «Підписатися» (Subscribe), потім поверніться сюди і натисніть «Готово»." -f $name) -Buttons @('Готово', 'Пропустити')
        if ($idx -ne 0) { $ctx.Warnings.Add(('Озвучку для «{0}» не підключено зі Steam Workshop.' -f $name)) }
    }
    $ctx.Warnings.Add('Озвучку Steam докачає сам. Перед грою дочекайтеся, поки завантаження в Steam завершиться.')
}

# =================================================== previous install / uninstall ====

function Get-UaPreviousInstall($ctx) {
    $d = Get-UaDataDir $ctx
    $m = Join-UaPath $d 'manifest.json'
    $j = Join-UaPath $d 'journal.txt'
    if ([IO.File]::Exists($m)) {
        try { return @{ Complete = $true; Manifest = ([IO.File]::ReadAllText($m, [Text.Encoding]::UTF8) | ConvertFrom-Json) } }
        catch { return @{ Complete = $false; Manifest = $null } }
    }
    if ([IO.File]::Exists($j)) { return @{ Complete = $false; Manifest = $null } }
    return $null
}

function Remove-UaInstalledFiles($ctx) {
    $data = Get-UaDataDir $ctx
    $jp = Join-UaPath $data 'journal.txt'
    $backup = Join-UaPath $data 'backup'
    $lines = @()
    if ([IO.File]::Exists($jp)) { $lines = @([IO.File]::ReadAllLines($jp, [Text.Encoding]::UTF8)) }
    Write-UaLog ('Uninstall: {0} journal records' -f $lines.Count)
    $dirs = New-Object System.Collections.Generic.List[string]
    $noBackup = 0
    $meter = New-UaSpeedMeter
    for ($k = $lines.Count - 1; $k -ge 0; $k--) {
        $parts = $lines[$k] -split "`t", 2
        if ($parts.Count -lt 2) { continue }
        $kind = $parts[0]
        $rel = $parts[1]
        if (-not (Test-UaSafeRelPath $rel)) { continue }
        $target = Join-UaPath $ctx.GameDir $rel
        switch ($kind) {
            'N' { Remove-UaFileQuiet $target }
            'R' {
                $b = Join-UaPath $backup $rel
                if ([IO.File]::Exists($b)) {
                    try { Clear-UaReadOnly $target; [IO.File]::Copy($b, $target, $true) } catch { Write-UaLog ('Restore failed {0}: {1}' -f $rel, $_.Exception.Message) 'WARN' }
                } else { $noBackup++ }
            }
            'X' { $noBackup++ }
            'D' { $dirs.Add($target) }
        }
        if (Test-UaTick $meter 250) {
            Assert-UaNotCancelled
            $doneCount = $lines.Count - $k
            Set-UaProgress -Fraction ([double]$doneCount / [Math]::Max(1, $lines.Count)) -Detail ('Видаляю файли українізатора: {0} з {1}' -f $doneCount, $lines.Count)
        }
    }
    foreach ($d in @($dirs | Sort-Object Length -Descending)) { Remove-UaEmptyDir $d }
    if ($noBackup -gt 0) { $ctx.Warnings.Add('Частину оригінальних файлів не збережено. Щоб повністю їх повернути: Steam → правою кнопкою на Half-Life 2 → Властивості → Встановлені файли → «Перевірити цілісність файлів гри».') }
    Remove-UaFileQuiet $jp
    Remove-UaDirQuiet $backup
    $ctx.Journal = New-Object System.Collections.Generic.List[string]
    $ctx.Tracked.Clear()
}

function Invoke-UaUninstallFlow($ctx, $Prev) {
    Initialize-UaSteps @(
        @{ Key = 'check'; Title = 'Перевірка компʼютера'; Weight = 2 },
        @{ Key = 'find'; Title = 'Пошук гри Half-Life 2'; Weight = 3 },
        @{ Key = 'remove'; Title = 'Видалення файлів українізатора'; Weight = 80 },
        @{ Key = 'lang'; Title = 'Повернення англійської мови'; Weight = 12 },
        @{ Key = 'cleanup'; Title = 'Прибирання'; Weight = 3 }
    )
    Complete-UaStep 'find'
    Enter-UaStep 'remove'
    Remove-UaInstalledFiles $ctx
    Complete-UaStep 'remove'
    Enter-UaStep 'lang'
    $m = $null
    if ($Prev) { $m = $Prev.Manifest }
    if ($ctx.IsSteam) { Update-UaSteamLaunchOptions $ctx 'remove' @(Get-UaProp $m 'LaunchOptions') }
    else { Restore-UaShortcuts @(Get-UaProp $m 'Shortcuts') }
    Complete-UaStep 'lang'
    Enter-UaStep 'cleanup'
    Remove-UaDirQuiet (Get-UaDataDir $ctx)
    Complete-UaStep 'cleanup'
    return 'uninstalled'
}

function Save-UaManifest($ctx) {
    $launch = New-Object System.Collections.Generic.List[object]
    $shortcuts = New-Object System.Collections.Generic.List[object]
    $prev = $ctx.PreviousManifest
    # При перевстановленні зберігаємо найперші «було», щоб видалення повернуло оригінал.
    foreach ($r in @(Get-UaProp $prev 'LaunchOptions')) { if ($r) { $launch.Add($r) } }
    foreach ($c in $ctx.LaunchChanges) {
        $dup = $false
        foreach ($r in $launch) { if ((Get-UaProp $r 'File') -ieq $c.File -and [string](Get-UaProp $r 'AppId') -eq $c.AppId) { $dup = $true } }
        if (-not $dup) { $launch.Add($c) }
    }
    foreach ($r in @(Get-UaProp $prev 'Shortcuts')) { if ($r) { $shortcuts.Add($r) } }
    foreach ($c in $ctx.ShortcutChanges) { $shortcuts.Add($c) }
    $archives = @()
    foreach ($a in $ctx.Installed) { $archives += @{ Part = $a.Part; Mode = $a.Mode; Name = $a.Name; Id = $a.FileId; Size = $a.Size } }
    $m = [ordered]@{
        Tool          = 'HL2-UA-Installer'
        Version       = $global:HL2UA_Config.Version
        InstalledAt   = (Get-Date).ToString('yyyy-MM-dd HH:mm')
        GameDir       = $ctx.GameDir
        Kind          = $ctx.Game.Kind
        Strategy      = $ctx.Strategy
        Archives      = $archives
        LaunchOptions = $launch.ToArray()
        Shortcuts     = $shortcuts.ToArray()
    }
    $path = Join-UaPath (Get-UaDataDir $ctx) 'manifest.json'
    [IO.File]::WriteAllText($path, ($m | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
    $readme = "Тут лежать службові файли українізатора Half-Life 2 (HamUA Studio):`r`n" +
    "журнал встановлених файлів і резервні копії оригіналів.`r`n" +
    "Щоб видалити українізатор, запустіть HL2-UA-Installer.cmd ще раз і виберіть «Видалити українізатор».`r`n"
    [IO.File]::WriteAllText((Join-UaPath (Get-UaDataDir $ctx) 'README.txt'), $readme, [Text.Encoding]::UTF8)
}

# ================================================================ elevation ====

function Get-UaHandoffPath {
    if (-not $env:ProgramData) { return $null }
    return (Join-UaPath $env:ProgramData 'HL2UA' 'handoff.json')
}

function Read-UaHandoff {
    if ($env:HL2UA_ARG -ne '--elevated') { return $null }
    $p = Get-UaHandoffPath
    if (-not $p -or -not [IO.File]::Exists($p)) { return $null }
    try {
        $h = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) | ConvertFrom-Json
        $age = [DateTime]::UtcNow.Ticks - [long](Get-UaProp $h 'CreatedTicks')
        if ($age -lt 0 -or $age -gt [TimeSpan]::FromMinutes(30).Ticks) { return $null }
        return $h
    } catch { return $null }
}

function Remove-UaHandoff {
    $p = Get-UaHandoffPath
    if ($p) { Remove-UaFileQuiet $p }
}

function Invoke-UaElevation($ctx) {
    $idx = Request-UaChoice -Title 'Потрібен дозвіл' -Text ("Папка гри захищена Windows:`n{0}`n`nЩоб записати туди українізатор, потрібен дозвіл адміністратора.`nЗараз Windows запитає дозвіл — натисніть «Так» (Yes).`nПісля цього встановлення продовжиться в новому вікні." -f $ctx.GameDir) -Buttons @('Продовжити', 'Скасувати')
    if ($idx -ne 0) { throw (New-UaError 91 'user declined elevation') }
    $p = Get-UaHandoffPath
    if (-not $p) { throw (New-UaError 42 'no ProgramData for handoff') }
    $h = @{ GameDir = $ctx.GameDir; Desktop = (Get-UaDesktop); LogPath = $global:HL2UA_State.LogPath; CreatedTicks = [DateTime]::UtcNow.Ticks }
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($p))
    [IO.File]::WriteAllText($p, ($h | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
    Write-UaLog 'Relaunching elevated'
    try { Start-Process -FilePath $env:HL2UA_SELF -ArgumentList '--elevated' -Verb RunAs -ErrorAction Stop | Out-Null }
    catch {
        Remove-UaHandoff
        throw (New-UaError 12 $_.Exception.Message $_.Exception)
    }
}

# ===================================================================== flow ====

function New-UaContext {
    return @{
        Warnings         = (New-Object System.Collections.Generic.List[string])
        Game             = $null
        GameDir          = $null
        IsSteam          = $false
        Parts            = @('hl2')
        Strategy         = 'full'
        Selection        = $null
        Journal          = (New-Object System.Collections.Generic.List[string])
        JournalPath      = $null
        Tracked          = (New-Object 'System.Collections.Generic.HashSet[string]')
        Installed        = (New-Object System.Collections.Generic.List[object])
        InstalledFull    = @{}
        InstalledText    = @{}
        LaunchChanges    = (New-Object System.Collections.Generic.List[object])
        ShortcutChanges  = (New-Object System.Collections.Generic.List[object])
        ReplacePrevious  = $false
        PreviousRemoved  = $false
        PreviousManifest = $null
        ManualFiles      = (New-Object System.Collections.Generic.List[string])
        Handoff          = $null
    }
}

function Test-UaPreflight($ctx) {
    Set-UaProgress -Detail 'Перевіряю систему...'
    $culture = ''
    try { $culture = [Globalization.CultureInfo]::CurrentUICulture.Name } catch { }
    Write-UaLog ('OS {0}; 64-bit OS: {1}; 64-bit process: {2}; PS {3}; CLR {4}; elevated: {5}; user: {6}; UI culture: {7}' -f [Environment]::OSVersion.VersionString, [Environment]::Is64BitOperatingSystem, [Environment]::Is64BitProcess, $PSVersionTable.PSVersion, [Environment]::Version, (Test-UaElevated), [Environment]::UserName, $culture)
    $rel = Get-UaRegValue 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' 'Release'
    if ($rel) {
        Write-UaLog ('.NET Framework release: ' + $rel)
        if ([int]$rel -lt 378389) { throw (New-UaError 14 ('.NET release ' + $rel)) }
    }
    if (-not ('System.IO.Compression.ZipFile' -as [type])) { throw (New-UaError 14 'System.IO.Compression.ZipFile is not available') }
    Enable-UaNetDefaults
}

function New-UaJob([string]$Part, [string]$Mode, $Entry, [bool]$Optional) {
    $id = $null
    $name = 'Half-Life 2 UKR (озвучення+текст).zip'
    if ($Entry) { $id = $Entry.Id; $name = $Entry.Name }
    $what = 'завантаження і встановлення'
    if ($Mode -eq 'text') { $what = 'переклад тексту' }
    return @{
        Key = 'job-' + $Part + '-' + $Mode; Part = $Part; Mode = $Mode; FileId = $id; Name = $name
        Optional = $Optional; Size = -1L; Url = $null; Title = (Get-UaPartName $Part) + ': ' + $what
    }
}

function Get-UaJobs($ctx) {
    $cfg = $global:HL2UA_Config
    Set-UaProgress -Detail 'Отримую список файлів українізатора з Google Drive...'
    $listing = @()
    try { $listing = @(Get-UaDriveListing) }
    catch {
        $info = Get-UaErrorInfo $_
        if ($info -and $info.Code -in 31, 32, 33, 91) { throw }
        Write-UaLog ('Listing failed: ' + (Format-UaError $_)) 'WARN'
        $listing = @()
    }
    foreach ($k in @($cfg.KnownFiles)) {
        if (-not $k) { continue }
        $dup = $false
        foreach ($e in $listing) { if ($e.Id -eq $k.Id) { $dup = $true } }
        if (-not $dup) { $listing += @{ Id = $k.Id; Name = $k.Name; Path = $k.Name; IsFolder = $false } }
    }
    foreach ($e in $listing) { Write-UaLog ('  drive: {0}{1} [{2}]' -f $e.Path, $(if ($e.IsFolder) { '/' } else { '' }), $e.Id) }
    $sel = Select-UaArchives -Listing $listing -Parts $ctx.Parts
    $ctx.Selection = $sel
    $jobs = @()
    $hl2 = $sel['hl2']
    if ($hl2.Full) { $jobs += New-UaJob 'hl2' 'full' $hl2.Full $false }
    elseif ($ctx.IsSteam -and $hl2.Text) {
        Write-UaLog 'No voice archive on Drive; using Steam Workshop voice + text archive'
        $ctx.Strategy = 'workshop'
        $jobs += New-UaJob 'hl2' 'text' $hl2.Text $false
    }
    elseif ($hl2.Unsupported) { throw (New-UaError 39 $hl2.Unsupported.Name) }
    else { $jobs += New-UaJob 'hl2' 'manual' $null $false }
    if ($cfg.IncludeEpisodes) {
        foreach ($part in @('ep1', 'ep2')) {
            if ($ctx.Parts -notcontains $part) { continue }
            $slot = $sel[$part]
            if ($slot.Full) { $jobs += New-UaJob $part 'full' $slot.Full $true }
            elseif ($slot.Text -and $ctx.IsSteam) { $jobs += New-UaJob $part 'text' $slot.Text $true }
            else {
                Write-UaLog ('No archive for ' + $part) 'WARN'
                $ctx.Warnings.Add(('Для «{0}» українізатор на Google Drive не знайдено — цю частину пропущено.' -f (Get-UaPartName $part)))
            }
        }
    }
    foreach ($j in $jobs) {
        if (-not $j.FileId) { continue }
        Set-UaProgress -Detail ('Перевіряю файл «{0}»...' -f $j.Name)
        try { Resolve-UaDriveFile $j }
        catch {
            $info = Get-UaErrorInfo $_
            if ($info -and $info.Code -in 31, 32, 33, 91) { throw }
            Write-UaLog ('Probe failed for {0}: {1}' -f $j.Name, (Format-UaError $_)) 'WARN'
        }
    }
    return $jobs
}

function Set-UaJobSteps([object[]]$Jobs) {
    $known = 0.0
    $unknown = 0
    foreach ($j in $Jobs) { if ($j.Size -gt 0) { $known += $j.Size } else { $unknown++ } }
    $avg = 1.0
    if ($known -gt 0 -and $Jobs.Count -gt $unknown) { $avg = $known / ($Jobs.Count - $unknown) }
    $sum = $known + $unknown * $avg
    $defs = @(
        @{ Key = 'check'; Title = ''; Weight = 2 },
        @{ Key = 'find'; Title = ''; Weight = 3 },
        @{ Key = 'online'; Title = ''; Weight = 2 }
    )
    foreach ($j in $Jobs) {
        $sz = $avg
        if ($j.Size -gt 0) { $sz = [double]$j.Size }
        $w = 85.0 / [Math]::Max(1, $Jobs.Count)
        if ($sum -gt 0) { $w = 85.0 * $sz / $sum }
        $defs += @{ Key = $j.Key; Title = $j.Title; Weight = [Math]::Max(1.0, $w) }
    }
    $defs += @{ Key = 'lang'; Title = 'Увімкнення української мови в грі'; Weight = 5 }
    $defs += @{ Key = 'cleanup'; Title = 'Прибирання тимчасових файлів'; Weight = 3 }
    Initialize-UaSteps $defs
}

# Скільки місця треба на диску гри; якщо бракує — жертвуємо епізодами.
function Select-UaJobsBySpace($ctx, [object[]]$Jobs) {
    $free = Get-UaFreeSpace $ctx.GameDir
    if ($free -lt 0) { return $Jobs }
    $gameRoot = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($ctx.GameDir))
    $tempRoot = ''
    try { $tempRoot = [IO.Path]::GetPathRoot([IO.Path]::GetTempPath()) } catch { }
    $kept = @($Jobs)
    while ($true) {
        $est = 0L
        $maxA = 0L
        foreach ($j in $kept) {
            $sz = 2GB
            if ($j.Size -gt 0) { $sz = [long]$j.Size }
            $est += [long]($sz * 1.3)
            if ($sz -gt $maxA) { $maxA = $sz }
        }
        $need = $est + 300MB
        if ($tempRoot -ieq $gameRoot) { $need += $maxA }
        Write-UaLog ('Space plan: need ~{0} on {1}, free {2}' -f $need, $gameRoot, $free)
        if ($free -ge $need) { return $kept }
        $optional = @($kept | Where-Object { $_.Optional })
        if ($optional.Count -eq 0) {
            $extra = 'Диск {0} — треба звільнити ще {1} (зараз вільно {2}, потрібно приблизно {3}).' -f $gameRoot.TrimEnd('\', '/'), (Format-UaSize ($need - $free)), (Format-UaSize $free), (Format-UaSize $need)
            throw (New-UaError -Code 41 -Detail $extra -Extra $extra)
        }
        $drop = $optional[-1]
        $ctx.Warnings.Add(('«{0}» пропущено: на диску замало місця.' -f (Get-UaPartName $drop.Part)))
        Write-UaLog ('Dropping optional job for space: ' + $drop.Key) 'WARN'
        $kept = @($kept | Where-Object { $_.Key -ne $drop.Key })
    }
}

function Get-UaWorkDirCandidates([string]$GameDir) {
    $list = New-Object System.Collections.Generic.List[string]
    $cands = @()
    try { $cands += Join-UaPath ([IO.Path]::GetTempPath()) 'HL2UA' } catch { }
    if ($GameDir) {
        try { $cands += Join-UaPath ([IO.Path]::GetPathRoot([IO.Path]::GetFullPath($GameDir))) 'HL2UA_temp' } catch { }
    }
    foreach ($d in @(Get-UaFixedDrives)) { $cands += Join-UaPath $d 'HL2UA_temp' }
    foreach ($c in $cands) {
        $dup = $false
        foreach ($x in $list) { if ($x -ieq $c) { $dup = $true } }
        if (-not $dup) { $list.Add($c) }
    }
    foreach ($x in $list) { $x }
}

function Get-UaDownloadFileName($Job) { return ('hl2ua_' + $Job.Part + '_' + $Job.FileId + '.zip') }

function Select-UaWorkDir($ctx, $Job) {
    $need = 3GB
    if ($Job.Size -gt 0) { $need = [long]$Job.Size }
    $fname = Get-UaDownloadFileName $Job
    $cands = @(Get-UaWorkDirCandidates $ctx.GameDir)
    foreach ($c in $cands) {
        if ([IO.File]::Exists((Join-UaPath $c ($fname + '.part'))) -or [IO.File]::Exists((Join-UaPath $c $fname))) { return $c }
    }
    foreach ($c in $cands) {
        $free = Get-UaFreeSpace $c
        if ($free -ge 0 -and $free -lt ($need + 200MB)) { continue }
        try {
            [void][IO.Directory]::CreateDirectory($c)
            if (Test-UaWritable $c) { return $c }
        } catch { }
    }
    $extra = 'Для тимчасового файлу потрібно {0} вільного місця на будь-якому диску.' -f (Format-UaSize ($need + 200MB))
    throw (New-UaError -Code 41 -Detail $extra -Extra $extra)
}

function Test-UaDownloadedFile([string]$Path, [bool]$Own) {
    Start-Sleep -Milliseconds 400
    if (-not [IO.File]::Exists($Path)) { throw (New-UaError 44 ('file vanished after download: ' + $Path)) }
    $type = 'unknown'
    try { $type = Get-UaArchiveType $Path }
    catch { throw (Convert-UaDiskError $_.Exception 44) }
    Write-UaLog ('Downloaded file type: ' + $type)
    if ($type -eq 'zip') {
        if (Test-UaZipOpens $Path) { return }
        if ($Own) { Remove-UaFileQuiet $Path }
        throw (New-UaError 38 'zip does not open')
    }
    if ($type -in '7z', 'rar') { throw (New-UaError 39 $type) }
    if ($Own) { Remove-UaFileQuiet $Path }
    if ($type -eq 'html') { throw (New-UaError 36 'got an html page instead of the archive') }
    throw (New-UaError 38 'unknown file type')
}

# Якщо архів уже лежить у «Завантаженнях» (наприклад, син скачав вручну) — беремо його.
function Find-UaLocalArchive($Job) {
    if ($Job.Mode -eq 'text') { return $null }
    $dirs = @((Get-UaDownloadsDir), (Get-UaDesktop)) | Where-Object { $_ -and [IO.Directory]::Exists($_) } | Select-Object -Unique
    foreach ($d in $dirs) {
        foreach ($f in @([IO.Directory]::GetFiles($d, '*.zip'))) {
            $info = Get-UaArchiveInfo ([IO.Path]::GetFileName($f))
            if ($info.Part -ne $Job.Part -or $info.Type -ne 'full') { continue }
            if ($Job.Size -gt 0 -and (New-Object IO.FileInfo($f)).Length -ne $Job.Size) { continue }
            if (Test-UaZipOpens $f) { Write-UaLog ('Using archive found locally: ' + $f); return $f }
        }
    }
    return $null
}

function Wait-UaManualDownload($Job, [datetime]$Since) {
    $dirs = @((Get-UaDownloadsDir), (Get-UaDesktop)) | Where-Object { $_ -and [IO.Directory]::Exists($_) } | Select-Object -Unique
    Write-UaLog ('Waiting for manual download in: ' + ($dirs -join '; '))
    $sizes = @{}
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalMinutes -lt 90) {
        Assert-UaNotCancelled
        $inProgress = 0L
        foreach ($d in $dirs) {
            foreach ($f in @([IO.Directory]::GetFiles($d))) {
                $fi = New-Object IO.FileInfo($f)
                $ext = $fi.Extension.ToLowerInvariant()
                if ($ext -in '.crdownload', '.part', '.partial', '.download', '.opdownload') {
                    if ($fi.LastWriteTime -gt $Since) { $inProgress += $fi.Length }
                    continue
                }
                if ($ext -ne '.zip') { continue }
                $info = Get-UaArchiveInfo $fi.Name
                if ($info.Part -ne $Job.Part -or $info.Type -eq 'text' -or $info.Type -eq 'textures') { continue }
                $k = $fi.FullName
                if ($sizes.ContainsKey($k) -and $sizes[$k] -eq $fi.Length -and $fi.Length -gt 1MB) {
                    if (Test-UaZipOpens $k) { return $k }
                }
                $sizes[$k] = $fi.Length
            }
        }
        $txt = 'Чекаю, поки файл завантажиться в папку «Завантаження»...'
        if ($inProgress -gt 0) { $txt += ' Уже завантажено ' + (Format-UaSize $inProgress) + '.' }
        Set-UaProgress -Detail $txt
        Start-UaSleep 3
    }
    throw (New-UaError 37 'manual download timed out')
}

function Get-UaArchiveManually($ctx, $Job) {
    $cfg = $global:HL2UA_Config
    $url = 'https://drive.google.com/drive/folders/' + $cfg.DriveFolderId
    if ($Job.FileId) { $url = $cfg.FileViewUrl -f $Job.FileId }
    $text = "Автоматично завантажити не вийшло, тому потрібна ваша допомога.`n`n" +
    "1. Натисніть «Відкрити браузер» — відкриється Google Drive з українізатором.`n" +
    ("2. Знайдіть файл «{0}» і завантажте його (кнопка зі стрілкою вниз або правою кнопкою → «Завантажити»).`n" -f $Job.Name) +
    "3. Якщо Google попередить, що файл великий, натисніть «Усе одно завантажити».`n`n" +
    'Далі я сам помічу завантажений файл і продовжу встановлення.'
    $idx = Request-UaChoice -Title 'Потрібна ваша допомога' -Text $text -Buttons @('Відкрити браузер', 'Скасувати')
    if ($idx -ne 0) { throw (New-UaError 91 'user declined manual download') }
    $since = Get-Date
    Invoke-UaShellOpen $url
    $f = Wait-UaManualDownload $Job $since
    if ((New-Object IO.FileInfo($f)).LastWriteTime -ge $since.AddMinutes(-1)) { $ctx.ManualFiles.Add($f) }
    return $f
}

function Invoke-UaJob($ctx, $Job) {
    $zip = $null
    $own = $false
    if ($Job.Mode -eq 'manual') {
        $zip = Find-UaLocalArchive $Job
        if (-not $zip) { $zip = Get-UaArchiveManually $ctx $Job }
    } else {
        $zip = Find-UaLocalArchive $Job
        if (-not $zip) {
            $own = $true
            for ($try = 1; $try -le 2; $try++) {
                $dir = Select-UaWorkDir $ctx $Job
                $out = Join-UaPath $dir (Get-UaDownloadFileName $Job)
                $reuse = [IO.File]::Exists($out) -and ($Job.Size -le 0 -or (New-Object IO.FileInfo($out)).Length -eq $Job.Size) -and (Test-UaZipOpens $out)
                if ($reuse) { Write-UaLog ('Reusing complete download: ' + $out) }
                else {
                    Write-UaLog ('Downloading {0} ({1}) to {2}' -f $Job.Name, $Job.FileId, $out)
                    Receive-UaDriveFile $Job $out
                }
                try { Test-UaDownloadedFile $out $true; $zip = $out; break }
                catch {
                    $info = Get-UaErrorInfo $_
                    if ($try -lt 2 -and $info -and $info.Code -eq 38) { Write-UaLog 'Corrupt download; retrying once' 'WARN'; continue }
                    throw
                }
            }
        }
    }
    if ($ctx.ReplacePrevious -and -not $ctx.PreviousRemoved) {
        Set-UaProgress -Detail 'Прибираю попередню версію українізатора...'
        Remove-UaInstalledFiles $ctx
        $ctx.PreviousRemoved = $true
    }
    Install-UaArchive $ctx $Job $zip
    if ($own) { Remove-UaFileQuiet $zip }
    if ($Job.Mode -eq 'text') { $ctx.InstalledText[$Job.Part] = $true } else { $ctx.InstalledFull[$Job.Part] = $true }
    $ctx.Installed.Add(@{ Part = $Job.Part; Mode = $Job.Mode; Name = $Job.Name; FileId = $Job.FileId; Size = $Job.Size })
}

# Обовʼязковий архів не вдалося взяти: пробуємо запасні шляхи.
function Get-UaFallbackJobs($ctx, $Job, $Err) {
    $info = Get-UaErrorInfo $Err
    $code = 19
    if ($info) { $code = $info.Code }
    if ($code -in 91, 31, 32, 33, 41, 42, 43, 44, 45, 51, 52) { throw $Err }
    $slot = $null
    if ($ctx.Selection) { $slot = $ctx.Selection[$Job.Part] }
    if ($ctx.IsSteam -and $Job.Mode -eq 'full' -and $slot -and $slot.Text -and $code -in 35, 36, 37, 38) {
        $idx = Request-UaChoice -Title 'Google Drive не віддає файл' -Text "Google Drive зараз не дає завантажити велику озвучку.`n`nМожна взяти озвучку прямо зі Steam (розділ «Майстерня») — це теж офіційний варіант від авторів. Від вас знадобиться одне натискання кнопки «Підписатися».`n`nПродовжити так?" -Buttons @('Так, через Steam', 'Ні')
        if ($idx -eq 0) {
            $ctx.Strategy = 'workshop'
            return @(New-UaJob $Job.Part 'text' $slot.Text $Job.Optional)
        }
    }
    if ($Job.Mode -eq 'full' -and $code -in 34, 36, 37, 38) {
        $m = New-UaJob $Job.Part 'manual' $null $Job.Optional
        $m.FileId = $Job.FileId
        $m.Name = $Job.Name
        $m.Size = $Job.Size
        return @($m)
    }
    throw $Err
}

function Invoke-UaFlow($ctx) {
    $cfg = $global:HL2UA_Config
    Initialize-UaSteps @(
        @{ Key = 'check'; Title = 'Перевірка компʼютера'; Weight = 2 },
        @{ Key = 'find'; Title = 'Пошук гри Half-Life 2'; Weight = 3 },
        @{ Key = 'online'; Title = 'Пошук українізатора в інтернеті'; Weight = 2 },
        @{ Key = 'work'; Title = 'Завантаження і встановлення'; Weight = 85 },
        @{ Key = 'lang'; Title = 'Увімкнення української мови в грі'; Weight = 5 },
        @{ Key = 'cleanup'; Title = 'Прибирання тимчасових файлів'; Weight = 3 }
    )

    Enter-UaStep 'check'
    Test-UaPreflight $ctx
    Complete-UaStep 'check'

    Enter-UaStep 'find'
    $game = $null
    $handoff = Read-UaHandoff
    if ($handoff) {
        $dir = [string](Get-UaProp $handoff 'GameDir')
        Write-UaLog ('Elevated instance; game dir from handoff: ' + $dir)
        if (Test-UaHl2Dir $dir) {
            foreach ($c in @(Get-UaSteamGameCandidates)) { if ($c.Dir -ieq $dir) { $game = $c; break } }
            if (-not $game) { $game = @{ Dir = $dir; Kind = 'other' } }
        }
    }
    if (-not $game) { $game = Find-UaGame }
    $ctx.Game = $game
    $ctx.GameDir = [string]$game.Dir
    $ctx.IsSteam = ($game.Kind -eq 'steam')
    Write-UaLog ('Game: {0} (kind: {1}, app: {2})' -f $ctx.GameDir, $game.Kind, (Get-UaProp $game 'AppId'))
    Set-UaProgress -Detail ('Знайдено гру: ' + $ctx.GameDir)
    if ($ctx.IsSteam) { Wait-UaSteamAppReady $game }
    Close-UaRunningGame $ctx
    if (-not (Test-UaWritable $ctx.GameDir) -or -not (Test-UaWritable (Join-UaPath $ctx.GameDir 'hl2'))) {
        Write-UaLog 'Game folder is not writable' 'WARN'
        if ((Test-UaElevated) -or -not $env:HL2UA_SELF) { throw (New-UaError 42 $ctx.GameDir) }
        Invoke-UaElevation $ctx
        return 'elevated'
    }
    $ctx.Parts = @(Get-UaGameParts $ctx.GameDir)
    Write-UaLog ('Game parts present: ' + ($ctx.Parts -join ', '))
    $prev = Get-UaPreviousInstall $ctx
    if ($prev) {
        if ($prev.Complete) {
            $when = [string](Get-UaProp $prev.Manifest 'InstalledAt')
            $q = "Український переклад уже встановлено ({0}).`n`nЩо зробити?" -f $when
        } else {
            $q = "Попереднє встановлення українізатора не завершилося.`n`nЩо зробити?"
        }
        $idx = Request-UaChoice -Title 'Українізатор уже є' -Text $q -Buttons @('Перевстановити', 'Видалити українізатор', 'Нічого не робити')
        if ($idx -eq 1) { return (Invoke-UaUninstallFlow $ctx $prev) }
        if ($idx -ne 0) { return 'noop' }
        $ctx.ReplacePrevious = $true
        if ($prev.Complete) { $ctx.PreviousManifest = $prev.Manifest }
    }
    Complete-UaStep 'find'

    Enter-UaStep 'online'
    Wait-UaInternet
    $jobs = @(Get-UaJobs $ctx)
    $jobs = @(Select-UaJobsBySpace $ctx $jobs)
    Set-UaJobSteps $jobs
    Complete-UaStep 'online'

    $queue = New-Object System.Collections.Queue
    foreach ($j in $jobs) { $queue.Enqueue($j) }
    while ($queue.Count -gt 0) {
        $job = $queue.Dequeue()
        Enter-UaStep $job.Key
        try {
            Invoke-UaJob $ctx $job
            Complete-UaStep $job.Key
        } catch {
            $err = $_
            $info = Get-UaErrorInfo $err
            if ($info -and $info.Code -eq 91) { throw }
            Write-UaLog ('Job {0} failed: {1}' -f $job.Key, (Format-UaError $err)) 'WARN'
            if ($job.Optional) {
                $code = 19
                if ($info) { $code = $info.Code }
                $ctx.Warnings.Add(('«{0}» не встановлено (помилка {1}). Решта працює.' -f (Get-UaPartName $job.Part), $code))
                Complete-UaStep $job.Key 'warn'
                continue
            }
            $replacement = @(Get-UaFallbackJobs $ctx $job $err)
            Write-UaLog ('Fallback for {0}: {1}' -f $job.Key, (($replacement | ForEach-Object { $_.Key }) -join ', '))
            $rest = @($queue.ToArray())
            $queue.Clear()
            foreach ($j in $replacement) { $queue.Enqueue($j) }
            foreach ($j in $rest) { $queue.Enqueue($j) }
            $rebuilt = @()
            foreach ($j in $jobs) { if ($j.Key -eq $job.Key) { $rebuilt += $replacement } else { $rebuilt += $j } }
            $jobs = $rebuilt
            Set-UaJobSteps $jobs
        }
    }

    Enter-UaStep 'lang'
    if ($ctx.IsSteam) { Update-UaSteamLaunchOptions $ctx 'add' $null }
    else { Set-UaShortcutLanguage $ctx }
    if ($ctx.Strategy -eq 'workshop') { Invoke-UaWorkshopSubscribe $ctx }
    Complete-UaStep 'lang'

    Enter-UaStep 'cleanup'
    Set-UaProgress -Detail 'Видаляю тимчасові файли...'
    Save-UaManifest $ctx
    Complete-UaStep 'cleanup'
    return 'installed'
}

function Save-UaErrorLog {
    $s = $global:HL2UA_State
    if (-not $s -or -not $s.LogPath) { return }
    $s.ErrorLogCopy = $s.LogPath
    $desk = Get-UaDesktop
    if (-not $desk) { return }
    $dst = Join-UaPath $desk $global:HL2UA_Config.LogFileName
    try { [IO.File]::Copy($s.LogPath, $dst, $true); $s.ErrorLogCopy = $dst } catch { }
}

function Invoke-UaFinalCleanup($ctx, [string]$Kind) {
    $s = $global:HL2UA_State
    if ($Kind -ne 'elevated') { Remove-UaHandoff }
    if ($Kind -in 'installed', 'uninstalled', 'noop') {
        if ($Kind -eq 'installed') {
            foreach ($d in @(Get-UaWorkDirCandidates $ctx.GameDir)) { Remove-UaDirQuiet $d }
            foreach ($f in $ctx.ManualFiles) { Remove-UaFileQuiet $f }
            if ($s -and $s.LogPath -and $ctx.GameDir) {
                try { [IO.File]::Copy($s.LogPath, (Join-UaPath (Get-UaDataDir $ctx) 'install-log.txt'), $true) } catch { }
            }
        }
        $desk = Get-UaDesktop
        if ($desk) { Remove-UaFileQuiet (Join-UaPath $desk $global:HL2UA_Config.LogFileName) }
    } elseif ($Kind -ne 'elevated') {
        Save-UaErrorLog
    }
}

function Invoke-UaWorkerMain {
    $ErrorActionPreference = 'Stop'
    $s = $global:HL2UA_State
    $ctx = New-UaContext
    $global:HL2UA_Ctx = $ctx
    $kind = 'error'
    try {
        Write-UaLog ('==== HL2 Ukrainian installer v{0} ====' -f $global:HL2UA_Config.Version)
        $kind = [string](Invoke-UaFlow $ctx)
        $exe = $null
        if ($ctx.GameDir) { $exe = Get-UaGameExe $ctx.GameDir }
        $s.Result = @{
            Kind = $kind; Warnings = @($ctx.Warnings); Strategy = $ctx.Strategy; IsSteam = $ctx.IsSteam
            GameDir = $ctx.GameDir; Exe = $exe; Parts = @($ctx.Parts); InstalledFull = @($ctx.InstalledFull.Keys)
        }
        Write-UaLog ('RESULT: ' + $kind)
    } catch {
        $err = $_
        $info = Get-UaErrorInfo $err
        $code = 19
        $extra = ''
        if ($info) { $code = $info.Code; $extra = $info.Extra }
        $stepTitle = ''
        $st = Get-UaStep ([string]$s.CurrentKey)
        if ($st) { $stepTitle = $st.Title; if ($code -ne 91) { $st.Status = 'fail' } }
        Write-UaLog ('FAILED with code {0} at "{1}": {2}' -f $code, $stepTitle, (Format-UaError $err)) 'ERROR'
        if ($code -eq 91) { $kind = 'cancelled' } else { $kind = 'error' }
        $s.Result = @{ Kind = $kind; Code = $code; Extra = $extra; StepTitle = $stepTitle; Warnings = @($ctx.Warnings) }
    } finally {
        try { Invoke-UaFinalCleanup $ctx $kind } catch { Write-UaLog ('Final cleanup failed: ' + $_.Exception.Message) 'WARN' }
        $s.Done = $true
        Update-UaState
    }
}

# ======================================================================= UI ====

function New-UaFont([double]$Size, [string]$Style = 'Regular', [string]$Family = 'Segoe UI') {
    return (New-Object System.Drawing.Font($Family, [single]$Size, [System.Drawing.FontStyle]$Style))
}

function New-UaLabel([string]$Text, $Font, $Color, [int]$X, [int]$Y, [int]$W, [int]$H) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Font = $Font
    $l.ForeColor = $Color
    $l.SetBounds($X, $Y, $W, $H)
    $l.AutoSize = $false
    return $l
}

function New-UaButton([string]$Text, [bool]$Primary = $false) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Font = New-UaFont 11
    $b.Height = 42
    $b.Width = [Math]::Max(130, [System.Windows.Forms.TextRenderer]::MeasureText($Text, $b.Font).Width + 36)
    $b.Margin = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
    $b.UseVisualStyleBackColor = -not $Primary
    if ($Primary) {
        $b.BackColor = [System.Drawing.Color]::FromArgb(0, 87, 183)
        $b.ForeColor = [System.Drawing.Color]::White
        $b.FlatStyle = 'Flat'
        $b.FlatAppearance.BorderSize = 0
    }
    $b.Visible = $false
    return $b
}

function Show-UaDialog {
    param($Owner, [string]$Title, [string]$Text, [string[]]$Buttons = @('OK'))
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = $Title
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.ShowInTaskbar = ($null -eq $Owner)
    $dlg.StartPosition = 'CenterParent'
    $dlg.BackColor = [System.Drawing.Color]::White
    $dlg.Font = New-UaFont 11
    $dlg.Tag = -1
    $w = 560
    $flags = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::TextBoxControl
    $h = [System.Windows.Forms.TextRenderer]::MeasureText($Text, $dlg.Font, (New-Object System.Drawing.Size($w, 0)), $flags).Height + 8
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.Font = $dlg.Font
    $lbl.AutoSize = $false
    $lbl.SetBounds(24, 22, $w, $h)
    $dlg.Controls.Add($lbl)
    $y = 22 + $h + 22
    $x = 24 + $w
    for ($i = $Buttons.Count - 1; $i -ge 0; $i--) {
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $Buttons[$i]
        $b.Font = $dlg.Font
        $bw = [Math]::Max(120, [System.Windows.Forms.TextRenderer]::MeasureText($b.Text, $b.Font).Width + 36)
        $x -= $bw
        $b.SetBounds($x, $y, $bw, 40)
        $x -= 10
        $b.Tag = $i
        $b.Add_Click({ $f = $this.FindForm(); $f.Tag = [int]$this.Tag; $f.Close() })
        $dlg.Controls.Add($b)
        if ($i -eq 0) {
            $dlg.AcceptButton = $b
            $b.BackColor = [System.Drawing.Color]::FromArgb(0, 87, 183)
            $b.ForeColor = [System.Drawing.Color]::White
            $b.FlatStyle = 'Flat'
            $b.FlatAppearance.BorderSize = 0
        }
    }
    $dlg.ClientSize = New-Object System.Drawing.Size((24 + $w + 24), ($y + 40 + 22))
    $dlg.Add_Shown({ $this.Activate() })
    if ($global:HL2UA_Config.AutoDialogMs -gt 0) {
        # Лише для автотестів: «натискаємо» першу кнопку.
        $t = New-Object System.Windows.Forms.Timer
        $t.Interval = [int]$global:HL2UA_Config.AutoDialogMs
        $t.Tag = $dlg
        $t.Add_Tick({ $this.Stop(); $this.Tag.Tag = 0; $this.Tag.Close() })
        $t.Start()
    }
    try { [System.Media.SystemSounds]::Asterisk.Play() } catch { }
    if ($Owner) { [void]$dlg.ShowDialog($Owner) } else { $dlg.TopMost = $true; [void]$dlg.ShowDialog() }
    $res = [int]$dlg.Tag
    $dlg.Dispose()
    return $res
}

# Службове чорне вікно згортаємо, щойно зʼявилося наше (щоб його випадково не закрили).
function Initialize-UaConsoleApi {
    try {
        if (-not ('HL2UA.Native' -as [type])) {
            Add-Type -Namespace 'HL2UA' -Name 'Native' -MemberDefinition '[DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);' -ErrorAction Stop
        }
    } catch { Write-UaLog ('Console API unavailable: ' + $_.Exception.Message) 'WARN' }
}

function Set-UaConsoleWindow([int]$Cmd) {
    try {
        if (-not ('HL2UA.Native' -as [type])) { return }
        $h = [HL2UA.Native]::GetConsoleWindow()
        if ($h -ne [IntPtr]::Zero) { [void][HL2UA.Native]::ShowWindow($h, $Cmd) }
    } catch { }
}

function Start-UaWorker {
    $ui = $global:HL2UA_Ui
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = [System.Threading.ApartmentState]::STA
    $rs.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('HL2UA_State', $global:HL2UA_State)
    $rs.SessionStateProxy.SetVariable('HL2UA_ScriptText', $global:HL2UA_ScriptText)
    $rs.SessionStateProxy.SetVariable('HL2UA_LIBRARY_ONLY', $true)
    $rs.SessionStateProxy.SetVariable('HL2UA_ConfigOverride', $global:HL2UA_Config)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript('. ([ScriptBlock]::Create($HL2UA_ScriptText)); $global:HL2UA_Config = $HL2UA_ConfigOverride; Invoke-UaWorkerMain')
    $ui.WorkerRS = $rs
    $ui.WorkerPS = $ps
    $ui.WorkerHandle = $ps.BeginInvoke()
}

function Stop-UaWorker {
    $ui = $global:HL2UA_Ui
    try {
        if ($ui.WorkerPS) {
            if ($ui.WorkerHandle -and -not $ui.WorkerHandle.IsCompleted) { $ui.WorkerPS.Stop() }
            $ui.WorkerPS.Dispose()
        }
        if ($ui.WorkerRS) { $ui.WorkerRS.Dispose() }
    } catch { }
    $ui.WorkerPS = $null
    $ui.WorkerRS = $null
    $ui.WorkerHandle = $null
}

function Set-UaButtons([string[]]$Names) {
    $ui = $global:HL2UA_Ui
    foreach ($k in @('BtnCancel', 'BtnClose', 'BtnRetry', 'BtnLog', 'BtnPlay', 'BtnTime')) { $ui[$k].Visible = ($Names -contains $k) }
}

function Update-UaUi {
    $ui = $global:HL2UA_Ui
    $s = $global:HL2UA_State
    $steps = @($s.Steps)
    $glyph = @{ pending = [string][char]0x25CB; running = [string][char]0x25BA; done = [string][char]0x2714; warn = '!'; fail = [string][char]0x2716; skip = [string][char]0x2013 }
    for ($i = 0; $i -lt $ui.Icons.Count; $i++) {
        if ($i -lt $steps.Count) {
            $st = $steps[$i]
            $status = [string]$st.Status
            $ui.Icons[$i].Text = $glyph[$status]
            $ui.Icons[$i].ForeColor = $ui.Colors[$status]
            $ui.Labels[$i].Text = [string]$st.Title
            if ($status -eq 'running') { $ui.Labels[$i].Font = $ui.FontStepBold; $ui.Labels[$i].ForeColor = $ui.Colors.text }
            else {
                $ui.Labels[$i].Font = $ui.FontStep
                if ($status -eq 'pending') { $ui.Labels[$i].ForeColor = $ui.Colors.pending } else { $ui.Labels[$i].ForeColor = $ui.Colors.text }
            }
            $ui.Icons[$i].Visible = $true
            $ui.Labels[$i].Visible = $true
        } else {
            $ui.Icons[$i].Visible = $false
            $ui.Labels[$i].Visible = $false
        }
    }
    $pct = Get-UaOverallPercent $s
    $pct = [Math]::Max(0, [Math]::Min(100, $pct))
    $ui.Bar.Value = $pct
    $ui.Pct.Text = 'Виконано: ' + $pct + '%'
    $ui.Detail.Text = [string]$s.Detail
}

function Show-UaResult {
    $ui = $global:HL2UA_Ui
    $s = $global:HL2UA_State
    $r = $s.Result
    Update-UaUi
    if (-not $r) { $r = @{ Kind = 'error'; Code = 19 } }
    if ($r.Kind -eq 'elevated') { $ui.Form.Close(); return }
    $body = ''
    $warnings = @($r.Warnings)
    switch ($r.Kind) {
        'installed' {
            $ui.ResTitle.Text = 'ГОТОВО! Українізатор встановлено.'
            $ui.ResTitle.ForeColor = $ui.Colors.done
            if ($r.IsSteam) { $body = 'Запускайте Half-Life 2 як завжди — через Steam.' }
            else { $body = 'Запускайте Half-Life 2 як завжди.' }
            $body += "`r`nОзвучення, субтитри, меню й написи в грі тепер українською."
            $eps = @($r.InstalledFull | Where-Object { $_ -ne 'hl2' })
            if ($eps.Count -gt 0) { $body += "`r`nЕпізоди теж українською." }
            $body += "`r`nСубтитри вмикаються в налаштуваннях гри (розділ звуку)."
            $ui.ResSay.Text = 'Приємної гри!'
            $ui.ResSay.ForeColor = $ui.Colors.done
            Set-UaButtons @('BtnClose', 'BtnPlay')
            $ui.Form.AcceptButton = $ui.BtnPlay
        }
        'uninstalled' {
            $ui.ResTitle.Text = 'Українізатор видалено.'
            $ui.ResTitle.ForeColor = $ui.Colors.done
            $body = 'Гра знову англійською, як була до встановлення.'
            $ui.ResSay.Text = ''
            Set-UaButtons @('BtnClose')
        }
        'noop' {
            $ui.ResTitle.Text = 'Нічого не змінено.'
            $ui.ResTitle.ForeColor = $ui.Colors.text
            $body = 'Українізатор залишився як був.'
            $ui.ResSay.Text = ''
            Set-UaButtons @('BtnClose')
        }
        'cancelled' {
            $ui.ResTitle.Text = 'Встановлення скасовано.'
            $ui.ResTitle.ForeColor = $ui.Colors.warn
            $body = 'Гру не змінено. Щоб встановити українізатор, запустіть файл ще раз — уже завантажене не пропаде.'
            $ui.ResSay.Text = ''
            Set-UaButtons @('BtnClose', 'BtnRetry')
        }
        default {
            $code = [int]$r.Code
            $e = $global:HL2UA_Errors[$code]
            if (-not $e) { $e = $global:HL2UA_Errors[19] }
            $ui.ResTitle.Text = 'ПОМИЛКА ' + $code
            $ui.ResTitle.ForeColor = $ui.Colors.fail
            $body = $e[0] + "`r`n`r`nЩо робити: " + $e[1]
            if ($r.Extra) { $body += "`r`n`r`n" + $r.Extra }
            if ($r.StepTitle) { $body += "`r`n`r`nЕтап: " + $r.StepTitle }
            $ui.ResSay.Text = 'Скажіть синові: «помилка ' + $code + '»'
            $ui.ResSay.ForeColor = $ui.Colors.fail
            $btns = @('BtnClose', 'BtnRetry', 'BtnLog')
            if ($code -eq 32) { $btns += 'BtnTime' }
            Set-UaButtons $btns
            $ui.Form.AcceptButton = $ui.BtnRetry
        }
    }
    if ($warnings.Count -gt 0) {
        $body += "`r`n`r`nЗверніть увагу:"
        foreach ($w in $warnings) { $body += "`r`n• " + $w }
    }
    $ui.ResBody.Text = $body
    $logText = ''
    if ($r.Kind -eq 'error' -and $s.ErrorLogCopy) { $logText = 'Подробиці для сина збережено у файлі: ' + $s.ErrorLogCopy }
    $ui.ResLog.Text = $logText
    foreach ($c in @($ui.Icons) + @($ui.Labels)) { $c.Visible = $false }
    $ui.Pct.Visible = $false
    $ui.Bar.Visible = $false
    $ui.Detail.Visible = $false
    $ui.ResultPanel.Visible = $true
    $ui.ResultPanel.BringToFront()
    try { $ui.Form.Activate() } catch { }
    if ($global:HL2UA_Config.AutoCloseMs -gt 0) {
        $t = New-Object System.Windows.Forms.Timer
        $t.Interval = [int]$global:HL2UA_Config.AutoCloseMs
        $t.Add_Tick({ $this.Stop(); $global:HL2UA_Ui.Form.Close() })
        $t.Start()
    }
}

function Invoke-UaUiTick {
    $ui = $global:HL2UA_Ui
    $s = $global:HL2UA_State
    if ($global:HL2UA_InPrompt) { return }
    try {
        if ($s.Version -ne $ui.LastVersion -and -not $ui.Finished) {
            $ui.LastVersion = $s.Version
            Update-UaUi
        }
        $p = $s.Prompt
        if ($p -and $p.Id -ne $ui.LastPromptId) {
            $ui.LastPromptId = $p.Id
            $ui.Timer.Stop()
            $global:HL2UA_InPrompt = $true
            $idx = -1
            try { $idx = Show-UaDialog -Owner $ui.Form -Title $p.Title -Text $p.Text -Buttons $p.Buttons }
            catch { Write-UaLog ('Dialog failed: ' + $_.Exception.Message) 'ERROR' }
            finally { $global:HL2UA_InPrompt = $false }
            $s.PromptAnswer = @{ Id = $p.Id; Index = $idx }
            $ui.Timer.Start()
        }
        if (-not $ui.Finished) {
            if ($s.Done) {
                $ui.Finished = $true
                Show-UaResult
            } elseif ($ui.WorkerHandle -and $ui.WorkerHandle.IsCompleted) {
                $errs = @()
                try { [void]$ui.WorkerPS.EndInvoke($ui.WorkerHandle) } catch { $errs += $_.Exception.ToString() }
                try { foreach ($e in $ui.WorkerPS.Streams.Error) { $errs += $e.ToString() } } catch { }
                Write-UaLog ('Worker ended unexpectedly: ' + ($errs -join ' | ')) 'ERROR'
                $s.Result = @{ Kind = 'error'; Code = 19; Extra = ''; StepTitle = '' }
                Save-UaErrorLog
                $s.Done = $true
                $ui.Finished = $true
                Show-UaResult
            }
        }
    } catch { Write-UaLog ('UI tick error: ' + $_.Exception.Message) 'ERROR' }
}

function Restart-UaWorker {
    $ui = $global:HL2UA_Ui
    $s = $global:HL2UA_State
    Stop-UaWorker
    Write-UaLog '===== RETRY ====='
    $s.Steps = @()
    $s.Done = $false
    $s.Result = $null
    $s.Cancel = $false
    $s.Detail = ''
    $s.Prompt = $null
    $s.PromptAnswer = $null
    $s.StepFraction = 0.0
    $s.ErrorLogCopy = $null
    $ui.Finished = $false
    $ui.LastVersion = -1
    $ui.ResultPanel.Visible = $false
    $ui.Pct.Visible = $true
    $ui.Bar.Visible = $true
    $ui.Detail.Visible = $true
    Set-UaButtons @('BtnCancel')
    Update-UaState
    Start-UaWorker
}

function Start-UaGame {
    $r = $global:HL2UA_State.Result
    if ($r.IsSteam) { Start-Process ('steam://rungameid/' + $global:HL2UA_Config.SteamAppId) | Out-Null; return }
    if ($r.Exe) { Start-Process -FilePath $r.Exe -ArgumentList $global:HL2UA_Config.LaunchArgs -WorkingDirectory $r.GameDir | Out-Null }
}

function Show-UaMainWindow {
    $ui = @{ LastVersion = -1; LastPromptId = 0; Finished = $false; WorkerPS = $null; WorkerRS = $null; WorkerHandle = $null }
    $global:HL2UA_Ui = $ui
    $global:HL2UA_InPrompt = $false
    $blue = [System.Drawing.Color]::FromArgb(0, 87, 183)
    $yellow = [System.Drawing.Color]::FromArgb(255, 213, 0)
    $ui.Colors = @{
        pending = [System.Drawing.Color]::FromArgb(160, 160, 160)
        running = $blue
        done    = [System.Drawing.Color]::FromArgb(25, 135, 60)
        warn    = [System.Drawing.Color]::FromArgb(220, 130, 0)
        fail    = [System.Drawing.Color]::FromArgb(205, 35, 35)
        skip    = [System.Drawing.Color]::FromArgb(160, 160, 160)
        text    = [System.Drawing.Color]::FromArgb(35, 35, 35)
        muted   = [System.Drawing.Color]::FromArgb(95, 95, 95)
    }
    $ui.FontStep = New-UaFont 12
    $ui.FontStepBold = New-UaFont 12 'Bold'

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Українізатор Half-Life 2'
    $form.ClientSize = New-Object System.Drawing.Size(720, 600)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::White
    $form.Font = New-UaFont 10
    $ui.Form = $form

    $header = New-Object System.Windows.Forms.Panel
    $header.SetBounds(0, 0, 720, 84)
    $header.BackColor = $blue
    $form.Controls.Add($header)
    $title = New-UaLabel 'Українізатор Half-Life 2' (New-UaFont 20 'Bold') ([System.Drawing.Color]::White) 20 8 680 42
    $title.BackColor = $blue
    $header.Controls.Add($title)
    $sub = New-UaLabel 'Українське озвучення і переклад від HamUA Studio' (New-UaFont 10.5) $yellow 23 52 680 24
    $sub.BackColor = $blue
    $header.Controls.Add($sub)
    $stripe = New-Object System.Windows.Forms.Panel
    $stripe.SetBounds(0, 84, 720, 6)
    $stripe.BackColor = $yellow
    $form.Controls.Add($stripe)

    $ui.Icons = @()
    $ui.Labels = @()
    for ($i = 0; $i -lt 9; $i++) {
        $y = 104 + $i * 33
        $ic = New-UaLabel '' (New-UaFont 13 'Regular' 'Segoe UI Symbol') $ui.Colors.pending 26 $y 30 30
        $ic.TextAlign = 'MiddleCenter'
        $ic.Visible = $false
        $lb = New-UaLabel '' $ui.FontStep $ui.Colors.pending 60 $y 640 30
        $lb.TextAlign = 'MiddleLeft'
        $lb.AutoEllipsis = $true
        $lb.Visible = $false
        $form.Controls.Add($ic)
        $form.Controls.Add($lb)
        $ui.Icons += $ic
        $ui.Labels += $lb
    }
    $ui.Pct = New-UaLabel 'Виконано: 0%' (New-UaFont 11 'Bold') $ui.Colors.text 26 408 668 24
    $form.Controls.Add($ui.Pct)
    $bar = New-Object System.Windows.Forms.ProgressBar
    $bar.SetBounds(26, 434, 668, 28)
    $bar.Minimum = 0
    $bar.Maximum = 100
    $form.Controls.Add($bar)
    $ui.Bar = $bar
    $ui.Detail = New-UaLabel 'Зачекайте...' (New-UaFont 10) $ui.Colors.muted 26 468 668 52
    $form.Controls.Add($ui.Detail)

    $rp = New-Object System.Windows.Forms.Panel
    $rp.SetBounds(20, 96, 680, 428)
    $rp.BackColor = [System.Drawing.Color]::White
    $rp.Visible = $false
    $form.Controls.Add($rp)
    $ui.ResultPanel = $rp
    $ui.ResTitle = New-UaLabel '' (New-UaFont 18 'Bold') $ui.Colors.text 4 6 672 44
    $rp.Controls.Add($ui.ResTitle)
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true
    $tb.ReadOnly = $true
    $tb.BorderStyle = 'None'
    $tb.BackColor = [System.Drawing.Color]::White
    $tb.ScrollBars = 'Vertical'
    $tb.Font = New-UaFont 12
    $tb.SetBounds(6, 58, 668, 272)
    $tb.TabStop = $false
    $rp.Controls.Add($tb)
    $ui.ResBody = $tb
    $ui.ResSay = New-UaLabel '' (New-UaFont 15 'Bold') $ui.Colors.fail 4 338 672 34
    $rp.Controls.Add($ui.ResSay)
    $ui.ResLog = New-UaLabel '' (New-UaFont 9) $ui.Colors.muted 6 378 668 46
    $rp.Controls.Add($ui.ResLog)

    $flow = New-Object System.Windows.Forms.FlowLayoutPanel
    $flow.FlowDirection = 'RightToLeft'
    $flow.WrapContents = $false
    $flow.SetBounds(20, 540, 680, 50)
    $form.Controls.Add($flow)
    $ui.BtnClose = New-UaButton 'Закрити'
    $ui.BtnPlay = New-UaButton 'Запустити гру' $true
    $ui.BtnRetry = New-UaButton 'Спробувати ще раз' $true
    $ui.BtnLog = New-UaButton 'Відкрити журнал'
    $ui.BtnTime = New-UaButton 'Налаштувати час'
    $ui.BtnCancel = New-UaButton 'Скасувати'
    foreach ($b in @($ui.BtnClose, $ui.BtnPlay, $ui.BtnRetry, $ui.BtnLog, $ui.BtnTime, $ui.BtnCancel)) { $flow.Controls.Add($b) }
    $ui.BtnCancel.Visible = $true

    $ui.BtnClose.Add_Click({ $global:HL2UA_Ui.Form.Close() })
    $ui.BtnCancel.Add_Click({ $global:HL2UA_Ui.Form.Close() })
    $ui.BtnRetry.Add_Click({ try { Restart-UaWorker } catch { Write-UaLog ('Retry failed: ' + $_.Exception.Message) 'ERROR' } })
    $ui.BtnLog.Add_Click({
            try {
                $p = $global:HL2UA_State.ErrorLogCopy
                if (-not $p) { $p = $global:HL2UA_State.LogPath }
                Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $p + '"') | Out-Null
            } catch { }
        })
    $ui.BtnPlay.Add_Click({ try { Start-UaGame } catch { }; $global:HL2UA_Ui.Form.Close() })
    $ui.BtnTime.Add_Click({ try { Start-Process 'ms-settings:dateandtime' | Out-Null } catch { try { Start-Process 'timedate.cpl' | Out-Null } catch { } } })

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 150
    $timer.Add_Tick({ Invoke-UaUiTick })
    $ui.Timer = $timer

    $form.Add_Shown({
            try {
                $f = $global:HL2UA_Ui.Form
                $f.TopMost = $true
                $f.Activate()
                $f.TopMost = $false
                Set-UaConsoleWindow 6
                Start-UaWorker
                $global:HL2UA_Ui.Timer.Start()
            } catch { Write-UaLog ('UI start failed: ' + $_.Exception.Message) 'ERROR' }
        })
    $form.Add_FormClosing({
            param($sender, $e)
            try {
                $s = $global:HL2UA_State
                if ($s.Done -or -not $global:HL2UA_Ui.WorkerHandle) { return }
                $e.Cancel = $true
                if ($s.Cancel -or $global:HL2UA_InPrompt) { return }
                $global:HL2UA_InPrompt = $true
                $idx = -1
                try { $idx = Show-UaDialog -Owner $sender -Title 'Перервати?' -Text "Перервати встановлення українізатора?`n`nУже завантажене збережеться — наступного разу завантаження продовжиться з місця зупинки." -Buttons @('Так, перервати', 'Ні, продовжити') }
                finally { $global:HL2UA_InPrompt = $false }
                if ($idx -eq 0) {
                    $s.Cancel = $true
                    try { $req = $s.ActiveRequest; if ($req) { $req.Abort() } } catch { }
                    $s.Detail = 'Скасовую... Зачекайте кілька секунд.'
                    $s.Version = [int]$s.Version + 1
                }
            } catch { }
        })

    [void]$form.ShowDialog()
    $timer.Stop()
    Stop-UaWorker
    $r = $global:HL2UA_State.Result
    if (-not $r) { return 91 }
    switch ([string]$r.Kind) {
        'error' { return [int]$r.Code }
        'cancelled' { return 91 }
    }
    return 0
}

# ==================================================================== entry ====

function Start-HL2UA {
    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
    Write-Host ''
    Write-Host '  Українізатор Half-Life 2 (озвучення HamUA Studio)' -ForegroundColor Cyan
    Write-Host '  Це службове вікно. Не закривайте його — зараз відкриється вікно встановлення.' -ForegroundColor Yellow
    Write-Host ''
    if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
        Write-Host '  ПОМИЛКА 11: Windows обмежує роботу PowerShell на цьому компʼютері.' -ForegroundColor Red
        Write-Host '  Скажіть синові: «помилка 11».' -ForegroundColor Red
        return 250
    }
    # Лише для автотестів у CI: підміна адрес і тайм-аутів з JSON-файлу.
    if ($env:HL2UA_TEST_OVERRIDES -and [IO.File]::Exists($env:HL2UA_TEST_OVERRIDES)) {
        $ov = [IO.File]::ReadAllText($env:HL2UA_TEST_OVERRIDES, [Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($prop in $ov.PSObject.Properties) { $global:HL2UA_Config[$prop.Name] = $prop.Value }
    }
    $state = New-UaState
    $global:HL2UA_State = $state
    $handoff = Read-UaHandoff
    $logDir = Join-UaPath ([IO.Path]::GetTempPath()) 'HL2UA-logs'
    try { [void][IO.Directory]::CreateDirectory($logDir) } catch { $logDir = [IO.Path]::GetTempPath() }
    $state.LogPath = Join-UaPath $logDir ('hl2ua-' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.log')
    $state.Desktop = [Environment]::GetFolderPath('Desktop')
    if ($handoff) {
        $hl = [string](Get-UaProp $handoff 'LogPath')
        if ($hl -and [IO.Directory]::Exists([IO.Path]::GetDirectoryName($hl))) { $state.LogPath = $hl }
        $hd = [string](Get-UaProp $handoff 'Desktop')
        if ($hd -and [IO.Directory]::Exists($hd)) { $state.Desktop = $hd }
    }
    Write-UaLog ('Launcher: {0}; arg: {1}' -f $env:HL2UA_SELF, $env:HL2UA_ARG)

    $mutex = $null
    $owned = $false
    try {
        $mutex = New-Object System.Threading.Mutex($false, 'Global\HL2UA_Installer')
        $wait = 0
        if ($handoff) { $wait = 30000 }
        try { $owned = $mutex.WaitOne($wait) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
    } catch { $owned = $true }

    try {
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            Add-Type -AssemblyName System.Drawing -ErrorAction Stop
            [System.Windows.Forms.Application]::EnableVisualStyles()
        } catch {
            Write-UaLog ('WinForms unavailable: ' + $_.Exception.Message) 'ERROR'
            Write-Host '  ПОМИЛКА 14: не вдалося відкрити вікно встановлення (бракує компонентів Windows).' -ForegroundColor Red
            Write-Host '  Скажіть синові: «помилка 14».' -ForegroundColor Red
            return 250
        }
        if (-not $owned) {
            [void](Show-UaDialog -Owner $null -Title 'Українізатор Half-Life 2' -Text ("Українізатор уже запущено в іншому вікні.`n`nДочекайтеся, поки воно завершить роботу.`n(Код: 13)") -Buttons @('Зрозуміло'))
            return 13
        }
        Initialize-UaConsoleApi
        $code = [int](Show-UaMainWindow | Select-Object -Last 1)
        Write-UaLog ('Exit code: ' + $code)
        $r = $state.Result
        if ($r -and $r.Kind -in 'installed', 'uninstalled', 'noop') {
            Remove-UaFileQuiet $state.LogPath
            Remove-UaEmptyDir $logDir
        }
        return $code
    } finally {
        if ($mutex) {
            if ($owned) { try { $mutex.ReleaseMutex() } catch { } }
            $mutex.Dispose()
        }
    }
}

if (-not $global:HL2UA_LIBRARY_ONLY) {
    $hl2uaExitCode = 19
    try { $hl2uaExitCode = [int](Start-HL2UA | Select-Object -Last 1) }
    catch {
        try { Write-UaLog ('Fatal: ' + (Format-UaError $_)) 'ERROR'; Save-UaErrorLog } catch { }
        Write-Host ('  ПОМИЛКА 19: ' + $_.Exception.Message) -ForegroundColor Red
        Write-Host '  Скажіть синові: «помилка 19».' -ForegroundColor Red
        $hl2uaExitCode = 250
    }
    exit $hl2uaExitCode
}
