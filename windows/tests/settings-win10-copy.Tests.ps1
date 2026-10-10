# Run: powershell -NoProfile -ExecutionPolicy Bypass -File windows\tests\settings-win10-copy.Tests.ps1
# Mocks intl.cpl imports; does not change this computer's settings.
$ErrorActionPreference = 'Stop'
$setupScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'settings.ps1'

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-CopyScenario {
    param([int[]]$ExitCodes)
    . $setupScript
    $script:xmlImports = New-Object 'System.Collections.Generic.List[string]'
    $script:exitCodes = New-Object 'System.Collections.Generic.Queue[int]'
    foreach ($code in $ExitCodes) { $script:exitCodes.Enqueue($code) }

    function Start-Process {
        param($FilePath, $ArgumentList, $WindowStyle, [switch]$Wait, [switch]$PassThru)
        if ($ArgumentList -notmatch '/f:"([^"]+)"') { throw "Unexpected intl.cpl arguments: $ArgumentList" }
        $script:xmlImports.Add([System.IO.File]::ReadAllText($Matches[1]))
        return [pscustomobject]@{ExitCode = $script:exitCodes.Dequeue()}
    }

    function Get-ItemProperty {
        param([string]$LiteralPath)
        return [pscustomobject]@{
            LocaleName = 'en-GB'
            sShortDate = 'yyyy-MM-dd'
            sTimeFormat = 'HH:mm:ss'
            iMeasure = '0'
            iPaperSize = '9'
        }
    }

    $failure = $null
    try {
        Copy-Windows10InternationalDefaults -KoreanTip '0412:{A028AE76-01B1-46C2-99C4-ACD9858AE02F}{B5FE1F02-D5F2-4445-9C03-C568F23C99A1}' *> $null
    } catch {
        $failure = $_
    }
    return [pscustomobject]@{Failure = $failure; XmlImports = @($script:xmlImports)}
}

$result = Invoke-CopyScenario -ExitCodes @(0)
Assert-Condition ($null -eq $result.Failure) 'Copy-only import should succeed when intl.cpl returns 0.'
Assert-Condition ($result.XmlImports.Count -eq 1) 'Copy-only success should use one import.'
Assert-Condition ($result.XmlImports[0] -match 'CopySettingsToDefaultUserAcct="true"') 'Copy XML must target new users.'
Write-Host 'PASS: Windows 10 copy-only international import succeeds.'

$result = Invoke-CopyScenario -ExitCodes @(1, 0)
Assert-Condition ($null -eq $result.Failure) 'Explicit retry should recover from copy-only intl.cpl exit code 1.'
Assert-Condition ($result.XmlImports.Count -eq 2) 'Fallback should perform exactly two imports.'
Assert-Condition ($result.XmlImports[1] -match '<gs:MUILanguage Value="en-US"') 'Fallback XML must set English display language.'
Assert-Condition ($result.XmlImports[1] -match '<gs:SystemLocale Name="en-US"') 'Fallback XML must set English system locale.'
Assert-Condition ($result.XmlImports[1] -match '0412:\{A028AE76-01B1-46C2-99C4-ACD9858AE02F\}\{B5FE1F02-D5F2-4445-9C03-C568F23C99A1\}') 'Fallback XML must set Korean IME.'
Assert-Condition ($result.XmlImports[1] -match '<gs:sShortDate>yyyy-MM-dd</gs:sShortDate>') 'Fallback XML must preserve short date.'
Write-Host 'PASS: Windows 10 international import retries with explicit settings.'

$result = Invoke-CopyScenario -ExitCodes @(1, 1)
Assert-Condition ($null -ne $result.Failure) 'Repeated intl.cpl failures should still report a failure.'
Assert-Condition ($result.Failure.Exception.Message -match 'Copy-only import exit code: 1; explicit import exit code: 1') 'Failure should include both exit codes.'
Write-Host 'PASS: Windows 10 international import reports both failing exit codes.'
