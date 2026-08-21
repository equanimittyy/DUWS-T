@echo off
rem Repack the flat src\ mission source into DUWS_T_<hash>.altis.pbo at the repo root.
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

rem Build stamp names both the staged log line and the output .pbo, so the file
rem in MPMissions\ self-identifies its source commit (a stale build reads exactly
rem like a fix that failed). No git tree falls back to "nogit"; the mission still
rem builds, it just cannot name itself.
set "STAMP=nogit"
for /f "delims=" %%i in ('git rev-parse --short HEAD 2^>nul') do set "STAMP=%%i"
rem Scoped to src\ because only src\ is packed: a docs-only edit is not a different
rem build. -dirty flags uncommitted src\ edits in the log; -d is its short form in
rem the .pbo name. Set inside the loop so any number of dirty paths yields one suffix.
set "DIRTY="
set "DIRTYNAME="
for /f "delims=" %%i in ('git status --porcelain -- src 2^>nul') do (
  set "DIRTY=-dirty"
  set "DIRTYNAME=-d"
)
rem Locale-independent, unlike %DATE%/%TIME%; powershell is already required below. The
rem sortable 's' format is one bare token, so it needs no quotes nested inside the for.
set "BUILT=unknown"
for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-Date -Format s"') do set "BUILT=%%i"

rem Hash the commit into the .pbo name so each build is a distinct file on disk.
set "MISSION=DUWS_T_%STAMP%%DIRTYNAME%.altis"
set "OUT=%MISSION%.pbo"

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

rem Write the same stamp into the staged copy, not src\, so a repack never dirties
rem the working tree and no generated hash is ever committed. STAMP/DIRTY/BUILT are
rem the values computed above for the .pbo name.
echo [repack] Build stamp: %STAMP%%DIRTY% %BUILT%
(
  echo // Generated into the staging tree by repack.cmd; see src\duws\shared\includes\build_stamp.hpp.
  echo #define DUWS_BUILD_STAMP "%STAMP%%DIRTY% %BUILT%"
) > "%STAGE%\%MISSION%\duws\shared\includes\build_stamp.hpp"
rem robocopy exits 1 on success (files copied) and nothing between it and this write
rem clears ERRORLEVEL, so verify the file exists rather than trust a stale ERRORLEVEL.
if not exist "%STAGE%\%MISSION%\duws\shared\includes\build_stamp.hpp" (
  echo [repack] ERROR: could not write the build stamp.
  rmdir /s /q "%STAGE%"
  exit /b 1
)

echo [repack] Packing to %OUT% ...
rem Remove any prior build left in the repo root so only this build's .pbo remains;
rem each commit produces a distinctly-named .pbo and stale ones would otherwise pile up.
del /q "DUWS_T*.altis.pbo" 2>nul
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
