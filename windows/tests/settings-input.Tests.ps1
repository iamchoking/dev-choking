# Run: powershell -NoProfile -ExecutionPolicy Bypass -File windows\tests\settings-input.Tests.ps1
# Mocks settings and native input changes; does not change this computer's settings.
$ErrorActionPreference = 'Stop'
$setupScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'settings.ps1'

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

foreach ($case in @('restored-US', 'already-Korean-only', 'native-failure', 'ineffective-native', 'copy-restores-US')) {
    & {
        . $setupScript
        $script:isWindows11 = $true
        $script:events = New-Object 'System.Collections.Generic.List[string]'
        $script:nativeCalls = 0
        $script:copyCalls = 0
        $script:uiLanguage = $null
        $script:culture = $null
        $script:regional = @{}
        function Install-LanguageCapability { param($Name) }
        function Set-Windows11SystemUiLanguage { }
        function Set-WinUILanguageOverride { param($Language) $script:uiLanguage = $Language }
        function Set-WinSystemLocale { param($Language) }
        function Set-WinDefaultInputMethodOverride { param($InputTip) $script:defaultTip = $InputTip }
        function Set-WinLanguageBarOption { }
        function Set-Culture { param($CultureInfo) $script:culture = $CultureInfo; $script:events.Add('culture') }
        function Set-UserLocaleFormat {
            param($LocaleType, $Value)
            $names = @{0x1f='sShortDate'; 0x20='sLongDate'; 0x79='sShortTime'; 0x1003='sTimeFormat'; 0x0d='iMeasure'; 0x100a='iPaperSize'}
            $script:regional[$names[[int]$LocaleType]] = $Value
        }
        function Update-RegionalFormatNotification { }
        function Update-WindowsSearchLanguage { }
        function Set-RegistryValue {
            param($Path, $Name, $Value, $Type)
            if ($Path -eq 'HKCU:\Control Panel\International') { $script:regional[$Name] = $Value }
        }
        function Set-WinUserLanguageList {
            param($LanguageList, [switch]$Force)
            $script:languages = $LanguageList
            # Reproduce this machine's behavior: an empty English keyboard list
            # gets normalized back to US, even though Korean is the default IME.
            if ($case -ne 'already-Korean-only') { $script:languages[0].InputMethodTips.Add('0409:00000409') }
            $script:events.Add('languages')
        }
        function Get-WinUserLanguageList { return ,$script:languages }
        function Invoke-InputProfileInstall {
            param($Tip, $Flags)
            $script:nativeCalls++
            Assert-Condition ($Flags -eq 0x42 -and $Tip -eq $script:defaultTip) 'Wrong native input profile or flags'
            Assert-Condition ($script:culture -eq 'en-GB' -and $script:regional.sShortTime -eq 'HH:mm') 'Input enforcement must follow regional changes'
            if ($case -eq 'native-failure') { return $false }
            if ($case -ne 'ineffective-native') { $script:languages[0].InputMethodTips.Clear() }
            $script:events.Add('input')
            return $true
        }
        function Copy-InternationalDefaults {
            $script:copyCalls++
            Assert-KoreanOnlyInputProfiles -KoreanTip $script:defaultTip
            $script:events.Add('copy')
            # Model the normalization seen when copying international defaults.
            $script:regional.sShortDate = 'dd/MM/yyyy'
            if ($case -eq 'copy-restores-US') { $script:languages[0].InputMethodTips.Add('0409:00000409') }
        }
        $failure = $null
        try { Set-LanguageAndRegion *> $null } catch { $failure = $_ }
        $expectedFailure = $case -in @('native-failure', 'ineffective-native', 'copy-restores-US')
        Assert-Condition (($null -ne $failure) -eq $expectedFailure) "Wrong input configuration result: $case"
        $expectedNativeCalls = if ($case -eq 'already-Korean-only') { 0 } else { 1 }
        $expectedCopyCalls = if ($case -in @('native-failure', 'ineffective-native')) { 0 } else { 1 }
        Assert-Condition ($script:nativeCalls -eq $expectedNativeCalls -and $script:copyCalls -eq $expectedCopyCalls) "Unexpected native/copy calls: $case"
        Assert-Condition ($script:uiLanguage -eq 'en-US' -and $script:languages[0].LanguageTag -eq 'en-US') 'English UI and preferred language must be preserved'
        Assert-Condition ($script:regional.iMeasure -eq '0' -and $script:regional.iPaperSize -eq '9') 'Metric/A4 preferences must be preserved'
        Assert-Condition ($script:regional.sShortDate -eq 'yyyy-MM-dd') 'Date must use yyyy-MM-dd'
        if ($case -eq 'copy-restores-US') {
            Assert-Condition ($failure.Exception.Message -match '0409:00000409') 'Failure must identify the unexpected keyboard'
        }
        Write-Host "PASS: $case"
    }
}

& {
    . $setupScript
    $script:languages = New-DesiredLanguageList
    # The same IME may be associated with multiple language entries; it still
    # represents one input method. Do not fail solely because of duplicates.
    $koreanTip = $script:languages[1].InputMethodTips[0]
    $script:languages[0].InputMethodTips.Add($koreanTip)
    function Get-WinUserLanguageList { return ,$script:languages }
    Assert-KoreanOnlyInputProfiles -KoreanTip $koreanTip
    Write-Host 'PASS: duplicate references to the same IME are one enabled input method.'
}
