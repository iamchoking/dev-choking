# Run: powershell -NoProfile -ExecutionPolicy Bypass -File windows\tests\settings-word.Tests.ps1
# Mocks Word COM close/quit signatures; does not open Word or change settings.
$ErrorActionPreference = 'Stop'
$setupScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'settings.ps1'
. $setupScript

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

class FakeWordDocument {
    [int]$CloseCalls = 0
    [void] Close([ref]$SaveChanges, [ref]$OriginalFormat, [ref]$RouteDocument) {
        $this.CloseCalls++
        if ($SaveChanges.Value -ne 0) { throw 'Document close should not save again.' }
    }
}

class FakeWordApplication {
    [int]$QuitCalls = 0
    [void] Quit([ref]$SaveChanges, [ref]$OriginalFormat, [ref]$RouteDocument) {
        $this.QuitCalls++
        if ($SaveChanges.Value -ne 0) { throw 'Application quit should not save again.' }
    }
}

$document = [FakeWordDocument]::new()
Close-WordComObject -ComObject $document -Kind Document
Assert-Condition ($document.CloseCalls -eq 1) 'Word document close must be invoked with reference arguments.'
Write-Host 'PASS: Word document close uses reference arguments.'

$application = [FakeWordApplication]::new()
Close-WordComObject -ComObject $application -Kind Application
Assert-Condition ($application.QuitCalls -eq 1) 'Word application quit must be invoked with reference arguments.'
Write-Host 'PASS: Word application quit uses reference arguments.'
