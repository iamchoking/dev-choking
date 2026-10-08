# Windows 11 helpers, loaded by settings.ps1. Run settings.cmd, not this file.

function Install-Windows11EnglishDisplayLanguage {
    if (Test-EnglishDisplayLanguage) {
        Write-Host '[dev-choking] English display-language pack is already installed; skipping download.'
        return
    }
    Write-Host '[dev-choking] Downloading and installing the English display-language pack. This can take several minutes...'
    # Download only the display pack. Required typing/fonts are installed and
    # checked individually by Set-LanguageAndRegion, rather than requesting all
    # optional speech, handwriting, and OCR features in one bulk installation.
    $job = Install-Language -Language 'en-US' -CopyToSettings -ExcludeFeatures -AsJob -ErrorAction Stop
    Wait-SettingsJob -Job $job -Activity 'English display-language installation'
}

function Set-Windows11SystemUiLanguage {
    Set-SystemPreferredUILanguage 'en-US'
}

function Set-Windows11TaskbarAlignment {
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAl' 0
}

function Initialize-Windows11PowerApi {
    if ('DevChoking.PowerModes' -as [type]) { return }
    # Documented Windows 11 APIs persist separate AC/DC choices and apply them.
    # https://learn.microsoft.com/windows/win32/api/powrprof/nf-powrprof-powersetuserconfiguredacpowermode
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace DevChoking {
    public static class PowerModes {
        [DllImport("powrprof.dll")]
        public static extern uint PowerSetUserConfiguredACPowerMode(ref Guid mode);
        [DllImport("powrprof.dll")]
        public static extern uint PowerSetUserConfiguredDCPowerMode(ref Guid mode);
        [DllImport("powrprof.dll")]
        public static extern uint PowerGetUserConfiguredACPowerMode(out Guid mode);
        [DllImport("powrprof.dll")]
        public static extern uint PowerGetUserConfiguredDCPowerMode(out Guid mode);
    }
}
'@
}

function Set-Windows11PowerPreferences {
    Initialize-Windows11PowerApi
    # The Balanced base plan allows Windows to apply the AC/DC power modes.
    & powercfg.exe /setactive SCHEME_BALANCED
    if ($LASTEXITCODE -ne 0) { throw "powercfg failed with exit code $LASTEXITCODE." }
    $performance = [guid]'ded574b5-45a0-4f42-8737-46345c09c238'
    $efficiency = [guid]'961cc777-2547-4f9d-8174-7d86181b8a7a'
    $result = [DevChoking.PowerModes]::PowerSetUserConfiguredACPowerMode([ref]$performance)
    if ($result -ne 0) { throw "Setting AC power mode failed with Windows error $result." }
    Write-Host '[dev-choking] Plugged in: Best performance.'
    if (@(Get-CimInstance -ClassName Win32_Battery).Count -gt 0) {
        $result = [DevChoking.PowerModes]::PowerSetUserConfiguredDCPowerMode([ref]$efficiency)
        if ($result -ne 0) { throw "Setting battery power mode failed with Windows error $result." }
        Write-Host '[dev-choking] On battery: Best power efficiency.'
    } else {
        Write-Host '[dev-choking] No battery detected; skipped the battery power mode.'
    }
}

function Copy-Windows11InternationalDefaults {
    # A fresh process reads the newly selected culture and its custom formats.
    & "$PSHOME\powershell.exe" -NoProfile -Command 'Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true -ErrorAction Stop'
    if ($LASTEXITCODE -ne 0) { throw 'Could not copy language/region/input settings to the welcome screen and new users.' }
}
