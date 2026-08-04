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

rem Stamp the staged copy so the mission's own log names the source it was packed from.
rem Written here rather than into src\ so a repack never dirties the working tree and no
rem generated hash is ever committed. A tree with no git falls back to "nogit"; the mission
rem still builds, it just cannot name itself.
set "STAMP=nogit"
for /f "delims=" %%i in ('git rev-parse --short HEAD 2^>nul') do set "STAMP=%%i"
rem Scoped to src\ because only src\ is packed: a docs-only edit is not a different build.
rem Set inside the loop so any number of dirty paths still yields one suffix.
set "DIRTY="
for /f "delims=" %%i in ('git status --porcelain -- src 2^>nul') do set "DIRTY=-dirty"
rem Locale-independent, unlike %DATE%/%TIME%; powershell is already required below. The
rem sortable 's' format is one bare token, so it needs no quotes nested inside the for.
set "BUILT=unknown"
for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-Date -Format s"') do set "BUILT=%%i"

echo [repack] Build stamp: %STAMP%%DIRTY% %BUILT%
(
  echo // Generated into the staging tree by repack.cmd; see src\duws\shared\includes\build_stamp.hpp.
  echo #define DUWS_BUILD_STAMP "%STAMP%%DIRTY% %BUILT%"
) > "%STAGE%\%MISSION%\duws\shared\includes\build_stamp.hpp"
if errorlevel 1 (
  echo [repack] ERROR: could not write the build stamp.
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

rem pboc stores forward-slash PBO paths; Arma's convention and the mission's own
rem backslash load paths require '\'. Normalize them (and recompute the SHA1).
echo [repack] Normalizing PBO paths to backslashes ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\normalize_pbo.ps1" "%OUT%"
if errorlevel 1 (
  echo [repack] ERROR: path normalization failed ^(%~dp0scripts\normalize_pbo.ps1^).
  exit /b 1
)

echo [repack] Done. Wrote %OUT%
exit /b 0
