# Тести для HL2-UA-Installer.cmd.
#   Linux/macOS:  pwsh -File tools/hl2-ua/tests/run-tests.ps1
#   Windows:      powershell.exe -ExecutionPolicy Bypass -File tools\hl2-ua\tests\run-tests.ps1 [-Gui]
# Працює і в Windows PowerShell 5.1, і в PowerShell 7. Інтеграційні сценарії
# піднімають фейковий Google Drive (tests/fake_drive.py) і фейкові Steam + гру.
param([switch]$SkipIntegration, [switch]$Gui)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$installer = [IO.Path]::GetFullPath([IO.Path]::Combine($here, '..', 'HL2-UA-Installer.cmd'))
$global:HL2UA_LIBRARY_ONLY = $true
$global:HL2UA_ScriptText = [IO.File]::ReadAllText($installer, [Text.Encoding]::UTF8)
. ([ScriptBlock]::Create($global:HL2UA_ScriptText))

$script:Pass = 0
$script:Fail = 0
$script:Failures = New-Object System.Collections.Generic.List[string]
$sep = [IO.Path]::DirectorySeparatorChar

function Add-Failure([string]$Msg) {
    $script:Fail++
    $script:Failures.Add($Msg)
    Write-Host ('    FAIL: ' + $Msg) -ForegroundColor Red
}
function Assert-Eq($Actual, $Expected, [string]$Msg) {
    if ($Actual -ceq $Expected) { $script:Pass++ } else { Add-Failure ("{0}`n      expected: [{1}]`n      actual:   [{2}]" -f $Msg, $Expected, $Actual) }
}
function Assert-True($Cond, [string]$Msg) { if ($Cond) { $script:Pass++ } else { Add-Failure $Msg } }
function Test-Case([string]$Name, [scriptblock]$Body) {
    Write-Host ('- ' + $Name)
    try { & $Body } catch { Add-Failure ('{0}: exception {1} {2}' -f $Name, $_.Exception.Message, $_.ScriptStackTrace) }
}
function P([string]$Base) {
    $p = $Base
    foreach ($x in $args) { $p = [IO.Path]::Combine($p, ([string]$x).Replace('/', $sep)) }
    return $p
}
function Write-Text([string]$Path, [string]$Text) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}
function Read-Text([string]$Path) { return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
function New-RandomBytes([int]$Count, [int]$Seed) {
    $b = New-Object byte[] $Count
    (New-Object Random $Seed).NextBytes($b)
    return , $b
}
function New-TestZip([string]$Path, [object[]]$Entries) {
    # $Entries: @(@('name', <string|byte[]|$null for dir>), ...)
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    $fs = [IO.File]::Create($Path)
    $zip = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($e in $Entries) {
            $entry = $zip.CreateEntry([string]$e[0])
            if ($null -eq $e[1]) { continue }
            $st = $entry.Open()
            try {
                if ($e[1] -is [byte[]]) { $st.Write($e[1], 0, $e[1].Length) }
                else { $b = [Text.Encoding]::UTF8.GetBytes([string]$e[1]); $st.Write($b, 0, $b.Length) }
            } finally { $st.Dispose() }
        }
    } finally { $zip.Dispose(); $fs.Dispose() }
}
# JS-екранування як у Google: \xHH для службових символів і \uHHHH для кирилиці.
function ConvertTo-JsEscaped([string]$s) {
    $bs = [string][char]92
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        $c = [int]$ch
        if ('[]"=&'.IndexOf($ch) -ge 0) { [void]$sb.Append($bs + 'x' + $c.ToString('x2')) }
        elseif ($c -gt 127) { [void]$sb.Append($bs + 'u' + $c.ToString('x4')) }
        else { [void]$sb.Append($ch) }
    }
    return $sb.ToString()
}

$lf = "`n"
$localConfigFixture = @'
"UserLocalConfigStore"
{
	"Software"
	{
		"Valve"
		{
			"Steam"
			{
				"apps"
				{
					"220"
					{
						"LastPlayed"		"1700000000"
						"LaunchOptions"		"-novid -language russian"
					}
					"420"
					{
						"LastPlayed"		"1600000000"
					}
				}
			}
		}
	}
	"friends"
	{
		"x"		"y"
	}
}
'@ -replace "`r`n", "`n"

# ============================================================ unit tests ====

Test-Case 'Format-UaSize / Format-UaDuration' {
    Assert-Eq (Format-UaSize 512) '512 Б' 'bytes'
    Assert-Eq (Format-UaSize 2048) '2 КБ' 'KB'
    Assert-Eq (Format-UaSize (350MB)) '350 МБ' 'MB'
    Assert-Eq (Format-UaSize (2.5GB)) '2,5 ГБ' 'GB'
    Assert-Eq (Format-UaDuration 42) '42 с' 'seconds'
    Assert-Eq (Format-UaDuration 125) '2 хв 5 с' 'min+sec'
    Assert-Eq (Format-UaDuration 1500) '25 хв' 'minutes'
    Assert-Eq (Format-UaDuration 3900) '1 год 5 хв' 'hours'
    Assert-Eq (Format-UaDuration ([double]::NaN)) '' 'NaN'
}

Test-Case 'VDF: libraryfolders (new and old formats), appmanifest' {
    $new = "`"libraryfolders`"$lf{$lf`t`"0`"$lf`t{$lf`t`t`"path`"`t`t`"C:\\Program Files (x86)\\Steam`"$lf`t`t`"apps`"$lf`t`t{$lf`t`t`t`"228980`"`t`t`"1`"$lf`t`t}$lf`t}$lf`t`"1`"$lf`t{$lf`t`t`"path`"`t`t`"D:\\SteamLibrary`"$lf`t}$lf}$lf"
    $root = ConvertFrom-UaVdf $new
    $lfn = Get-UaVdfChild $root 'LibraryFolders'
    Assert-True ($null -ne $lfn) 'libraryfolders node (case-insensitive)'
    Assert-Eq (Get-UaVdfValue (Get-UaVdfChild $lfn '0') 'path') 'C:\Program Files (x86)\Steam' 'path unescaped'
    Assert-Eq (Get-UaVdfValue (Get-UaVdfChild $lfn '1') 'path') 'D:\SteamLibrary' 'second library'
    $old = "`"LibraryFolders`"$lf{$lf`t`"TimeNextStatsReport`"`t`t`"1561832015`"$lf`t`"1`"`t`t`"D:\\Games\\SteamLibrary`"$lf}"
    $o = Get-UaVdfChild (ConvertFrom-UaVdf $old) 'libraryfolders'
    Assert-Eq (Get-UaVdfValue $o '1') 'D:\Games\SteamLibrary' 'old format numeric key'
    $acf = "`"AppState`"$lf{$lf`t`"appid`"`t`t`"220`"$lf`t`"name`"`t`t`"Half-Life 2`"$lf`t`"StateFlags`"`t`t`"4`"$lf`t`"installdir`"`t`t`"Half-Life 2`"$lf`t`"BytesToDownload`"`t`t`"123`"$lf}$lf"
    $tmp = [IO.Path]::GetTempFileName()
    Write-Text $tmp $acf
    $m = Read-UaAppManifest $tmp
    Remove-Item -LiteralPath $tmp
    Assert-Eq $m.InstallDir 'Half-Life 2' 'installdir'
    Assert-Eq $m.StateFlags 4L 'StateFlags'
    Assert-Eq $m.BytesToDownload 123L 'BytesToDownload'
    $cond = "`"a`"$lf{$lf`t`"k`"`t`"v`" [`$WIN32]$lf`t// comment`"x`"$lf`t`"k2`"`t`"v2`"$lf}"
    Assert-Eq (Get-UaVdfValue (Get-UaVdfChild (ConvertFrom-UaVdf $cond) 'a') 'k2') 'v2' 'conditionals and comments skipped'
    $threw = $false
    try { [void](ConvertFrom-UaVdf "`"a`"$lf{$lf`t`"k`"`t`"v`"$lf") } catch { $threw = $true }
    Assert-True $threw 'unbalanced braces throw'
}

Test-Case 'Launch options string transforms' {
    Assert-Eq (Add-UaLaunchArgs '') '-language ukr +cc_lang ukr' 'empty'
    Assert-Eq (Add-UaLaunchArgs '-novid') '-novid -language ukr +cc_lang ukr' 'append'
    Assert-Eq (Add-UaLaunchArgs '-language english -novid') '-novid -language ukr +cc_lang ukr' 'replace other language'
    Assert-Eq (Add-UaLaunchArgs 'mangohud %command% -novid') 'mangohud %command% -language ukr +cc_lang ukr -novid' '%command% template'
    Assert-Eq (Add-UaLaunchArgs '-novid -language ukr +cc_lang ukr') '-novid -language ukr +cc_lang ukr' 'idempotent'
    Assert-Eq (Remove-UaLaunchArgs '-novid -language ukr +cc_lang ukr') '-novid' 'remove'
    Assert-Eq (Remove-UaLaunchArgs '-language "ukr" +cc_lang ukr') '' 'remove quoted'
    Assert-Eq (Remove-UaLaunchArgs '+cc_language 1 -dev') '+cc_language 1 -dev' 'similar names untouched'
}

Test-Case 'localconfig.vdf: edit existing value in place' {
    $r = Set-UaVdfAppLaunchOptions -Text $localConfigFixture -AppId '220' -Transform { param($o) Add-UaLaunchArgs $o }
    Assert-True $r.Changed 'changed'
    Assert-Eq $r.Before '-novid -language russian' 'before'
    Assert-Eq $r.After '-novid -language ukr +cc_lang ukr' 'after'
    $expected = $localConfigFixture.Replace('"-novid -language russian"', '"-novid -language ukr +cc_lang ukr"')
    Assert-Eq $r.Text $expected 'only the value changed'
    $again = Set-UaVdfAppLaunchOptions -Text $r.Text -AppId '220' -Transform { param($o) Add-UaLaunchArgs $o }
    Assert-True (-not $again.Changed) 'second application is a no-op'
}

Test-Case 'localconfig.vdf: insert into existing app block, keep formatting' {
    $r = Set-UaVdfAppLaunchOptions -Text $localConfigFixture -AppId '420' -Transform { param($o) Add-UaLaunchArgs $o }
    Assert-True $r.Changed 'changed'
    $t6 = "`t" * 6
    $t5 = "`t" * 5
    $needle = "`"420`"$lf$t5{$lf$t6`"LaunchOptions`"`t`t`"-language ukr +cc_lang ukr`"$lf$t6`"LastPlayed`""
    Assert-True ($r.Text.Contains($needle)) 'inserted right after { with 6 tabs'
    $back = Set-UaVdfAppLaunchOptions -Text $r.Text -AppId '420' -Transform { param($o) Remove-UaLaunchArgs $o } -RemoveIfEmpty
    Assert-Eq $back.Text $localConfigFixture 'RemoveIfEmpty restores the original text byte-for-byte'
    $none = Set-UaVdfAppLaunchOptions -Text $localConfigFixture -AppId '380' -Transform { param($o) Add-UaLaunchArgs $o }
    Assert-True (-not $none.Changed) 'missing app without -CreateIfMissing is untouched'
}

Test-Case 'localconfig.vdf: create missing chain (CRLF file)' {
    $crlf = "`"UserLocalConfigStore`"`r`n{`r`n`t`"Software`"`r`n`t{`r`n`t`t`"Valve`"`r`n`t`t{`r`n`t`t`t`"Steam`"`r`n`t`t`t{`r`n`t`t`t`t`"SurveyDate`"`t`t`"2024-01-01`"`r`n`t`t`t}`r`n`t`t}`r`n`t}`r`n}`r`n"
    $r = Set-UaVdfAppLaunchOptions -Text $crlf -AppId '220' -Transform { param($o) Add-UaLaunchArgs $o } -CreateIfMissing
    Assert-True $r.Changed 'changed'
    Assert-True (-not ($r.Text -match "[^`r]`n")) 'all inserted newlines are CRLF'
    $node = Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (ConvertFrom-UaVdf $r.Text) 'UserLocalConfigStore') 'Software') 'Valve') 'Steam') 'apps') '220'
    Assert-Eq (Get-UaVdfValue $node 'LaunchOptions') '-language ukr +cc_lang ukr' 'created value readable'
    $bare = "`"UserLocalConfigStore`"$lf{$lf`t`"friends`"$lf`t{$lf`t}$lf}$lf"
    $r2 = Set-UaVdfAppLaunchOptions -Text $bare -AppId '220' -Transform { param($o) Add-UaLaunchArgs $o } -CreateIfMissing
    $n2 = Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (ConvertFrom-UaVdf $r2.Text) 'UserLocalConfigStore') 'Software') 'Valve') 'Steam') 'apps') '220'
    Assert-Eq (Get-UaVdfValue $n2 'LaunchOptions') '-language ukr +cc_lang ukr' 'whole Software chain created'
}

Test-Case 'localconfig.vdf: escaped quotes and backslashes survive' {
    $bs = [string][char]92
    $raw = $bs + '"C:' + $bs + $bs + 'tools' + $bs + $bs + 'wrap.exe' + $bs + '" %command% -novid'
    $text = "`"UserLocalConfigStore`"$lf{$lf`t`"Software`"$lf`t{$lf`t`t`"Valve`"$lf`t`t{$lf`t`t`t`"Steam`"$lf`t`t`t{$lf`t`t`t`t`"apps`"$lf`t`t`t`t{$lf`t`t`t`t`t`"220`"$lf`t`t`t`t`t{$lf`t`t`t`t`t`t`"LaunchOptions`"`t`t`"$raw`"$lf`t`t`t`t`t}$lf`t`t`t`t}$lf`t`t`t}$lf`t`t}$lf`t}$lf}$lf"
    $r = Set-UaVdfAppLaunchOptions -Text $text -AppId '220' -Transform { param($o) Add-UaLaunchArgs $o }
    Assert-Eq $r.Before '"C:\tools\wrap.exe" %command% -novid' 'unescaped before'
    Assert-Eq $r.After '"C:\tools\wrap.exe" %command% -language ukr +cc_lang ukr -novid' 'after'
    $node = Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (ConvertFrom-UaVdf $r.Text) 'UserLocalConfigStore') 'Software') 'Valve') 'Steam') 'apps') '220'
    Assert-Eq (Get-UaVdfValue $node 'LaunchOptions') $r.After 'round-trips through escaping'
}

Test-Case 'Google Drive: embedded folder listing' {
    $html = '<html><body><div class="flip-entries">' +
    '<div class="flip-entry" id="entry-1AbCdEfGhIjKlMnOp" tabindex="0" role="link"><div class="flip-entry-info"><a href="https://drive.google.com/file/d/1AbCdEfGhIjKlMnOp/view?usp=drive_web" target="_blank"><div class="flip-entry-visual"></div><div class="flip-entry-title">Half-Life 2 UKR (озвучення+текст).zip</div></a></div><div class="flip-entry-last-modified"><div>Dec 1, 2024</div></div></div>' +
    '<div class="flip-entry" id="entry-1FoLdErIdXyZ123456" tabindex="0" role="link"><div class="flip-entry-info"><a href="https://drive.google.com/drive/folders/1FoLdErIdXyZ123456" target="_blank"><div class="flip-entry-title">Епізоди &amp; інше</div></a></div></div>' +
    '<div class="flip-entry" id="entry-1TeXtIdQwErTy7890" tabindex="0" role="link"><div class="flip-entry-info"><a href="https://drive.google.com/file/d/1TeXtIdQwErTy7890/view?usp=drive_web"><div class="flip-entry-title">Half-Life 2 UKR (текст).zip</div></a></div></div>' +
    '</div></body></html>'
    $e = @(ConvertFrom-UaDriveEmbedHtml $html)
    Assert-Eq $e.Count 3 'three entries'
    Assert-Eq $e[0].Id '1AbCdEfGhIjKlMnOp' 'file id'
    Assert-Eq $e[0].Name 'Half-Life 2 UKR (озвучення+текст).zip' 'file name'
    Assert-True (-not $e[0].IsFolder) 'file is not folder'
    Assert-True $e[1].IsFolder 'folder detected'
    Assert-Eq $e[1].Name 'Епізоди & інше' 'html entities decoded'
    Assert-Eq $e[2].Id '1TeXtIdQwErTy7890' 'third id'
}

Test-Case 'Google Drive: _DRIVE_ivd folder page' {
    $json = '[[["1AbCdEfGhIjKlMnOp",["1RoOtFoLdEr000001"],"Half-Life 2 UKR (озвучення+текст).zip","application/zip",0],["1FoLdErIdXyZ123456",["1RoOtFoLdEr000001"],"Епізод 2","application/vnd.google-apps.folder",0]],null]'
    $html = "<html><script>window['_DRIVE_ivd'] = '" + (ConvertTo-JsEscaped $json) + "';</script></html>"
    Assert-True ($html.IndexOf([char]0x0437) -lt 0) 'fixture really uses \u escapes'
    $e = @(ConvertFrom-UaDriveIvdHtml $html)
    Assert-Eq $e.Count 2 'two entries'
    Assert-Eq $e[0].Name 'Half-Life 2 UKR (озвучення+текст).zip' 'decoded cyrillic name'
    Assert-True $e[1].IsFolder 'folder mime'
}

Test-Case 'Google Drive: warning pages' {
    $confirm = '<html><head><title>Google Drive - Virus scan warning</title></head><body><form id="download-form" action="https://drive.usercontent.google.com/download" method="get"><input type="submit" id="uc-download-link" value="Download anyway"/><input type="hidden" name="id" value="1AbC"><input type="hidden" name="export" value="download"><input type="hidden" name="confirm" value="t"><input type="hidden" name="uuid" value="a1-b2"></form></body></html>'
    Assert-Eq (Get-UaDrivePageKind $confirm) 'confirm' 'virus scan page'
    Assert-Eq (Get-UaDriveConfirmUrl $confirm) 'https://drive.usercontent.google.com/download?id=1AbC&export=download&confirm=t&uuid=a1-b2' 'confirm url'
    Assert-Eq (Get-UaDrivePageKind '<title>Google Drive - Quota exceeded</title>Too many users have viewed or downloaded this file recently.') 'quota' 'quota page'
    Assert-Eq (Get-UaDrivePageKind '<a href="https://accounts.google.com/ServiceLogin?x">') 'denied' 'login page'
    $legacy = '<a id="uc-download-link" href="/uc?export=download&amp;confirm=AbCd&amp;id=1XyZ">Download anyway</a>'
    Assert-Eq (Get-UaDriveConfirmUrl $legacy) 'https://drive.google.com/uc?export=download&confirm=AbCd&id=1XyZ' 'legacy confirm link'
}

Test-Case 'Archive name classification' {
    $cases = @(
        @('Half-Life 2 UKR (озвучення+текст).zip', 'hl2', 'full'),
        @('Half-Life 2 UKR (текст).zip', 'hl2', 'text'),
        @('Half-Life 2 Епізод 1 UKR (озвучення+текст).zip', 'ep1', 'full'),
        @('Half-Life 2 Episode Two UKR (текст).zip', 'ep2', 'text'),
        @('Епізод 2/Half-Life 2 UKR (озвучення+текст).zip', 'ep2', 'full'),
        @('HL2 EP1 UKR.zip', 'ep1', 'other'),
        @('Half-Life 2 Episode One - ukr voice.zip', 'ep1', 'full'),
        @('Half-Life 2 UKR (текстури).zip', 'hl2', 'textures'),
        @('Half-Life 2 Lost Coast UKR.zip', 'lostcoast', 'other'),
        @('Half-Life 2 Епізод Два (озвучення).zip', 'ep2', 'full')
    )
    foreach ($c in $cases) {
        $i = Get-UaArchiveInfo $c[0]
        Assert-Eq ($i.Part + '/' + $i.Type) ($c[1] + '/' + $c[2]) ('classify ' + $c[0])
    }
}

Test-Case 'Archive selection from listing' {
    $listing = @(
        @{ Id = 'a1a1a1a1a1a1'; Name = 'Half-Life 2 UKR (озвучення+текст) v1.1.zip'; Path = 'Half-Life 2 UKR (озвучення+текст) v1.1.zip'; IsFolder = $false },
        @{ Id = 'a2a2a2a2a2a2'; Name = 'Half-Life 2 UKR (озвучення+текст) v1.2.zip'; Path = 'Half-Life 2 UKR (озвучення+текст) v1.2.zip'; IsFolder = $false },
        @{ Id = 't1t1t1t1t1t1'; Name = 'Half-Life 2 UKR (текст).zip'; Path = 'Half-Life 2 UKR (текст).zip'; IsFolder = $false },
        @{ Id = 'f1f1f1f1f1f1'; Name = 'Епізод 1'; Path = 'Епізод 1'; IsFolder = $true },
        @{ Id = 'e1e1e1e1e1e1'; Name = 'UKR (озвучення+текст).7z'; Path = 'Епізод 1/UKR (озвучення+текст).7z'; IsFolder = $false },
        @{ Id = 'x2x2x2x2x2x2'; Name = 'HL2 EP2 UKR.zip'; Path = 'HL2 EP2 UKR.zip'; IsFolder = $false }
    )
    $sel = Select-UaArchives -Listing $listing -Parts @('hl2', 'ep1', 'ep2')
    Assert-Eq $sel['hl2'].Full.Id 'a2a2a2a2a2a2' 'newest version wins'
    Assert-Eq $sel['hl2'].Text.Id 't1t1t1t1t1t1' 'text archive'
    Assert-True ($null -eq $sel['ep1'].Full) 'ep1: 7z is not usable'
    Assert-Eq $sel['ep1'].Unsupported.Id 'e1e1e1e1e1e1' 'ep1 unsupported noted'
    Assert-Eq $sel['ep2'].Full.Id 'x2x2x2x2x2x2' 'unmarked zip used as fallback'
}

Test-Case 'Zip root detection and entry filters' {
    Assert-Eq (Find-UaZipRootPrefix @('hl2_ukr/sound/a.wav')) '' 'flat archive'
    Assert-Eq (Find-UaZipRootPrefix @('Half-Life 2 UKR/readme.txt', 'Half-Life 2 UKR/hl2_ukr/sound/a.wav')) 'Half-Life 2 UKR/' 'wrapper folder'
    Assert-Eq (Find-UaZipRootPrefix @('A/B/hl2/resource/x.txt')) 'A/B/' 'nested wrapper'
    Assert-Eq (Find-UaZipRootPrefix @('HL2/hl2_ukr/x.wav', 'HL2/platform/y.txt')) 'HL2/' 'wrapper named like a game folder'
    Assert-Eq (Find-UaZipRootPrefix @('hl2/bin/client.dll', 'hl2/resource/a.txt')) '' 'hl2/bin is not a wrapper'
    Assert-True ($null -eq (Find-UaZipRootPrefix @('readme.txt', 'sound/x.wav'))) 'unknown layout'
    Assert-True (Test-UaSafeRelPath 'hl2/resource/a.txt') 'safe path'
    foreach ($bad in @('../x', 'a/../b', '/abs', 'C:/x', 'a//b')) { Assert-True (-not (Test-UaSafeRelPath $bad)) ('unsafe: ' + $bad) }
    Assert-True (Test-UaJunkEntry 'readme.txt') 'root-level file skipped'
    Assert-True (Test-UaJunkEntry 'hl2/__MACOSX/x') 'macos junk'
    Assert-True (Test-UaJunkEntry 'hl2/._x.wav') 'appledouble'
    Assert-True (-not (Test-UaJunkEntry 'hl2/resource/x.txt')) 'regular entry kept'
}

Test-Case 'Error mapping' {
    Assert-Eq (Get-UaErrorInfo (Convert-UaDiskError (New-Object UnauthorizedAccessException 'x'))).Code 42 'access denied -> 42'
    Assert-Eq (Get-UaErrorInfo (Convert-UaDiskError (New-Object IO.IOException 'full', -2147024784))).Code 41 'disk full -> 41'
    Assert-Eq (Get-UaErrorInfo (Convert-UaDiskError (New-Object IO.IOException 'busy', -2147024864))).Code 43 'sharing violation -> 43'
    Assert-Eq (Get-UaErrorInfo (Convert-UaDiskError (New-Object IO.IOException 'virus', -2147024671))).Code 44 'virus -> 44'
    Assert-Eq (Get-UaErrorInfo (Convert-UaDiskError (New-Object IO.IOException 'other') 52)).Code 45 'generic io -> 45'
    Assert-True ($null -eq (Convert-UaDiskError (New-Object InvalidOperationException 'x'))) 'non-disk -> null'
    $wrapped = New-Object System.Management.Automation.RuntimeException('outer', (New-UaError 35 'inner'))
    Assert-Eq (Get-UaErrorInfo $wrapped).Code 35 'code found through wrappers'
    foreach ($k in $global:HL2UA_Errors.Keys) { Assert-Eq @($global:HL2UA_Errors[$k]).Count 2 ('catalog entry ' + $k) }
    Assert-True (Test-UaTransient (New-Object IO.IOException 'connection reset')) 'network io is transient'
    Assert-True (-not (Test-UaTransient (New-Object IO.IOException 'full', -2147024784))) 'disk full is not transient'
    Assert-True (-not (Test-UaTransient (New-UaError 35))) 'coded errors are final'
}

Test-Case 'Progress weighting' {
    $s = New-UaState
    $s.Steps = @(@{ Key = 'a'; Title = 'a'; Weight = 10; Status = 'done' }, @{ Key = 'b'; Title = 'b'; Weight = 30; Status = 'running' }, @{ Key = 'c'; Title = 'c'; Weight = 60; Status = 'pending' })
    $s.StepFraction = 0.5
    Assert-Eq (Get-UaOverallPercent $s) 25 '10 + 30*0.5 of 100'
}

# ===================================================== integration tests ====

function Find-Python {
    foreach ($c in @('python3', 'python', 'py')) {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

if (-not $SkipIntegration) {
    $py = Find-Python
    if (-not $py) { Add-Failure 'python not found for integration tests (use -SkipIntegration to skip)' }
}

if (-not $SkipIntegration -and $py) {
    $work = P ([IO.Path]::GetTempPath()) ('hl2ua-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    [void][IO.Directory]::CreateDirectory($work)
    $oldTmp = $env:TMP; $oldTemp = $env:TEMP; $oldTmpDir = $env:TMPDIR
    $tmpDir = P $work 'tmp'
    [void][IO.Directory]::CreateDirectory($tmpDir)
    $env:TMP = $tmpDir; $env:TEMP = $tmpDir; $env:TMPDIR = $tmpDir
    $desktop = P $work 'desktop'
    [void][IO.Directory]::CreateDirectory($desktop)

    # --- fake Steam with a second library and the game ---
    $steam = P $work 'Steam'
    $lib2 = P $work 'Library2'
    $game = P $lib2 'steamapps' 'common' 'Half-Life 2'
    Write-Text (P $steam 'steam.exe') 'fake'
    Write-Text (P $steam 'steamapps' 'libraryfolders.vdf') ("`"libraryfolders`"$lf{$lf`t`"0`"$lf`t{$lf`t`t`"path`"`t`t`"" + (ConvertTo-UaVdfEscaped $steam) + "`"$lf`t}$lf`t`"1`"$lf`t{$lf`t`t`"path`"`t`t`"" + (ConvertTo-UaVdfEscaped $lib2) + "`"$lf`t}$lf}$lf")
    Write-Text (P $lib2 'steamapps' 'appmanifest_220.acf') "`"AppState`"$lf{$lf`t`"appid`"`t`t`"220`"$lf`t`"StateFlags`"`t`t`"4`"$lf`t`"installdir`"`t`t`"Half-Life 2`"$lf}$lf"
    Write-Text (P $game 'hl2.exe') 'fake exe'
    Write-Text (P $game 'hl2' 'gameinfo.txt') 'GameInfo {}'
    Write-Text (P $game 'hl2' 'resource' 'gameui_english.txt') 'ORIGINAL GAMEUI'
    Write-Text (P $game 'episodic' 'gameinfo.txt') 'GameInfo {}'
    Write-Text (P $game 'ep2' 'gameinfo.txt') 'GameInfo {}'
    $lc1 = P $steam 'userdata' '111' 'config' 'localconfig.vdf'
    $lc2 = P $steam 'userdata' '222' 'config' 'localconfig.vdf'
    Write-Text $lc1 $localConfigFixture
    Write-Text $lc2 "`"UserLocalConfigStore`"$lf{$lf`t`"friends`"$lf`t{$lf`t}$lf}$lf"

    # --- archives served by the fake Drive ---
    $bigWav = New-RandomBytes 700000 1
    $hl2Full = P $work 'srv' 'hl2full.zip'
    New-TestZip $hl2Full @(
        @('Half-Life 2 UKR/hl2/resource/gameui_english.txt', 'UKR GAMEUI'),
        @('Half-Life 2 UKR/hl2_ukr/', $null),
        @('Half-Life 2 UKR/hl2_ukr/resource/closecaption_ukr.dat', (New-RandomBytes 50000 2)),
        @('Half-Life 2 UKR/hl2_ukr/sound/vo/breen/br_welcome.wav', $bigWav),
        @('Half-Life 2 UKR/platform/resource/platform_ukr.txt', 'PLATFORM UKR'),
        @('Half-Life 2 UKR/Інструкція.txt', 'readme'),
        @('__MACOSX/Half-Life 2 UKR/._x', 'junk')
    )
    $hl2Text = P $work 'srv' 'hl2text.zip'
    New-TestZip $hl2Text @(, @('hl2/resource/hl2_ukr.txt', 'TEXT ONLY'))
    $ep1 = P $work 'srv' 'ep1.zip'
    New-TestZip $ep1 @(, @('episodic_ukr/sound/vo/ep1.wav', (New-RandomBytes 100000 3)))
    $ep2 = P $work 'srv' 'ep2.zip'
    New-TestZip $ep2 @(, @('Half-Life 2 Episode Two/ep2_ukr/sound/vo/ep2.wav', (New-RandomBytes 100000 4)))

    $serverLog = P $work 'server.log'
    $cfgPath = P $work 'drive.json'
    function Set-DriveConfig([hashtable]$Modes, [bool]$Broken = $false) {
        $cfg = @{
            log         = $serverLog
            embed_broken = $Broken
            page_broken = $Broken
            folders     = @{
                'ROOTFOLDER000001' = @(
                    @{ id = 'HL2FULL000000001'; name = 'Half-Life 2 UKR (озвучення+текст).zip' },
                    @{ id = 'HL2TEXT000000001'; name = 'Half-Life 2 UKR (текст).zip' },
                    @{ id = 'EPSFOLDER0000001'; name = 'Епізоди'; folder = $true }
                )
                'EPSFOLDER0000001' = @(
                    @{ id = 'EP1FULL000000001'; name = 'Half-Life 2 Епізод 1 UKR (озвучення+текст).zip' },
                    @{ id = 'EP2FULL000000001'; name = 'Half-Life 2 Епізод 2 UKR (озвучення+текст).zip' }
                )
            }
            files       = @{
                'HL2FULL000000001' = @{ path = $hl2Full; name = 'Half-Life 2 UKR (озвучення+текст).zip'; mode = $Modes['hl2'] }
                'HL2TEXT000000001' = @{ path = $hl2Text; name = 'Half-Life 2 UKR (текст).zip'; mode = 'normal' }
                'EP1FULL000000001' = @{ path = $ep1; name = 'ep1.zip'; mode = $Modes['ep1'] }
                'EP2FULL000000001' = @{ path = $ep2; name = 'ep2.zip'; mode = $Modes['ep2'] }
            }
        }
        [IO.File]::WriteAllText($cfgPath, ($cfg | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
    }
    Set-DriveConfig @{ hl2 = 'drop-once'; ep1 = 'quota'; ep2 = 'confirm' }

    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $py
    $psi.Arguments = '"' + (P $here 'fake_drive.py') + '" "' + $cfgPath + '"'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true
    $server = [Diagnostics.Process]::Start($psi)
    $port = [int](($server.StandardOutput.ReadLine() -split ' ')[1])
    Write-Host ('  fake Drive on port ' + $port)

    $cfg = $global:HL2UA_Config
    $cfg.DriveFolderId = 'ROOTFOLDER000001'
    $cfg.EmbedListUrl = 'http://127.0.0.1:' + $port + '/embeddedfolderview?id={0}'
    $cfg.FolderPageUrl = 'http://127.0.0.1:' + $port + '/folders/{0}'
    $cfg.DownloadUrl = 'http://127.0.0.1:' + $port + '/download?id={0}&export=download&confirm=t'
    $cfg.ClockCheckUrl = 'http://127.0.0.1:' + $port + '/generate_204'
    $cfg.InternetProbes = @('127.0.0.1:' + $port)
    $cfg.ExtraSteamRoots = @($steam)
    $cfg.SkipDiskScan = $true

    function Invoke-Flow([int[]]$Answers) {
        $s = New-UaState
        $s.Headless = $true
        $s.AutoAnswers = New-Object System.Collections.Queue
        foreach ($a in @($Answers)) { $s.AutoAnswers.Enqueue($a) }
        $s.LogPath = P $work ('flow-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.log')
        $s.Desktop = $desktop
        $global:HL2UA_State = $s
        Invoke-UaWorkerMain
        $r = $s.Result
        Write-Host ('    -> {0} {1}' -f $r.Kind, $r.Code)
        if ($r.Kind -eq 'error') { Write-Host ('    log: ' + $s.LogPath) }
        return $s
    }
    function Get-LaunchOptions([string]$File, [string]$AppId) {
        $root = ConvertFrom-UaVdf (Read-Text $File)
        $n = Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild (Get-UaVdfChild $root 'UserLocalConfigStore') 'Software') 'Valve') 'Steam') 'apps') $AppId
        return (Get-UaVdfValue $n 'LaunchOptions')
    }
    $data = P $game '_ukrainizator'
    $wav = P $game 'hl2_ukr' 'sound' 'vo' 'breen' 'br_welcome.wav'
    $gameui = P $game 'hl2' 'resource' 'gameui_english.txt'

    try {
        Test-Case 'Integration 1: fresh install (confirm page, dropped connection + resume, quota on Ep1)' {
            $s = Invoke-Flow @()
            Assert-Eq $s.Result.Kind 'installed' 'result'
            Assert-True ([IO.File]::Exists($wav)) 'voice file installed (wrapper folder stripped)'
            Assert-Eq ([IO.File]::ReadAllBytes($wav).Length) 700000 'voice file complete'
            Assert-Eq (Read-Text $gameui) 'UKR GAMEUI' 'replaced file'
            Assert-Eq (Read-Text (P $data 'backup' 'hl2' 'resource' 'gameui_english.txt')) 'ORIGINAL GAMEUI' 'original backed up'
            Assert-True ([IO.File]::Exists((P $game 'platform' 'resource' 'platform_ukr.txt'))) 'platform file'
            Assert-True (-not [IO.File]::Exists((P $game 'Інструкція.txt'))) 'readme not copied into game root'
            Assert-True (-not [IO.Directory]::Exists((P $game '__MACOSX'))) 'junk skipped'
            Assert-True ([IO.File]::Exists((P $game 'ep2_ukr' 'sound' 'vo' 'ep2.wav'))) 'episode 2 installed'
            Assert-True (-not [IO.Directory]::Exists((P $game 'episodic_ukr'))) 'episode 1 skipped (quota)'
            Assert-True (@($s.Result.Warnings | Where-Object { $_ -match 'Епізод 1' }).Count -gt 0) 'warning about episode 1'
            foreach ($f in @('journal.txt', 'manifest.json', 'install-log.txt', 'README.txt')) { Assert-True ([IO.File]::Exists((P $data $f))) ('data file ' + $f) }
            Assert-Eq (Get-LaunchOptions $lc1 '220') '-novid -language ukr +cc_lang ukr' 'launch options 220'
            Assert-Eq (Get-LaunchOptions $lc1 '420') '-language ukr +cc_lang ukr' 'launch options 420 (existing block)'
            Assert-Eq (Get-LaunchOptions $lc2 '220') '-language ukr +cc_lang ukr' 'second account: chain created'
            Assert-True ([IO.File]::Exists($lc1 + '.hl2ua.bak')) 'localconfig backup'
            $log = Read-Text $serverLog
            Assert-True ($log -match '"path": "/download\?id=HL2FULL000000001[^"]*uuid=[^"]*", "range": "bytes=[1-9]') 'download resumed with Range after the drop'
            Assert-True (-not [IO.Directory]::Exists((P $tmpDir 'HL2UA'))) 'temp download folder removed'
            Assert-True (-not [IO.File]::Exists((P $desktop 'HL2-UA-log.txt'))) 'no error log on desktop'
        }

        Set-DriveConfig @{ hl2 = 'confirm'; ep1 = 'quota'; ep2 = 'normal' }
        Test-Case 'Integration 2: reinstall keeps the true originals' {
            $s = Invoke-Flow @(0)
            Assert-Eq $s.Result.Kind 'installed' 'result'
            Assert-Eq (Read-Text $gameui) 'UKR GAMEUI' 'replaced again'
            Assert-Eq (Read-Text (P $data 'backup' 'hl2' 'resource' 'gameui_english.txt')) 'ORIGINAL GAMEUI' 'backup still holds the original'
            Assert-Eq (Get-LaunchOptions $lc1 '220') '-novid -language ukr +cc_lang ukr' 'launch options not duplicated'
            $m = Read-Text (P $data 'manifest.json') | ConvertFrom-Json
            $rec = @($m.LaunchOptions | Where-Object { $_.AppId -eq '220' -and $_.File -eq $lc1 })
            Assert-Eq $rec.Count 1 'one record for 220'
            Assert-Eq $rec[0].Before '-novid -language russian' 'original value remembered across reinstall'
        }

        Test-Case 'Integration 3: uninstall restores everything' {
            $s = Invoke-Flow @(1)
            Assert-Eq $s.Result.Kind 'uninstalled' 'result'
            Assert-Eq (Read-Text $gameui) 'ORIGINAL GAMEUI' 'original restored'
            Assert-True (-not [IO.Directory]::Exists((P $game 'hl2_ukr'))) 'hl2_ukr removed'
            Assert-True (-not [IO.Directory]::Exists((P $game 'platform'))) 'created folders removed'
            Assert-True (-not [IO.Directory]::Exists((P $game 'ep2_ukr'))) 'episode files removed'
            Assert-True (-not [IO.Directory]::Exists($data)) 'data folder removed'
            Assert-Eq (Read-Text $lc1) $localConfigFixture 'localconfig restored byte-for-byte'
            Assert-True (-not [IO.File]::Exists($lc1 + '.hl2ua.bak')) 'localconfig backup removed'
            Assert-True ($null -eq (Get-LaunchOptions $lc2 '220')) 'second account cleaned'
        }

        Set-DriveConfig @{ hl2 = 'quota'; ep1 = 'quota'; ep2 = 'normal' }
        Test-Case 'Integration 4: Drive quota -> Steam Workshop fallback' {
            $s = Invoke-Flow @(0)
            Assert-Eq $s.Result.Kind 'installed' 'result'
            Assert-Eq $s.Result.Strategy 'workshop' 'strategy'
            Assert-Eq (Read-Text (P $game 'hl2' 'resource' 'hl2_ukr.txt')) 'TEXT ONLY' 'text archive installed'
            Assert-True (-not [IO.File]::Exists($wav)) 'no voice archive'
            $log = Read-Text $s.LogPath
            Assert-True ($log.Contains('steam://url/CommunityFilePage/3374817799')) 'workshop page opened for HL2'
            Assert-True ($log.Contains('steam://url/CommunityFilePage/3547695650')) 'workshop page opened for Ep1'
            Assert-True (-not $log.Contains('steam://url/CommunityFilePage/3583786172')) 'Ep2 voice came from Drive'
            Assert-Eq (Invoke-Flow @(1)).Result.Kind 'uninstalled' 'cleanup uninstall'
        }

        Set-DriveConfig @{ hl2 = 'normal'; ep1 = 'normal'; ep2 = 'normal' } $true
        Test-Case 'Integration 5: listing broken -> archive already in Downloads/Desktop is used' {
            $local = P $desktop 'Half-Life 2 UKR (озвучення+текст).zip'
            [IO.File]::Copy($hl2Full, $local, $true)
            $s = Invoke-Flow @()
            Assert-Eq $s.Result.Kind 'installed' 'result'
            Assert-True ([IO.File]::Exists($wav)) 'installed from local archive'
            Assert-True ([IO.File]::Exists($local)) 'user file kept (it existed before)'
            Assert-True (@($s.Result.Warnings | Where-Object { $_ -match 'Епізод 2' }).Count -gt 0) 'episodes reported as missing'
            Remove-Item -LiteralPath $local
            Assert-Eq (Invoke-Flow @(1)).Result.Kind 'uninstalled' 'cleanup uninstall'
        }

        Test-Case 'Integration 6: listing broken, nothing local -> manual download declined' {
            $s = Invoke-Flow @(1)
            Assert-Eq $s.Result.Kind 'cancelled' 'result'
            Assert-Eq $s.Result.Code 91 'code'
            Assert-True (-not [IO.Directory]::Exists((P $game 'hl2_ukr'))) 'game untouched'
            Assert-True ([IO.File]::Exists((P $desktop 'HL2-UA-log.txt'))) 'log copied to desktop'
        }

        Set-DriveConfig @{ hl2 = 'normal'; ep1 = 'normal'; ep2 = 'normal' }
        Test-Case 'Integration 7: failure mid-install rolls everything back' {
            Write-Text (P $game 'hl2_ukr' 'sound') 'a FILE where a folder must be'
            $s = Invoke-Flow @()
            Assert-Eq $s.Result.Kind 'error' 'result'
            Assert-True ($s.Result.Code -in 45, 52) ('io error code, got ' + $s.Result.Code)
            Assert-Eq (Read-Text $gameui) 'ORIGINAL GAMEUI' 'replaced file restored'
            Assert-True (-not [IO.File]::Exists((P $game 'hl2_ukr' 'resource' 'closecaption_ukr.dat'))) 'new file removed'
            Assert-True (-not [IO.Directory]::Exists((P $game 'hl2_ukr' 'resource'))) 'new folder removed'
            Assert-True (-not [IO.Directory]::Exists($data)) 'no data folder left'
            Assert-Eq (Get-LaunchOptions $lc1 '220') '-novid -language russian' 'Steam settings untouched'
            Remove-Item -LiteralPath (P $game 'hl2_ukr') -Recurse -Force
        }

        Set-DriveConfig @{ hl2 = 'corrupt'; ep1 = 'normal'; ep2 = 'normal' }
        Test-Case 'Integration 8: corrupt download -> retried, then user declines fallbacks' {
            $s = Invoke-Flow @(1, 1)
            Assert-Eq $s.Result.Kind 'cancelled' 'result'
            $log = Read-Text $s.LogPath
            Assert-True ($log.Contains('Corrupt download; retrying once')) 'retried once'
            Assert-True (@(Get-ChildItem -LiteralPath $tmpDir -Recurse -Filter '*.zip*' -ErrorAction SilentlyContinue).Count -eq 0) 'corrupt files deleted'
        }

        if ($Gui) {
            # Справжній запуск, як у батька: cmd.exe -> powershell.exe -> вікно -> фоновий runspace.
            function Invoke-Launcher([hashtable]$Overrides) {
                $ovPath = P $work 'overrides.json'
                [IO.File]::WriteAllText($ovPath, ($Overrides | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
                $env:HL2UA_TEST_OVERRIDES = $ovPath
                try {
                    $p = Start-Process -FilePath $env:ComSpec -ArgumentList @('/c', ('"' + $installer + '"')) -Wait -PassThru
                    return $p.ExitCode
                } finally { $env:HL2UA_TEST_OVERRIDES = $null }
            }
            $baseOv = @{
                DriveFolderId = 'ROOTFOLDER000001'; EmbedListUrl = $cfg.EmbedListUrl; FolderPageUrl = $cfg.FolderPageUrl
                DownloadUrl = $cfg.DownloadUrl; ClockCheckUrl = $cfg.ClockCheckUrl; InternetProbes = @($cfg.InternetProbes)
                ExtraSteamRoots = @($steam); SkipDiskScan = $true; AutoCloseMs = 1500; AutoDialogMs = 800
            }
            Set-DriveConfig @{ hl2 = 'confirm'; ep1 = 'normal'; ep2 = 'normal' }
            Test-Case 'Launcher 1: real .cmd run installs everything' {
                $code = Invoke-Launcher $baseOv
                Assert-Eq $code 0 'exit code'
                Assert-True ([IO.File]::Exists($wav)) 'voice installed'
                Assert-True ([IO.File]::Exists((P $game 'episodic_ukr' 'sound' 'vo' 'ep1.wav'))) 'episode 1 installed'
                Assert-True ([IO.File]::Exists((P $game 'ep2_ukr' 'sound' 'vo' 'ep2.wav'))) 'episode 2 installed'
                Assert-Eq (Get-LaunchOptions $lc1 '220') '-novid -language ukr +cc_lang ukr' 'launch options'
            }
            Test-Case 'Launcher 2: second run -> dialog -> reinstall' {
                $code = Invoke-Launcher $baseOv
                Assert-Eq $code 0 'exit code'
                Assert-True ([IO.File]::Exists($wav)) 'still installed'
            }
            Test-Case 'Launcher 3: game not found -> error 21 on screen and in exit code' {
                $ov = $baseOv.Clone()
                $ov.ExtraSteamRoots = @()
                $code = Invoke-Launcher $ov
                Assert-Eq $code 21 'exit code'
            }
        }
    } finally {
        try { $server.Kill() } catch { }
        $env:TMP = $oldTmp; $env:TEMP = $oldTemp; $env:TMPDIR = $oldTmpDir
        if ($script:Fail -eq 0 -and -not $env:HL2UA_KEEP_TEST) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
        else { Write-Host ('  test files kept in ' + $work) }
    }
}

# ============================================================ GUI smoke ====

if ($Gui) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $orig = $global:HL2UA_ScriptText
    $global:HL2UA_Config.AutoCloseMs = 1500
    $global:HL2UA_Config.AutoDialogMs = 700
    $cases = @(
        @('success with a prompt', "function Invoke-UaFlow(`$ctx) { Initialize-UaSteps @(@{Key='a';Title='Крок A';Weight=1},@{Key='b';Title='Крок B';Weight=1}); Enter-UaStep 'a'; Set-UaProgress 0.5 'Половина'; Start-Sleep -Milliseconds 300; Complete-UaStep 'a'; Enter-UaStep 'b'; [void](Request-UaChoice -Text 'Тестове питання' -Buttons @('Так','Ні')); Complete-UaStep 'b'; return 'installed' }", 0),
        @('coded error', "function Invoke-UaFlow(`$ctx) { Initialize-UaSteps @(@{Key='a';Title='Крок A';Weight=1}); Enter-UaStep 'a'; throw (New-UaError 35 'test') }", 35)
    )
    foreach ($c in $cases) {
        Test-Case ('GUI: ' + $c[0]) {
            $global:HL2UA_ScriptText = $orig + "`n" + $c[1] + "`n"
            $s = New-UaState
            $s.LogPath = P ([IO.Path]::GetTempPath()) ('hl2ua-gui-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.log')
            $s.Desktop = [IO.Path]::GetTempPath()
            $global:HL2UA_State = $s
            $code = [int](Show-UaMainWindow | Select-Object -Last 1)
            Assert-Eq $code $c[2] 'exit code'
            Assert-True $s.Done 'worker finished'
        }
    }
    $global:HL2UA_ScriptText = $orig
}

Write-Host ''
Write-Host ('Passed: {0}  Failed: {1}' -f $script:Pass, $script:Fail) -ForegroundColor $(if ($script:Fail -eq 0) { 'Green' } else { 'Red' })
exit $script:Fail
