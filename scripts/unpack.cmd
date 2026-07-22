@echo off
rem Unpack DUWS_T.altis.pbo into a flat src\ folder for editing.
rem Wraps the vendored PBO Manager console CLI (Windows only). See README.md.
setlocal EnableExtensions
rem Operate from the repo root (parent of scripts\), where src\ and the .pbo live.
cd /d "%~dp0.."

rem Run the work in :main so one pause fires on every exit path (double-click
rem leaves the window open until a key is pressed, whatever the outcome).
call :main
set "RC=%ERRORLEVEL%"
echo(
pause
exit /b %RC%

:main
set "PBOC=tools\PBO Manager\pboc.exe"
set "PBO=DUWS_T.altis.pbo"
set "MISSION=DUWS_T.altis"
set "STAGE=%TEMP%\duws_t_unpack"

if not exist "%PBOC%" (
  echo [unpack] ERROR: "%PBOC%" not found.
  echo         Get PBO Manager from https://github.com/winseros/pboman3 and
  echo         unzip it into "tools\PBO Manager\". See README.md.
  exit /b 1
)
if not exist "%PBO%" (
  echo [unpack] ERROR: "%PBO%" not found in the repo root.
  exit /b 1
)

rem Confirm before touching src\ ; default is No (a bare Enter cancels).
if exist "src\mission.sqm" (
  echo [unpack] WARNING: src\ already holds an unpacked mission.
  echo          Continuing REPLACES src\ and DISCARDS any local edits.
) else (
  echo [unpack] This will unpack %PBO% into src\.
)
set "CONFIRM="
set /p "CONFIRM=[unpack] Are you sure? [y/N] "
if /I not "%CONFIRM%"=="y" (
  echo [unpack] Cancelled.
  exit /b 0
)

echo [unpack] Extracting %PBO% ...
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%"
"%PBOC%" unpack "%PBO%" -o "%STAGE%"
if errorlevel 1 (
  echo [unpack] ERROR: pboc.exe failed.
  rmdir /s /q "%STAGE%"
  exit /b 1
)

rem pboc normally extracts to %STAGE%\%MISSION%\ ; tolerate a flat extraction too.
set "FROM="
if exist "%STAGE%\%MISSION%\mission.sqm" set "FROM=%STAGE%\%MISSION%"
if not defined FROM if exist "%STAGE%\mission.sqm" set "FROM=%STAGE%"
if not defined FROM (
  echo [unpack] ERROR: could not find the extracted mission under "%STAGE%".
  dir /b "%STAGE%"
  rmdir /s /q "%STAGE%"
  exit /b 1
)

echo [unpack] Syncing into src\ ...
robocopy "%FROM%" "src" /MIR /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
  echo [unpack] ERROR: robocopy into src\ failed.
  rmdir /s /q "%STAGE%"
  exit /b 1
)

rmdir /s /q "%STAGE%"
echo [unpack] Done. Mission source is in src\
exit /b 0
