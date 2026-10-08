# Shared by settings.ps1 and apps-essential_amd64.ps1.
function Get-VSCodeExecutable {
    $candidates = @()
    foreach ($root in @('HKCU:\Software', 'HKLM:\Software', 'HKLM:\Software\WOW6432Node')) {
        $appPath = Join-Path $root 'Microsoft\Windows\CurrentVersion\App Paths\Code.exe'
        if (Test-Path -LiteralPath $appPath) {
            $registeredPath = (Get-Item -LiteralPath $appPath).GetValue('')
            if ($registeredPath) { $candidates += $registeredPath.Trim('"') }
        }
    }
    foreach ($root in @($env:LOCALAPPDATA, $env:ProgramW6432, $env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }) {
        $relativePath = if ($root -eq $env:LOCALAPPDATA) { 'Programs\Microsoft VS Code\Code.exe' } else { 'Microsoft VS Code\Code.exe' }
        $candidates += Join-Path $root $relativePath
    }
    $candidates += @(Get-Command Code.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    return $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}

function Set-VSCodeContextMenu {
    param([string]$Executable = (Get-VSCodeExecutable), [switch]$SkipIfMissing)
    if (-not $Executable -or -not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
        if ($SkipIfMissing) {
            Write-Host '[dev-choking] VS Code is not installed; skipped its context-menu entries.'
            return
        }
        throw 'VS Code executable was not found; install VS Code before adding its context-menu entries.'
    }
    # Windows 11's installer can register only the modern menu. Register the
    # classic menu too, including the folder background and drive menus.
    foreach ($entry in @(
        @{Class = 'Directory'; Argument = '%V'},
        @{Class = 'Directory\Background'; Argument = '%V'},
        @{Class = 'Drive'; Argument = '%V'},
        @{Class = '*'; Argument = '%1'}
    )) {
        $relativePath = 'Software\Classes\' + $entry.Class + '\shell\VSCode'
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($relativePath)
        try {
            $key.SetValue('', 'Open with Code', [Microsoft.Win32.RegistryValueKind]::String)
            $key.SetValue('Icon', ('"' + $Executable + '"'), [Microsoft.Win32.RegistryValueKind]::String)
        } finally { $key.Dispose() }
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($relativePath + '\command')
        try {
            $key.SetValue('', ('"' + $Executable + '" "' + $entry.Argument + '"'), [Microsoft.Win32.RegistryValueKind]::String)
        } finally { $key.Dispose() }
    }
    if (-not ('DevChoking.ShellAssociations' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace DevChoking {
    public static class ShellAssociations {
        [DllImport("shell32.dll")]
        public static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);
    }
}
'@
    }
    [DevChoking.ShellAssociations]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
    Write-Host '[dev-choking] Open with Code is registered for files, folders, folder backgrounds, and drives.'
}
