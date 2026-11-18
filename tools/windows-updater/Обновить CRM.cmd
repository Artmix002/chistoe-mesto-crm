@echo off
setlocal
set "INSTALL_DIR=%~dp0"
set "TEMP_SCRIPT=%TEMP%\CleanPlaceCRM-Updater-%RANDOM%%RANDOM%.ps1"
set "SCRIPT_URL=https://raw.githubusercontent.com/Artmix002/chistoe-mesto-crm/main/tools/windows-updater/tools/Update-CleanPlaceCRM.ps1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri '%SCRIPT_URL%' -OutFile '%TEMP_SCRIPT%'"

if not exist "%TEMP_SCRIPT%" (
  echo Could not download the update module. Check your internet connection.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP_SCRIPT%" -InstallDir "%INSTALL_DIR%" -Repository "Artmix002/chistoe-mesto-crm" -AssetPrefix "CRM-windows"
set "RESULT=%ERRORLEVEL%"
del "%TEMP_SCRIPT%" >nul 2>&1
exit /b %RESULT%
