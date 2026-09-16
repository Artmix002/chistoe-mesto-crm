@echo off
setlocal
set "INSTALL_DIR=%~dp0"
set "TEMP_SCRIPT=%TEMP%\CleanPlaceCRM-Updater-%RANDOM%%RANDOM%.ps1"

copy /Y "%~dp0tools\Update-CleanPlaceCRM.ps1" "%TEMP_SCRIPT%" >nul
if errorlevel 1 (
  echo Не удалось запустить обновление: отсутствует Update-CleanPlaceCRM.ps1.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP_SCRIPT%" -InstallDir "%INSTALL_DIR%" -Repository "Artmix002/chistoe-mesto-crm" -AssetName "CRM-windows.zip"
set "RESULT=%ERRORLEVEL%"
del "%TEMP_SCRIPT%" >nul 2>&1
exit /b %RESULT%
