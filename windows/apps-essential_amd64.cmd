@echo off
setlocal
rem Run from an administrator Command Prompt on Windows 10/11 (amd64/x64).
set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PSEXE=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0apps-essential_amd64.ps1"
exit /b %errorlevel%
