# Windows 10 helpers, loaded by settings.ps1. Run settings.cmd, not this file.

function Install-Windows10EnglishDisplayLanguage {
    param([string]$PackagePath)
    if (Test-EnglishDisplayLanguage) { return }
    if ($PackagePath) {
        $package = Get-Item -LiteralPath $PackagePath -ErrorAction Stop
        if ($package.PSIsContainer -or $package.Extension -ne '.cab') {
            throw 'EnglishLanguagePack must point to an en-US display-language CAB for this Windows version and architecture.'
        }
        Write-Host '[dev-choking] Installing the supplied English display-language pack...'
        $result = Add-WindowsPackage -Online -PackagePath $package.FullName -NoRestart
        if ($result.RestartNeeded) {
            throw 'Language-pack installation requires a restart. Restart Windows, then rerun settings.cmd.'
        }
    } else {
        # Windows 10 has no Install-Language cmdlet. Use Microsoft's download UI.
        Write-Host '[dev-choking] Windows 10 needs the English (United States) display-language pack.'
        Write-Host '[dev-choking] In Language settings, add English (United States) and install its Language pack.'
        Write-Host '[dev-choking] If English is already listed, select it > Options > Download under Language pack.'
        Write-Host '[dev-choking] Wait for installation to finish; keep this console open and do not sign out yet.'
        Start-Process 'ms-settings:regionlanguage'
        Read-Host 'After the language pack is installed, press Enter to continue (Ctrl+C to cancel)' | Out-Null
    }
    if (-not (Test-EnglishDisplayLanguage)) {
        throw 'The en-US display-language pack is not installed yet. Finish its download (or restart if requested), then rerun settings.cmd.'
    }
}

function Initialize-Windows10PowerApi {
    if ('DevChoking.Windows10Power' -as [type]) { return }
    # Legacy overlay API; Windows 11 uses its documented per-source APIs instead.
    # API signature and stored preferences: https://github.com/AaronKelley/PowerMode
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace DevChoking {
    public static class Windows10Power {
        [DllImport("powrprof.dll")]
        public static extern uint PowerSetActiveOverlayScheme(Guid mode);
        [DllImport("powrprof.dll")]
        public static extern uint PowerGetActualOverlayScheme(out Guid mode);
    }
}
'@
}

function Get-Windows10PowerSource {
    Add-Type -AssemblyName System.Windows.Forms
    return [string][System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus
}

function Set-Windows10ActivePowerMode {
    param([guid]$Mode)
    Initialize-Windows10PowerApi
    $result = [DevChoking.Windows10Power]::PowerSetActiveOverlayScheme($Mode)
    if ($result -ne 0) { throw "Setting the Windows 10 power slider failed with Windows error $result." }
    $actual = [guid]::Empty
    $result = [DevChoking.Windows10Power]::PowerGetActualOverlayScheme([ref]$actual)
    if ($result -ne 0 -or $actual -ne $Mode) { throw 'Windows did not retain the requested power slider mode.' }
}

function Set-Windows10PowerPreferences {
    $hasBattery = @(Get-CimInstance -ClassName Win32_Battery).Count -gt 0
    if (-not $hasBattery) {
        # Most Windows 10 desktops do not expose the battery power slider.
        & powercfg.exe /setactive SCHEME_MIN
        if ($LASTEXITCODE -ne 0) { throw "Selecting High performance failed with exit code $LASTEXITCODE." }
        Write-Host '[dev-choking] No battery: High performance power plan.'
        return
    }
    & powercfg.exe /setactive SCHEME_BALANCED
    if ($LASTEXITCODE -ne 0) { throw "Selecting Balanced failed with exit code $LASTEXITCODE." }
    $performance = 'ded574b5-45a0-4f42-8737-46345c09c238'
    $efficiency = '961cc777-2547-4f9d-8174-7d86181b8a7a'
    $powerSource = Get-Windows10PowerSource
    if ($powerSource -eq 'Online') {
        Set-Windows10ActivePowerMode $performance
    } elseif ($powerSource -eq 'Offline') {
        Set-Windows10ActivePowerMode $efficiency
    } else {
        throw 'Windows could not identify AC/battery power. Check the battery slider manually.'
    }
    # Persist BOTH source preferences, including the source not currently connected.
    # The normal end-of-setup restart lets Windows reload these legacy preferences.
    $powerKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes'
    Set-RegistryValue $powerKey 'ActiveOverlayAcPowerScheme' $performance 'String'
    Set-RegistryValue $powerKey 'ActiveOverlayDcPowerScheme' $efficiency 'String'
    Write-Host '[dev-choking] Plugged in: Best performance; battery: Better battery. Restart to load both preferences.'
}

function Invoke-Windows10InternationalImport {
    param([string]$Xml)
    $xmlPath = Join-Path ([System.IO.Path]::GetTempPath()) ('dev-choking-region-' + [guid]::NewGuid().ToString('N') + '.xml')
    try {
        [System.IO.File]::WriteAllText($xmlPath, $Xml, [System.Text.UTF8Encoding]::new($false))
        $control = Join-Path ([Environment]::GetFolderPath('System')) 'control.exe'
        $process = Start-Process -FilePath $control -ArgumentList ('intl.cpl,,/f:"' + $xmlPath + '"') -WindowStyle Hidden -Wait -PassThru
        return $process.ExitCode
    } finally {
        if (Test-Path -LiteralPath $xmlPath) { Remove-Item -LiteralPath $xmlPath -Force }
    }
}

function New-Windows10CopyCurrentInternationalXml {
    return @'
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
  <gs:UserList>
    <gs:User UserID="Current" CopySettingsToDefaultUserAcct="true" CopySettingsToSystemAcct="true" />
  </gs:UserList>
</gs:GlobalizationServices>
'@
}

function New-Windows10ExplicitInternationalXml {
    param([string]$KoreanTip)
    # The retry keeps the same supported XML import path, but stops intl.cpl from
    # having to infer the post-language-change values from the current profile.
    return @"
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
  <gs:UserList>
    <gs:User UserID="Current" CopySettingsToDefaultUserAcct="true" CopySettingsToSystemAcct="true" />
  </gs:UserList>
  <gs:MUILanguagePreferences>
    <gs:MUILanguage Value="en-US" />
  </gs:MUILanguagePreferences>
  <gs:SystemLocale Name="en-US" />
  <gs:InputPreferences>
    <gs:InputLanguageID Action="add" ID="$KoreanTip" Default="true" />
    <gs:InputLanguageID Action="remove" ID="0409:00000409" />
  </gs:InputPreferences>
  <gs:UserLocale>
    <gs:Locale Name="en-GB" SetAsCurrent="true" ResetAllSettings="false">
      <gs:Win32>
        <gs:sShortDate>yyyy-MM-dd</gs:sShortDate>
        <gs:sLongDate>yyyy-MM-dd</gs:sLongDate>
        <gs:sShortTime>HH:mm</gs:sShortTime>
        <gs:sTimeFormat>HH:mm:ss</gs:sTimeFormat>
        <gs:iMeasure>0</gs:iMeasure>
        <gs:iPaperSize>9</gs:iPaperSize>
      </gs:Win32>
    </gs:Locale>
  </gs:UserLocale>
</gs:GlobalizationServices>
"@
}

function Copy-Windows10InternationalDefaults {
    param([string]$KoreanTip)
    # Copy Settings is still part of intl.cpl on Windows 10. Current-user language
    # and input were already set with International cmdlets; do not reset them here.
    # https://learn.microsoft.com/troubleshoot/windows-client/setup-upgrade-and-drivers/automate-regional-language-settings
    $copyExit = Invoke-Windows10InternationalImport -Xml (New-Windows10CopyCurrentInternationalXml)
    if ($copyExit -ne 0) {
        Write-Warning "Copy-only international import failed with exit code $copyExit; retrying with explicit Windows 10 settings."
        $explicitExit = Invoke-Windows10InternationalImport -Xml (New-Windows10ExplicitInternationalXml -KoreanTip $KoreanTip)
        if ($explicitExit -ne 0) {
            throw "Copying international defaults failed. Copy-only import exit code: $copyExit; explicit import exit code: $explicitExit."
        }
    }
    # intl.cpl can fail silently. Check representative welcome-screen values.
    $current = Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\International'
    $welcome = Get-ItemProperty -LiteralPath 'Registry::HKEY_USERS\.DEFAULT\Control Panel\International'
    foreach ($name in @('LocaleName', 'sShortDate', 'sTimeFormat', 'iMeasure', 'iPaperSize')) {
        if ($welcome.$name -ne $current.$name) {
            throw "Welcome-screen setting $name was not copied."
        }
    }
}
