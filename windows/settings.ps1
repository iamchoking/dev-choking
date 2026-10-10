# Run through settings.cmd from an administrator CMD in your own Windows account.
# Dot-source this file to load functions without applying settings.
param([string]$EnglishLanguagePack)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'settings_win10.ps1')
. (Join-Path $PSScriptRoot 'settings_win11.ps1')
. (Join-Path $PSScriptRoot 'vscode-context-menu.ps1')

function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Assert-Prerequisites {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Open CMD as administrator using your own Windows account, then run settings.cmd again.'
    }
    $windows = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    if ([int]$windows.CurrentBuildNumber -lt 17763 -or $windows.InstallationType -ne 'Client') {
        throw 'This script requires Windows 10 version 1809 or later, or Windows 11.'
    }
    $script:isWindows11 = [int]$windows.CurrentBuildNumber -ge 22000
    $script:singleLanguage = $windows.EditionID -in @('CoreSingleLanguage', 'CoreCountrySpecific')
    $commands = @('winget.exe', 'Get-WindowsCapability', 'Add-WindowsCapability')
    if ($script:isWindows11) {
        $commands += @('Install-Language', 'Set-SystemPreferredUILanguage', 'Copy-UserInternationalSettingsToSystem')
    }
    foreach ($command in $commands) {
        Get-Command $command -ErrorAction Stop | Out-Null
    }
    if ($script:singleLanguage -and -not (Test-EnglishDisplayLanguage)) {
        throw 'This Windows edition restricts display languages. An English installation or an edition that supports multiple display languages is required.'
    }
}

function Test-EnglishDisplayLanguage {
    # Basic typing capability alone is NOT a Windows display language pack.
    Test-Path -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\MUI\UILanguages\en-US'
}

function Wait-SettingsJob {
    param(
        [System.Management.Automation.Job]$Job,
        [string]$Activity,
        [ValidateRange(1, 60)][int]$HeartbeatSeconds = 15
    )
    $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        while ($Job.State -in @('NotStarted', 'Running', 'Blocked')) {
            Wait-Job -Job $Job -Timeout $HeartbeatSeconds | Out-Null
            Receive-Job -Job $Job -ErrorAction Stop | Out-Null
            if ($Job.State -in @('NotStarted', 'Running', 'Blocked')) {
                Write-Host "[dev-choking] Waiting for $Activity ($([int]$elapsed.Elapsed.TotalSeconds)s elapsed; $($Job.State))..."
            }
        }
        Receive-Job -Job $Job -ErrorAction Stop | Out-Null
        if ($Job.State -ne 'Completed') {
            throw "$Activity ended with job state $($Job.State): $($Job.JobStateInfo.Reason)"
        }
        Write-Host "[dev-choking] Finished $Activity ($([int]$elapsed.Elapsed.TotalSeconds)s)."
    } finally {
        # Do not cancel Windows servicing just because its caller was interrupted.
        if ($Job.State -in @('Completed', 'Failed', 'Stopped')) {
            Remove-Job -Job $Job -ErrorAction SilentlyContinue
        }
    }
}

function Install-EnglishDisplayLanguage {
    if ($script:singleLanguage) {
        Write-Host '[dev-choking] English single-language edition: display pack is already installed.'
        return
    }
    if ($script:isWindows11) {
        Install-Windows11EnglishDisplayLanguage
    } else {
        Install-Windows10EnglishDisplayLanguage -PackagePath $EnglishLanguagePack
    }
}

function Set-DesktopPreferences {
    Write-Host '[dev-choking] Setting dark mode, left taskbar alignment, and Explorer preferences...'
    $personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-RegistryValue $personalize 'AppsUseLightTheme' 0
    Set-RegistryValue $personalize 'SystemUsesLightTheme' 0
    $explorer = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    if ($script:isWindows11) { Set-Windows11TaskbarAlignment }
    Set-RegistryValue $explorer 'Hidden' 1
    Set-RegistryValue $explorer 'HideFileExt' 0
}

function Set-HardwareClockUtc {
    Write-Host '[dev-choking] Setting UTC hardware-clock handling...'
    # Ubuntu must also use UTC: timedatectl should report "RTC in local TZ: no".
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' 'RealTimeIsUniversal' 1
}

function Disable-FastStartup {
    Write-Host '[dev-choking] Disabling Windows Fast Startup...'
    $power = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
    Set-RegistryValue $power 'HiberbootEnabled' 0
    $key = Get-Item -LiteralPath $power
    if ($key.GetValue('HiberbootEnabled') -ne 0 -or
        $key.GetValueKind('HiberbootEnabled') -ne [Microsoft.Win32.RegistryValueKind]::DWord) {
        throw 'Windows Fast Startup could not be verified as disabled.'
    }
}

function Set-PowerPreferences {
    Write-Host '[dev-choking] Setting power modes...'
    try {
        if ($script:isWindows11) {
            Set-Windows11PowerPreferences
        } else {
            Set-Windows10PowerPreferences
        }
    } catch {
        Write-Warning "Power modes could not be fully configured: $($_.Exception.Message)"
        Write-Warning 'Review power mode in Settings (Windows 11), or the battery slider / Power Options (Windows 10).'
        $script:manualSteps.Add('Review AC/battery power modes for this device.')
    }
    Set-PluggedInSleepTimeout
    Set-PluggedInScreenTimeout
}

function Set-PluggedInSleepTimeout {
    Write-Host '[dev-choking] Setting plugged-in automatic sleep to Never...'
    & powercfg.exe /change standby-timeout-ac 0
    if ($LASTEXITCODE -ne 0) { throw "Setting plugged-in sleep to Never failed with exit code $LASTEXITCODE." }
}

function Set-PluggedInScreenTimeout {
    Write-Host '[dev-choking] Setting plugged-in screen timeout to Never...'
    & powercfg.exe /change monitor-timeout-ac 0
    if ($LASTEXITCODE -ne 0) { throw "Setting plugged-in screen timeout to Never failed with exit code $LASTEXITCODE." }
}

function Set-UserLocaleFormat {
    param([uint32]$LocaleType, [string]$Value)
    if (-not ('DevChoking.RegionalFormats' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace DevChoking {
    public static class RegionalFormats {
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetLocaleInfo(uint locale, uint localeType, string data);
        [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, UIntPtr wParam,
            string lParam, uint flags, uint timeout, out UIntPtr result);
    }
}
'@
    }
    if (-not [DevChoking.RegionalFormats]::SetLocaleInfo(0x0400, $LocaleType, $Value)) {
        throw "Setting locale format $LocaleType failed with Windows error $([Runtime.InteropServices.Marshal]::GetLastWin32Error())."
    }
}

function Update-RegionalFormatNotification {
    $result = [UIntPtr]::Zero
    [void][DevChoking.RegionalFormats]::SendMessageTimeout([IntPtr]0xffff, 0x1a,
        [UIntPtr]::Zero, 'intl', 2, 1000, [ref]$result)
}

function Set-RegionalFormats {
    # SetLocaleInfo updates Windows' locale cache as well as the registry;
    # direct registry edits alone can leave Explorer showing the old format.
    # https://learn.microsoft.com/windows/win32/api/winnls/nf-winnls-setlocaleinfow
    Set-UserLocaleFormat 0x1f 'yyyy-MM-dd' # LOCALE_SSHORTDATE
    Set-UserLocaleFormat 0x20 'yyyy-MM-dd' # LOCALE_SLONGDATE
    Set-UserLocaleFormat 0x79 'HH:mm'      # LOCALE_SSHORTTIME
    Set-UserLocaleFormat 0x1003 'HH:mm:ss' # LOCALE_STIMEFORMAT
    Set-UserLocaleFormat 0x0d '0'         # LOCALE_IMEASURE: metric
    Set-UserLocaleFormat 0x100a '9'       # LOCALE_IPAPERSIZE: A4
    Update-RegionalFormatNotification
}

function Install-LanguageCapability {
    param([string]$Name)
    Write-Host "[dev-choking] Checking $Name..."
    $capability = Get-WindowsCapability -Online -Name $Name
    if ($capability.State -ne 'Installed') {
        Write-Host "[dev-choking] Installing $Name..."
        Add-WindowsCapability -Online -Name $Name | Out-Null
        $verified = Get-WindowsCapability -Online -Name $Name
        if ($verified.State -ne 'Installed') {
            throw "$Name did not finish installing (state: $($verified.State)). Restart Windows, then rerun settings.cmd to complete the language resources."
        }
        Write-Host "[dev-choking] Finished installing $Name."
    } else {
        Write-Host "[dev-choking] $Name is already installed; skipping."
    }
}

function New-DesiredLanguageList {
    # Keep English first for app/web preferences. Windows can restore its US
    # keyboard when this list is saved; enforce Korean-only input separately.
    $languages = New-WinUserLanguageList 'en-US'
    $languages.Add('ko-KR')
    foreach ($language in $languages) { $language.InputMethodTips.Clear() }
    $koreanTip = '0412:{A028AE76-01B1-46C2-99C4-ACD9858AE02F}{B5FE1F02-D5F2-4445-9C03-C568F23C99A1}'
    $languages[1].InputMethodTips.Add($koreanTip)
    return ,$languages
}

function Get-EnabledInputTips {
    @(foreach ($language in (Get-WinUserLanguageList)) { $language.InputMethodTips }) |
        Where-Object { $_ } | Sort-Object -Unique
}

function Assert-KoreanOnlyInputProfiles {
    param([string]$KoreanTip)
    $actualTips = @(Get-EnabledInputTips)
    if ($actualTips.Count -ne 1 -or $actualTips[0] -ne $KoreanTip) {
        throw "Windows did not retain Korean IME as the sole keyboard (enabled: $($actualTips -join '; ')). Language installation is complete; review Language & region before restarting."
    }
}

function Invoke-InputProfileInstall {
    param([string]$Tip, [uint32]$Flags)
    if (-not ('DevChoking.InputProfiles' -as [type])) {
        # Documented on both Windows 10 and 11. Load only the system Input.dll.
        # https://learn.microsoft.com/windows/win32/tsf/installlayoutortip
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
namespace DevChoking {
    public static class InputProfiles {
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        [DllImport("input.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool InstallLayoutOrTip(string profiles, uint flags);
    }
}
'@
    }
    # The API's documented format prefixes the hexadecimal language ID with 0x.
    return [DevChoking.InputProfiles]::InstallLayoutOrTip(('0x' + $Tip), $Flags)
}

function Set-KoreanOnlyInputProfiles {
    param([string]$KoreanTip)
    $actualTips = @(Get-EnabledInputTips)
    if ($actualTips.Count -ne 1 -or $actualTips[0] -ne $KoreanTip) {
        Write-Host '[dev-choking] Removing extra keyboards while preserving English language preferences...'
        # ILOT_CLEANINSTALL (0x40) replaces the enabled input profiles; with
        # ILOT_DEFPROFILE (0x02), Korean IME is the only profile and the default.
        if (-not (Invoke-InputProfileInstall -Tip $KoreanTip -Flags 0x42)) {
            throw 'Windows could not enable Korean IME as the sole input profile. Review Language & region before restarting.'
        }
    }
    Assert-KoreanOnlyInputProfiles -KoreanTip $KoreanTip
}

function Copy-InternationalDefaults {
    Write-Host '[dev-choking] Copying language, input, and regional settings to the welcome screen and new users...'
    try {
        if ($script:isWindows11) {
            Copy-Windows11InternationalDefaults
        } else {
            Copy-Windows10InternationalDefaults -KoreanTip $script:koreanTip
        }
        Write-Host '[dev-choking] Finished copying international defaults.'
    } catch {
        Write-Warning "Welcome-screen and new-user international defaults were not copied: $($_.Exception.Message)"
        Write-Warning 'Open intl.cpl > Administrative > Copy settings, then copy current settings to the welcome screen/system accounts and new user accounts.'
        $script:manualSteps.Add('Copy international settings in intl.cpl > Administrative > Copy settings.')
    }
}

function Set-LanguageAndRegion {
    Write-Host '[dev-choking] Installing English display resources and Korean input support. Downloads can take several minutes...'
    Install-LanguageCapability 'Language.Basic~~~en-US~0.0.1.0'
    Install-LanguageCapability 'Language.Basic~~~ko-KR~0.0.1.0'
    Install-LanguageCapability 'Language.Fonts.Kore~~~und-KORE~0.0.1.0'

    if ($script:isWindows11) { Set-Windows11SystemUiLanguage }
    Set-WinUILanguageOverride 'en-US'
    Set-WinSystemLocale 'en-US'
    $languages = New-DesiredLanguageList
    $koreanTip = $languages[1].InputMethodTips[0]
    $script:koreanTip = $koreanTip
    Set-WinUserLanguageList -LanguageList $languages -Force
    Set-WinDefaultInputMethodOverride -InputTip $koreanTip
    # Use one input method across windows instead of remembering one per app.
    Set-WinLanguageBarOption
    foreach ($name in @('Hotkey', 'Language Hotkey', 'Layout Hotkey')) {
        Set-RegistryValue 'HKCU:\Keyboard Layout\Toggle' $name '3' 'String'
    }

    # Korean 101-key Type 1: Right Alt = Hangul/English, Right Ctrl = Hanja.
    $keyboard = 'HKLM:\SYSTEM\CurrentControlSet\Services\i8042prt\Parameters'
    Set-RegistryValue $keyboard 'LayerDriver KOR' 'kbd101a.dll' 'String'
    Set-RegistryValue $keyboard 'OverrideKeyboardIdentifier' 'PCAT_101AKEY' 'String'
    Set-RegistryValue $keyboard 'OverrideKeyboardType' 8
    Set-RegistryValue $keyboard 'OverrideKeyboardSubtype' 3

    # Set culture after the language list, then custom formats after culture.
    # English (UK) supplies metric/A4 defaults even to apps that ignore overrides.
    Set-Culture 'en-GB'
    Set-RegionalFormats

    # Setting preferred languages can synthesize the English keyboard even when
    # InputMethodTips was empty. Replace the enabled profiles after those changes,
    # and verify before copying so new users do not inherit an unwanted keyboard.
    Set-KoreanOnlyInputProfiles -KoreanTip $koreanTip
    Copy-InternationalDefaults
    # Copying international defaults can normalize custom formats; reapply last.
    Set-RegionalFormats
    Assert-KoreanOnlyInputProfiles -KoreanTip $koreanTip
    Update-WindowsSearchLanguage
    Write-Host '[dev-choking] English UI; Korean IME only; yyyy-MM-dd; 24-hour time; metric; A4.'
}

function Update-WindowsSearchLanguage {
    # Search can retain localized result labels in its running process even
    # after the language preferences and on-disk Settings index are English.
    # https://learn.microsoft.com/troubleshoot/windows-client/shell-experience/fix-problems-in-windows-search
    $sessionId = (Get-Process -Id $PID).SessionId
    Get-Process -Name SearchHost, SearchApp, SearchUI -ErrorAction SilentlyContinue |
        Where-Object { $_.SessionId -eq $sessionId } | Stop-Process -Force
    Write-Host '[dev-choking] Windows Search refreshed; it reloads the selected display language when next opened.'
}

function Set-PrinterQueuePaper {
    param($Queue)
    # Current-user printing preferences also cover connected shared printers.
    # https://learn.microsoft.com/dotnet/api/system.printing.printqueue.userprintticket
    $a4Sizes = @(($Queue.GetPrintCapabilities()).PageMediaSizeCapability |
        Where-Object { $_.PageMediaSizeName -eq [System.Printing.PageMediaSizeName]::ISOA4 })
    if ($a4Sizes.Count -eq 0) { throw 'The printer driver does not advertise A4 support.' }
    $baseTicket = $Queue.UserPrintTicket
    if ($null -eq $baseTicket) { $baseTicket = $Queue.DefaultPrintTicket }
    if ($null -eq $baseTicket) { $baseTicket = New-Object System.Printing.PrintTicket }
    $delta = New-Object System.Printing.PrintTicket
    $delta.PageMediaSize = $a4Sizes[0]
    $validated = $Queue.MergeAndValidatePrintTicket($baseTicket, $delta).ValidatedPrintTicket
    if ($validated.PageMediaSize.PageMediaSizeName -ne [System.Printing.PageMediaSizeName]::ISOA4) {
        throw 'The driver rejected A4 while validating its other print settings.'
    }
    $Queue.UserPrintTicket = $validated
    $Queue.Commit()
    $Queue.Refresh()
    if ($Queue.UserPrintTicket.PageMediaSize.PageMediaSizeName -ne [System.Printing.PageMediaSizeName]::ISOA4) {
        throw 'The driver did not retain A4.'
    }
}

function Set-PrinterDefaults {
    Write-Host '[dev-choking] Setting your installed printers to A4...'
    $printServer = $null
    $queues = $null
    try {
        Add-Type -AssemblyName System.Printing
        Add-Type -AssemblyName ReachFramework
        $printServer = New-Object System.Printing.LocalPrintServer
        $queueTypes = [System.Printing.EnumeratedPrintQueueTypes[]]@('Local', 'Connections')
        $queues = $printServer.GetPrintQueues($queueTypes)
        foreach ($printer in $queues) {
            try {
                Set-PrinterQueuePaper $printer
                Write-Host "[dev-choking] A4: $($printer.Name)"
            } catch {
                Write-Warning "$($printer.Name): $($_.Exception.Message)"
                $script:manualSteps.Add("Select A4 in Printing preferences for $($printer.Name).")
            } finally {
                $printer.Dispose()
            }
        }
    } catch {
        Write-Warning "Printer settings are unavailable: $($_.Exception.Message)"
        $script:manualSteps.Add('Review A4 in printer Printing preferences after installing the printer drivers.')
    } finally {
        if ($null -ne $queues) { $queues.Dispose() }
        if ($null -ne $printServer) { $printServer.Dispose() }
    }
}

function Close-WordComObject {
    param(
        $ComObject,
        [ValidateSet('Document', 'Application')][string]$Kind
    )
    if ($null -eq $ComObject) { return }
    $doNotSaveChanges = 0
    $missing = [Type]::Missing
    if ($Kind -eq 'Document') {
        $ComObject.Close([ref]$doNotSaveChanges, [ref]$missing, [ref]$missing)
    } else {
        $ComObject.Quit([ref]$doNotSaveChanges, [ref]$missing, [ref]$missing)
    }
}

function Set-WordDefaults {
    if (-not [type]::GetTypeFromProgID('Word.Application')) {
        Write-Host '[dev-choking] Word is not installed. Rerun settings.cmd after installing Word to set its template to A4.'
        return
    }
    if (Get-Process -Name WINWORD -ErrorAction SilentlyContinue) {
        Write-Warning 'Word is open. Close Word and rerun settings.cmd to update its default template.'
        $script:manualSteps.Add('Close Word and rerun settings.cmd to apply its A4/centimeter defaults.')
        return
    }
    $word = $null
    $options = $null
    $normal = $null
    $document = $null
    $pageSetup = $null
    try {
        Write-Host '[dev-choking] Setting Word to centimeters and its Normal template to A4...'
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0
        $word.AutomationSecurity = 3
        $options = $word.Options
        $options.MeasurementUnit = 1 # wdCentimeters
        $normal = $word.NormalTemplate
        $backup = $normal.FullName + '.before-dev-choking'
        if ((Test-Path -LiteralPath $normal.FullName) -and -not (Test-Path -LiteralPath $backup)) {
            Copy-Item -LiteralPath $normal.FullName -Destination $backup
        }
        $document = $normal.OpenAsDocument()
        $pageSetup = $document.PageSetup
        $pageSetup.PaperSize = 7 # wdPaperA4 (different from Windows' DMPAPER_A4).
        $document.Save()
        Write-Host '[dev-choking] New Word documents using Normal.dotm will use A4; measurements use centimeters.'
    } catch {
        Write-Warning "Word defaults could not be fully configured: $($_.Exception.Message)"
        $script:manualSteps.Add('In Word, set Layout > Page Setup > Paper > A4 > Set As Default, and set measurement units to centimeters in Options > Advanced.')
    } finally {
        try {
            Close-WordComObject -ComObject $document -Kind Document
        } finally {
            try {
                Close-WordComObject -ComObject $word -Kind Application
            } finally {
                foreach ($comObject in @($pageSetup, $document, $normal, $options, $word)) {
                    if ($null -ne $comObject -and [Runtime.InteropServices.Marshal]::IsComObject($comObject)) {
                        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($comObject)
                    }
                }
            }
        }
    }
}

function Uninstall-OneDrive {
    Write-Host '[dev-choking] Checking Microsoft OneDrive...'
    & winget.exe list --id Microsoft.OneDrive --exact --source winget --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -eq -1978335212) {
        Write-Host '[dev-choking] Microsoft OneDrive is not installed; skipping.'
        return
    }
    if ($LASTEXITCODE -ne 0) { throw "Could not check Microsoft OneDrive (WinGet exit $LASTEXITCODE). Resolve the error above, then rerun settings.cmd." }
    Write-Host '[dev-choking] Uninstalling Microsoft OneDrive...'
    & winget.exe uninstall --id Microsoft.OneDrive --exact --source winget --silent --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "Microsoft OneDrive uninstall failed with exit code $LASTEXITCODE. Resolve the error above, then rerun settings.cmd." }
    Write-Host '[dev-choking] Microsoft OneDrive is uninstalled.'
}

function New-ShutUp10Shortcut {
    param([string]$Executable, [string]$ProgramsDirectory = [Environment]::GetFolderPath('Programs'))
    New-Item -ItemType Directory -Path $ProgramsDirectory -Force | Out-Null
    $shortcutPath = Join-Path $ProgramsDirectory 'O&O ShutUp10.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $null
    try {
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $Executable
        $shortcut.WorkingDirectory = Split-Path -Parent $Executable
        $shortcut.IconLocation = "$Executable,0"
        $shortcut.Description = 'Adjust Windows privacy settings as administrator.'
        $shortcut.Save()
    } finally {
        foreach ($comObject in @($shortcut, $shell)) {
            if ($null -ne $comObject) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($comObject) }
        }
    }
    # Shell Link header: LinkFlags at offset 0x14; RunAsUser (0x2000) requests elevation.
    # https://learn.microsoft.com/openspecs/windows_protocols/ms-shllink/ae350202-3ba9-4790-9e9e-98935f4ee5af
    $bytes = [IO.File]::ReadAllBytes($shortcutPath)
    $flags = [BitConverter]::ToUInt32($bytes, 0x14) -bor 0x2000
    [BitConverter]::GetBytes([uint32]$flags).CopyTo($bytes, 0x14)
    [IO.File]::WriteAllBytes($shortcutPath, $bytes)
    return $shortcutPath
}

function Open-ShutUp10 {
    # The current WinGet package is named O&O ShutUp10 (formerly ShutUp10++).
    Write-Host '[dev-choking] Installing O&O ShutUp10...'
    & winget.exe list --id OO-Software.ShutUp10 --exact --source winget --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        & winget.exe install --id OO-Software.ShutUp10 --exact --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) { throw "O&O ShutUp10 installation failed with exit code $LASTEXITCODE." }
    }
    # Check WinGet's links directly: this process may still have the old PATH.
    $candidates = @(foreach ($root in @("$env:LOCALAPPDATA\Microsoft\WinGet\Links", "$env:ProgramFiles\WinGet\Links")) {
        Join-Path $root 'shutup10.exe'
        Join-Path $root 'OOSU10.exe'
        if (Test-Path -LiteralPath $root -PathType Container) {
            Get-ChildItem -LiteralPath $root -Filter '*shutup10*.exe' -File | Select-Object -ExpandProperty FullName
        }
    })
    $candidates += @(Get-Command shutup10.exe, OOSU10.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    $executable = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $executable) { throw 'O&O is installed, but its executable was not found.' }
    $shortcutPath = New-ShutUp10Shortcut -Executable $executable
    Write-Host "[dev-choking] Start menu shortcut created: $shortcutPath"
    Write-Host '[dev-choking] After restarting, search Start for O&O ShutUp10 and accept its administrator prompt.'
    Write-Host '[dev-choking] Choose your O&O settings manually, then close its window and restart Windows.'
    Start-Process -FilePath $executable -Verb RunAs -Wait
}

function Invoke-Settings {
    $script:manualSteps = New-Object 'System.Collections.Generic.List[string]'
    Write-Host '[dev-choking] Checking Windows setup prerequisites...'
    Assert-Prerequisites
    # Disable AC sleep/display timeouts before downloads or Windows servicing.
    Set-PowerPreferences
    Disable-FastStartup
    Uninstall-OneDrive
    Install-EnglishDisplayLanguage
    Set-DesktopPreferences
    Set-VSCodeContextMenu -SkipIfMissing
    Set-HardwareClockUtc
    Set-LanguageAndRegion
    Set-PrinterDefaults
    Set-WordDefaults
    if ($script:manualSteps.Count -gt 0) {
        Write-Warning 'These items need attention:'
        foreach ($step in $script:manualSteps) { Write-Warning $step }
    }
    Open-ShutUp10
    Write-Host '[dev-choking] Restart Windows to apply the pending display, input, regional, and hardware-clock changes.'
    Write-Host '[dev-choking] After saving your work, restart from Start > Power > Restart.'
    if ($script:manualSteps.Count -gt 0) {
        Write-Warning 'Some settings need manual attention; review the messages above.'
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-Settings } catch {
        Write-Error $_ -ErrorAction Continue
        exit 1
    }
}
