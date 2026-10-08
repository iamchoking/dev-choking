# Run: powershell -NoProfile -ExecutionPolicy Bypass -File windows\tests\settings-progress.Tests.ps1
# Uses harmless PowerShell jobs and mocks language installation; no settings change.
$ErrorActionPreference = 'Stop'
$setupScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'settings.ps1'
. $setupScript

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

foreach ($case in @('ready', 'sleep-error', 'screen-error', 'prerequisite-error')) {
    & {
        . $setupScript
        $script:sleepDisabled = $false
        $script:screenDisabled = $false
        $script:languageCalls = 0
        $script:powerCalls = 0
        function Assert-Prerequisites {
            if ($case -eq 'prerequisite-error') { throw 'Simulated prerequisite failure' }
            $script:isWindows11 = $true
        }
        function Set-Windows11PowerPreferences { }
        function powercfg.exe {
            $script:powerCalls++
            $global:LASTEXITCODE = 0
            if ($args[1] -eq 'standby-timeout-ac') {
                if ($case -eq 'sleep-error') { $global:LASTEXITCODE = 1 }
                else { $script:sleepDisabled = $true }
            } elseif ($args[1] -eq 'monitor-timeout-ac') {
                if ($case -eq 'screen-error') { $global:LASTEXITCODE = 1 }
                else { $script:screenDisabled = $true }
            } else { throw "Unexpected power command: $args" }
        }
        function Uninstall-OneDrive {
            Assert-Condition ($script:sleepDisabled -and $script:screenDisabled) 'App removal started before AC timeouts were disabled'
        }
        function Install-EnglishDisplayLanguage {
            Assert-Condition ($script:sleepDisabled -and $script:screenDisabled) 'Language installation could suspend while waiting'
            $script:languageCalls++
        }
        function Set-DesktopPreferences { }
        function Set-VSCodeContextMenu { param([switch]$SkipIfMissing) }
        function Set-HardwareClockUtc { }
        function Set-LanguageAndRegion { }
        function Set-PrinterDefaults { }
        function Set-WordDefaults { }
        function Open-ShutUp10 { }
        $failure = $null
        try { Invoke-Settings *> $null } catch { $failure = $_ }
        Assert-Condition (($null -ne $failure) -eq ($case -ne 'ready')) "Wrong setup result: $case"
        $expectedLanguageCalls = if ($case -eq 'ready') { 1 } else { 0 }
        Assert-Condition ($script:languageCalls -eq $expectedLanguageCalls) "Unsafe language download attempt: $case"
        $expectedPowerCalls = if ($case -eq 'prerequisite-error') { 0 } elseif ($case -eq 'sleep-error') { 1 } else { 2 }
        Assert-Condition ($script:powerCalls -eq $expectedPowerCalls) "Unexpected power changes: $case"
        Write-Host "PASS: setup protects downloads against sleep and screen timeouts ($case)."
    }
}

$job = Start-Job -ScriptBlock { Start-Sleep -Seconds 2; 'Simulated installed resources' }
$jobId = $job.InstanceId
$messages = @(Wait-SettingsJob -Job $job -Activity 'test download' -HeartbeatSeconds 1 6>&1) | Out-String
Assert-Condition ($messages -match 'Waiting for test download' -and $messages -match 'Finished test download') 'Missing wait/completion messages'
Assert-Condition (@(Get-Job | Where-Object InstanceId -eq $jobId).Count -eq 0) 'Completed job was not cleaned up'
Write-Host 'PASS: slow work prints elapsed-time messages and completed work is cleaned up.'

$job = Start-Job -ScriptBlock { throw 'Simulated language download failure' }
$jobId = $job.InstanceId
$failure = $null
try { Wait-SettingsJob -Job $job -Activity 'failed test download' -HeartbeatSeconds 1 *> $null } catch { $failure = $_ }
Assert-Condition ($null -ne $failure -and $failure.Exception.Message -match 'Simulated language download failure') 'Language installation failure was hidden'
Assert-Condition (@(Get-Job | Where-Object InstanceId -eq $jobId).Count -eq 0) 'Failed job was not cleaned up'
Write-Host 'PASS: installation failures propagate and failed jobs are cleaned up.'

& {
    . $setupScript
    function Test-EnglishDisplayLanguage { return $true }
    function Install-Language { throw 'An existing display pack must not download again' }
    Install-Windows11EnglishDisplayLanguage *> $null
    Write-Host 'PASS: an existing English display pack skips installation.'
}

& {
    . $setupScript
    function Test-EnglishDisplayLanguage { return $false }
    function Install-Language {
        param($Language, [switch]$CopyToSettings, [switch]$ExcludeFeatures, [switch]$AsJob, $ErrorAction)
        Assert-Condition ($Language -eq 'en-US' -and $CopyToSettings -and $ExcludeFeatures -and $AsJob) 'Display installation must exclude bulk optional features'
        return Start-Job -ScriptBlock { 'Simulated English display pack installation' }
    }
    Install-Windows11EnglishDisplayLanguage *> $null
    Write-Host 'PASS: a missing English display pack installs as a monitored job.'
}

& {
    . $setupScript
    function Get-WindowsCapability {
        param([switch]$Online, $Name)
        return [pscustomobject]@{State = $script:capabilityState}
    }
    function Add-WindowsCapability {
        param([switch]$Online, $Name)
        $script:addCalls++
        if ($script:finishInstallation) { $script:capabilityState = 'Installed' }
    }
    foreach ($case in @('already-installed', 'missing', 'partial')) {
        $script:addCalls = 0
        $script:capabilityState = if ($case -eq 'already-installed') { 'Installed' } else { 'NotPresent' }
        $script:finishInstallation = $case -eq 'missing'
        $failure = $null
        try { Install-LanguageCapability 'Language.Basic~~~en-US~0.0.1.0' *> $null } catch { $failure = $_ }
        Assert-Condition (($null -ne $failure) -eq ($case -eq 'partial')) "Wrong required-language-component result: $case"
        $expectedAdds = if ($case -eq 'already-installed') { 0 } else { 1 }
        Assert-Condition ($script:addCalls -eq $expectedAdds) "Unexpected repeated installation: $case"
    }
    Write-Host 'PASS: required language components skip existing resources and reject partial installation.'
}
