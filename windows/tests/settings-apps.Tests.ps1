# Run: powershell -NoProfile -ExecutionPolicy Bypass -File windows\tests\settings-apps.Tests.ps1
# Mocks app removal/launch and creates a shortcut in a temporary test directory.
$ErrorActionPreference = 'Stop'
$setupScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'settings.ps1'

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

foreach ($case in @('installed', 'absent', 'lookup-error', 'uninstall-error')) {
    & {
        . $setupScript
        $script:calls = [System.Collections.Generic.List[string]]::new()
        function winget.exe {
            $script:calls.Add($args -join ' ')
            Assert-Condition ($args -contains 'Microsoft.OneDrive' -and $args -contains '--exact') 'Removal must target only Microsoft OneDrive'
            if ($args[0] -eq 'list') {
                $global:LASTEXITCODE = if ($case -eq 'absent') { -1978335212 } elseif ($case -eq 'lookup-error') { -1978335217 } else { 0 }
            } else {
                Assert-Condition ($args[0] -eq 'uninstall' -and $args -contains '--silent') 'OneDrive must be uninstalled silently'
                $global:LASTEXITCODE = if ($case -eq 'uninstall-error') { -1978335215 } else { 0 }
            }
        }
        $failure = $null
        try { Uninstall-OneDrive *> $null } catch { $failure = $_ }
        Assert-Condition (($null -ne $failure) -eq ($case -in @('lookup-error', 'uninstall-error'))) "Wrong OneDrive removal result: $case"
        $expectedCalls = if ($case -in @('installed', 'uninstall-error')) { 2 } else { 1 }
        Assert-Condition ($script:calls.Count -eq $expectedCalls) "Unexpected uninstall attempt: $case"
        Write-Host "PASS: OneDrive $case"
    }
}

. $setupScript
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('dev-choking-settings-apps-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $executable = Join-Path $testRoot 'shutup10.exe'
    [IO.File]::WriteAllBytes($executable, [byte[]]@(77, 90))
    $programs = Join-Path $testRoot 'Start Menu Programs'
    # Check creation and reruns using a real shortcut without launching the app.
    foreach ($attempt in 1..2) {
        $shortcutPath = New-ShutUp10Shortcut -Executable $executable -ProgramsDirectory $programs
        $bytes = [IO.File]::ReadAllBytes($shortcutPath)
        Assert-Condition (([BitConverter]::ToUInt32($bytes, 0x14) -band 0x2000) -ne 0) 'Start menu shortcut must request administrator privileges'
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $null
        try {
            $shortcut = $shell.CreateShortcut($shortcutPath)
            Assert-Condition ($shortcut.TargetPath -eq $executable) 'Shortcut must reopen the installed executable'
            Assert-Condition ($shortcut.WorkingDirectory -eq $testRoot) 'Wrong shortcut working directory'
        } finally {
            foreach ($comObject in @($shortcut, $shell)) {
                if ($null -ne $comObject) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($comObject) }
            }
        }
    }
    Write-Host 'PASS: Start menu shortcut preserves its executable target and administrator flag on reruns.'

    & {
        . $setupScript
        function winget.exe { $global:LASTEXITCODE = 0 }
        function Test-Path { param($LiteralPath, $PathType) return $LiteralPath -eq $executable }
        function Get-Command { param($Name, $CommandType, $ErrorAction) return [pscustomobject]@{Source = $executable} }
        function New-ShutUp10Shortcut { param($Executable) return 'Test shortcut.lnk' }
        function Start-Process {
            param($FilePath, $Verb, [switch]$Wait)
            Assert-Condition ($FilePath -eq $executable -and $Verb -eq 'RunAs' -and $Wait) 'ShutUp10 must run as administrator and wait for manual settings'
            $script:launchCalls++
        }
        $script:launchCalls = 0
        Open-ShutUp10 *> $null
        Assert-Condition ($script:launchCalls -eq 1) 'ShutUp10 was not launched'
        Write-Host 'PASS: ShutUp10 launches with explicit elevation and waits for the user.'
    }
} finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolvedTestRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $resolvedTestRoot) -notlike 'dev-choking-settings-apps-*') {
        throw 'Refusing to delete a test directory outside the expected temporary location.'
    }
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
}
