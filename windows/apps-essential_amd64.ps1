# Run apps-essential_amd64.cmd. Dot-source this file to inspect/test functions.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'vscode-context-menu.ps1')

function Set-GitIdentity {
    if (-not (Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue)) {
        throw 'Git is unavailable. Install Git for Windows, then reopen CMD and retry.'
    }
    # Match the personal identity configured by ubuntu/ubuntu-basic.sh.
    & git.exe config --global user.name 'iamchoking'
    if ($LASTEXITCODE -ne 0) { throw "Could not set Git user.name (exit $LASTEXITCODE)." }
    & git.exe config --global user.email 'iamchoking247@gmail.com'
    if ($LASTEXITCODE -ne 0) { throw "Could not set Git user.email (exit $LASTEXITCODE)." }
    Write-Host '[dev-choking] Git identity: iamchoking <iamchoking247@gmail.com>.'
}

function Get-EssentialApps {
    [pscustomobject]@{
        Id = 'Microsoft.VisualStudioCode'
        DisplayNamePattern = '^Microsoft Visual Studio Code(?: \((?:User|System)\))?$'
        Executable = 'Code.exe'
        MachinePath = 'Microsoft VS Code\Code.exe'
        UserPath = 'Programs\Microsoft VS Code\Code.exe'
        VersionedMachineDirectory = $null
    }
    [pscustomobject]@{
        Id = 'Google.Chrome'
        DisplayNamePattern = '^Google Chrome$'
        Executable = 'chrome.exe'
        MachinePath = 'Google\Chrome\Application\chrome.exe'
        UserPath = 'Google\Chrome\Application\chrome.exe'
        VersionedMachineDirectory = $null
    }
    [pscustomobject]@{
        Id = 'Google.GoogleDrive'
        DisplayNamePattern = '^Google Drive(?: for desktop)?$'
        Executable = 'GoogleDriveFS.exe'
        MachinePath = 'Google\Drive File Stream\GoogleDriveFS.exe'
        UserPath = 'Google\Drive File Stream\GoogleDriveFS.exe'
        VersionedMachineDirectory = 'Google\Drive File Stream'
    }
}

function Get-LocalAppEvidence {
    param($App)
    # Standard installers, including those launched by Chocolatey, register here.
    # Check machine/current-user installations in both registry views.
    foreach ($root in @('HKLM:\Software', 'HKLM:\Software\WOW6432Node',
        'HKCU:\Software', 'HKCU:\Software\WOW6432Node')) {
        $uninstall = Join-Path $root 'Microsoft\Windows\CurrentVersion\Uninstall'
        if (Test-Path -LiteralPath $uninstall) {
            foreach ($key in (Get-ChildItem -LiteralPath $uninstall)) {
                $displayName = $key.GetValue('DisplayName')
                if ($displayName -and $displayName -match $App.DisplayNamePattern) {
                    return "Windows installation record: $displayName"
                }
            }
        }
        $appPath = Join-Path $root ('Microsoft\Windows\CurrentVersion\App Paths\' + $App.Executable)
        if (Test-Path -LiteralPath $appPath) {
            $executablePath = (Get-Item -LiteralPath $appPath).GetValue('')
            if ($executablePath -and (Test-Path -LiteralPath ($executablePath.Trim('"')) -PathType Leaf)) {
                return "registered executable: $executablePath"
            }
        }
    }

    foreach ($root in @($env:ProgramW6432, $env:ProgramFiles, ${env:ProgramFiles(x86)}) |
        Where-Object { $_ } | Select-Object -Unique) {
        $executablePath = Join-Path $root $App.MachinePath
        if (Test-Path -LiteralPath $executablePath -PathType Leaf) { return "executable: $executablePath" }
        if ($App.VersionedMachineDirectory) {
            $directory = Join-Path $root $App.VersionedMachineDirectory
            if (Test-Path -LiteralPath $directory -PathType Container) {
                foreach ($version in (Get-ChildItem -LiteralPath $directory -Directory |
                    Where-Object { $_.Name -match '^\d+(\.\d+)*$' })) {
                    $executablePath = Join-Path $version.FullName $App.Executable
                    if (Test-Path -LiteralPath $executablePath -PathType Leaf) { return "executable: $executablePath" }
                }
            }
        }
    }
    if ($env:LOCALAPPDATA) {
        $executablePath = Join-Path $env:LOCALAPPDATA $App.UserPath
        if (Test-Path -LiteralPath $executablePath -PathType Leaf) { return "executable: $executablePath" }
    }
    $command = Get-Command $App.Executable -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command) { return "executable on PATH: $($command.Source)" }
    return $null
}

function Invoke-AppWinget {
    param([string[]]$Arguments, [switch]$ShowOutput)
    if (-not (Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue)) {
        throw 'WinGet is unavailable. Install or update App Installer, then reopen CMD and retry.'
    }
    # Windows PowerShell 5.1 can turn native stderr into terminating errors.
    # Collect it, then interpret the actual exit code explicitly.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& winget.exe @Arguments 2>&1 | ForEach-Object {
            if ($ShowOutput) { Write-Host $_ }
            $_
        })
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    [pscustomobject]@{ ExitCode = $exitCode; Output = ($output | Out-String).TrimEnd() }
}

function Install-EssentialApp {
    param($App)
    $installArguments = if ($App.Id -eq 'Microsoft.VisualStudioCode') {
        if (Get-Process -Name Code, Code-Insiders, 'VSCodeSetup*', 'VSCodeUserSetup*', 'CodeSetup-stable*' -ErrorAction SilentlyContinue) {
            throw 'Save your work and close all VS Code windows. Let any VS Code update finish, then rerun apps-essential_amd64.cmd to apply the context-menu options.'
        }
        # Reapply installer tasks even for an existing VS Code installation.
        @('install', '--force', $App.Id, '--exact', '--source', 'winget', '--architecture', 'x64',
            '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity', '--override',
            '/verysilent /suppressmsgboxes /norestart /log /mergetasks=!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath')
    } else {
        $evidence = Get-LocalAppEvidence $App
        if ($evidence) {
            Write-Host "[dev-choking] $($App.Id) is already installed ($evidence); skipping."
            return
        }
        $lookup = Invoke-AppWinget @('list', '--id', $App.Id, '--exact', '--source', 'winget',
            '--accept-source-agreements', '--disable-interactivity')
        if ($lookup.ExitCode -eq 0) {
            Write-Host "[dev-choking] $($App.Id) is already installed (WinGet); skipping."
            return
        }
        # APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND = 0x8A150014.
        # Any other error means detection failed, rather than proving the app absent.
        if ($lookup.ExitCode -ne -1978335212) {
            throw "Could not check $($App.Id) (WinGet exit $($lookup.ExitCode)). Resolve this error before rerunning: $($lookup.Output)"
        }
        @('install', '--id', $App.Id, '--exact', '--source', 'winget',
            '--architecture', 'x64', '--scope', 'machine', '--silent', '--accept-package-agreements',
            '--accept-source-agreements', '--disable-interactivity')
    }
    Write-Host "[dev-choking] Installing $($App.Id)..."
    $installation = Invoke-AppWinget -ShowOutput -Arguments $installArguments
    if ($installation.ExitCode -ne 0) {
        if ($App.Id -eq 'Microsoft.VisualStudioCode') {
            throw "VS Code installation failed with exit code $($installation.ExitCode). Close VS Code and let any update finish before retrying. Check the latest 'Setup Log*.txt' in %TEMP% for the installer error."
        }
        throw "Installation of $($App.Id) failed with exit code $($installation.ExitCode). Resolve the error above, then rerun."
    }
    if ($App.Id -eq 'Microsoft.VisualStudioCode') { Set-VSCodeContextMenu }
}

function Install-EssentialApps {
    Set-GitIdentity
    foreach ($app in (Get-EssentialApps)) { Install-EssentialApp $app }
    Write-Host '[dev-choking] VS Code, Chrome, and Google Drive for desktop are installed.'
    Write-Host '[dev-choking] Open Google Drive and sign in to configure synchronization.'
    Write-Host '[dev-choking] Windows 11: In Default apps, select Google Chrome, then click Set default.'
    Write-Host '[dev-choking] Windows 10: In Default apps, click Web browser, then choose Google Chrome.'
    Start-Process 'ms-settings:defaultapps'
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Install-EssentialApps } catch {
        Write-Error $_ -ErrorAction Continue
        exit 1
    }
}
