@echo off
rem Repack the flat src\ mission source into DUWS_T.altis.pbo at the repo root.
rem Wraps the vendored PBO Manager console CLI (Windows only). See README.md.
setlocal EnableExtensions
cd /d "%~dp0"

rem Run the work in :main so one pause fires on every exit path (double-click
rem leaves the window open until a key is pressed, whatever the outcome).
call :main
set "RC=%ERRORLEVEL%"
echo(
pause
exit /b %RC%

:main
set "PBOC=tools\PBO Manager\pboc.exe"
set "MISSION=DUWS_T.altis"
set "OUT=DUWS_T.altis.pbo"
set "STAGE=%TEMP%\duws_t_pack"

if not exist "%PBOC%" (
  echo [repack] ERROR: "%PBOC%" not found.
  echo         Get PBO Manager from https://github.com/winseros/pboman3 and
  echo         unzip it into "tools\PBO Manager\". See README.md.
  exit /b 1
)
if not exist "src\mission.sqm" (
  echo [repack] ERROR: src\ has no mission.sqm. Run unpack.cmd first.
  exit /b 1
)

rem Confirm before overwriting the packed mission; default is No.
if exist "%OUT%" (
  echo [repack] This will OVERWRITE %OUT% at the repo root.
) else (
  echo [repack] This will build %OUT% at the repo root.
)
set "CONFIRM="
set /p "CONFIRM=[repack] Are you sure? [y/N] "
if /I not "%CONFIRM%"=="y" (
  echo [repack] Cancelled.
  exit /b 0
)

rem pboc names the .pbo after the packed folder, so stage src\ as %MISSION%\.
echo [repack] Staging src\ as %MISSION% ...
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%\%MISSION%"
robocopy "src" "%STAGE%\%MISSION%" /MIR /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
  echo [repack] ERROR: staging copy failed.
  rmdir /s /q "%STAGE%"
  exit /b 1
)

echo [repack] Packing to %OUT% ...
if exist "%OUT%" del /q "%OUT%"
"%PBOC%" pack "%STAGE%\%MISSION%" -o .
if errorlevel 1 (
  echo [repack] ERROR: pboc.exe failed.
  rmdir /s /q "%STAGE%"
  exit /b 1
)

rmdir /s /q "%STAGE%"
if not exist "%OUT%" (
  echo [repack] ERROR: %OUT% was not produced.
  exit /b 1
)
echo [repack] Done. Wrote %OUT%
exit /b 0
