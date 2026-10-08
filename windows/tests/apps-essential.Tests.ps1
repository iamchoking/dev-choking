# Run: powershell -NoProfile -ExecutionPolicy Bypass -File windows\tests\apps-essential.Tests.ps1
# All installation and discovery calls below are mocked; no apps are installed.
$ErrorActionPreference = 'Stop'
$setupScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'apps-essential_amd64.ps1'
. $setupScript
$apps = @(Get-EssentialApps)

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

& {
    . $setupScript
    function Test-Path {
        param($LiteralPath, $PathType)
        return $LiteralPath -eq $script:registryPath -or $LiteralPath -eq $script:executablePath
    }
    function Get-ChildItem {
        param($LiteralPath, [switch]$Directory)
        if ($Directory) {
            return [pscustomobject]@{Name = '132.0.0.0'; FullName = (Join-Path $LiteralPath '132.0.0.0')}
        }
        $key = [pscustomobject]@{DisplayName = $script:displayName}
        $key | Add-Member -MemberType ScriptMethod -Name GetValue -Value {
            param($Name)
            if ($Name -eq 'DisplayName') { return $this.DisplayName }
        }
        return $key
    }
    function Get-Item {
        param($LiteralPath)
        $key = [pscustomobject]@{ExecutablePath = $script:executablePath}
        $key | Add-Member -MemberType ScriptMethod -Name GetValue -Value {
            param($Name)
            return '"' + $this.ExecutablePath + '"'
        }
        return $key
    }
    function Get-Command { param($Name, $CommandType, $ErrorAction) return $null }

    $script:executablePath = $null
    foreach ($root in @('HKLM:\Software', 'HKLM:\Software\WOW6432Node',
        'HKCU:\Software', 'HKCU:\Software\WOW6432Node')) {
        $script:registryPath = Join-Path $root 'Microsoft\Windows\CurrentVersion\Uninstall'
        foreach ($case in @(
            @{App = $apps[0]; Name = 'Microsoft Visual Studio Code (User)'},
            @{App = $apps[1]; Name = 'Google Chrome'},
            @{App = $apps[2]; Name = 'Google Drive'}
        )) {
            $script:displayName = $case.Name
            $evidence = Get-LocalAppEvidence $case.App
            Assert-Condition ($evidence -like 'Windows installation record:*') "Missed $($case.Name) in $root"
        }
    }
    $script:displayName = 'Google Chrome Beta'
    Assert-Condition ($null -eq (Get-LocalAppEvidence $apps[1])) 'Chrome Beta must not count as stable Chrome'

    $script:registryPath = $null
    foreach ($path in @(
        (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
    )) {
        $script:executablePath = $path
        Assert-Condition ((Get-LocalAppEvidence $apps[1]) -like 'executable:*') "Missed Chrome executable: $path"
    }
    $script:registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe'
    $script:executablePath = 'C:\Custom Chrome\chrome.exe'
    Assert-Condition ((Get-LocalAppEvidence $apps[1]) -like 'registered executable:*') 'Missed custom Chrome App Paths registration'

    $script:registryPath = Join-Path $env:ProgramFiles 'Google\Drive File Stream'
    $script:executablePath = Join-Path $script:registryPath '132.0.0.0\GoogleDriveFS.exe'
    Assert-Condition ((Get-LocalAppEvidence $apps[2]) -like 'executable:*') 'Missed versioned Google Drive executable'
    Write-Host 'PASS: machine/user registry views, Chrome executable paths, custom paths, versioned Drive, and Chrome Beta exclusion.'
}

& {
    . $setupScript
    function Get-LocalAppEvidence { param($App) return $script:evidence }
    function Get-Process { param($Name, $ErrorAction) return $null }
    function Set-VSCodeContextMenu { }
    function Invoke-AppWinget {
        param([string[]]$Arguments, [switch]$ShowOutput)
        $script:calls.Add($Arguments -join ' ')
        if ($Arguments[0] -eq 'list') {
            return [pscustomobject]@{ExitCode = $script:lookupExit; Output = 'Simulated lookup'}
        }
        Assert-Condition $ShowOutput 'Installer output must be shown'
        if ($Arguments -contains 'Microsoft.VisualStudioCode') {
            Assert-Condition ($Arguments -contains '--force' -and $Arguments -contains '--override' -and $Arguments -contains 'x64') 'Wrong VS Code installer options'
            $overrideIndex = [Array]::IndexOf($Arguments, '--override')
            Assert-Condition ($Arguments[$overrideIndex + 1] -ceq '/verysilent /suppressmsgboxes /norestart /log /mergetasks=!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath') 'VS Code override must reach WinGet as one argument without literal single quotes'
        } else {
            Assert-Condition ($Arguments -contains 'x64' -and $Arguments -contains 'machine') 'Wrong installer options'
        }
        return [pscustomobject]@{ExitCode = $script:installExit; Output = 'Simulated installer'}
    }
    foreach ($app in $apps) {
        foreach ($case in @('local-installed', 'winget-installed', 'absent', 'lookup-error', 'install-error')) {
            $script:calls = [System.Collections.Generic.List[string]]::new()
            $script:evidence = if ($case -eq 'local-installed') { 'Windows installation record' } else { $null }
            $script:lookupExit = if ($case -eq 'winget-installed') { 0 } elseif ($case -eq 'lookup-error') { -1978335217 } else { -1978335212 }
            $script:installExit = if ($case -eq 'install-error') { -1978335215 } else { 0 }
            $failed = $false
            try { Install-EssentialApp $app *> $null } catch { $failed = $true }
            $isVSCode = $app.Id -eq 'Microsoft.VisualStudioCode'
            $expectedFailure = $case -eq 'install-error' -or (-not $isVSCode -and $case -eq 'lookup-error')
            Assert-Condition ($failed -eq $expectedFailure) "Wrong outcome for $($app.Id): $case"
            $expectedCalls = if ($isVSCode) { 1 } elseif ($case -eq 'local-installed') { 0 } elseif ($case -in @('absent', 'install-error')) { 2 } else { 1 }
            Assert-Condition ($script:calls.Count -eq $expectedCalls) "Unexpected download attempt for $($app.Id): $case"
        }
    }
    Write-Host 'PASS: VS Code always applies installer tasks; Chrome/Drive skip existing installs; lookup/install failures propagate.'
}

& {
    . $setupScript
    function Get-Process { param($Name, $ErrorAction) return [pscustomobject]@{ProcessName = 'CodeSetup-stable'} }
    function Invoke-AppWinget { throw 'WinGet must not run while VS Code is updating' }
    $failure = $null
    try { Install-EssentialApp $apps[0] *> $null } catch { $failure = $_ }
    Assert-Condition ($null -ne $failure -and $failure.Exception.Message -match 'Let any VS Code update finish') 'Missing instructions for an active VS Code updater'
    Write-Host 'PASS: an active VS Code updater prevents a conflicting installation.'
}
