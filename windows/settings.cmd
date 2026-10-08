@echo off
setlocal
rem Use Windows PowerShell: the Windows language-management modules require it.
set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PSEXE=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0settings.ps1" %*
exit /b %errorlevel%
