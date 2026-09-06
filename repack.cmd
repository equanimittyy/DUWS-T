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

rem Choose the source to pack: the live working tree, or src\ as of one of the last five
rem commits (or any commit hash typed in). scripts\pick_commit.ps1 draws the menu on the
rem console and returns one token on stdout -- WORKING, a short hash, or INVALID.
set "PICK="
for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\pick_commit.ps1"') do set "PICK=%%i"
if not defined PICK (
  echo [repack] ERROR: no selection returned by the commit picker.
  exit /b 1
)
if /I "%PICK%"=="INVALID" (
  echo [repack] That did not match a commit. Cancelled.
  exit /b 0
)

rem The build stamp names both the staged log line and the output .pbo, so the file in
rem MPMissions\ self-identifies its source (a stale build reads exactly like a fix that
rem failed). Working tree: short HEAD, plus -dirty if src\ has uncommitted edits (-d in the
rem .pbo name). A chosen commit: that commit's short hash, and never dirty -- the archive
rem staged below is the pristine tree at that commit, not the working copy.
set "SRCMODE=working"
set "COMMIT="
if /I not "%PICK%"=="WORKING" (
  set "SRCMODE=commit"
  set "COMMIT=%PICK%"
)

set "STAMP=nogit"
set "DIRTY="
set "DIRTYNAME="
if "%SRCMODE%"=="commit" (
  set "STAMP=%PICK%"
) else (
  for /f "delims=" %%i in ('git rev-parse --short HEAD 2^>nul') do set "STAMP=%%i"
  rem Set inside the loop so any number of dirty paths yields one suffix.
  for /f "delims=" %%i in ('git status --porcelain -- src 2^>nul') do (
    set "DIRTY=-dirty"
    set "DIRTYNAME=-d"
  )
)

rem Locale-independent, unlike %DATE%/%TIME%; powershell is already required. The sortable
rem 's' format is one bare token, so it needs no quotes nested inside the for.
set "BUILT=unknown"
for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-Date -Format s"') do set "BUILT=%%i"

rem Hash the source commit into the .pbo name so each build is a distinct file on disk.
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

rem pboc names the .pbo after the packed folder, so stage the source as %MISSION%\.
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%\%MISSION%"
if "%SRCMODE%"=="commit" (call :stage_commit) else (call :stage_working)
if errorlevel 1 (
  if exist "%STAGE%" rmdir /s /q "%STAGE%"
  exit /b 1
)
if not exist "%STAGE%\%MISSION%\mission.sqm" (
  echo [repack] ERROR: staged tree has no mission.sqm.
  rmdir /s /q "%STAGE%"
  exit /b 1
)

rem Write the same stamp into the staged copy, not src\, so a repack never dirties the
rem working tree and no generated hash is ever committed.
echo [repack] Build stamp: %STAMP%%DIRTY% %BUILT%
(
  echo // Generated into the staging tree by repack.cmd; see src\duws\shared\includes\build_stamp.hpp.
  echo #define DUWS_BUILD_STAMP "%STAMP%%DIRTY% %BUILT%"
) > "%STAGE%\%MISSION%\duws\shared\includes\build_stamp.hpp"
if not exist "%STAGE%\%MISSION%\duws\shared\includes\build_stamp.hpp" (
  echo [repack] ERROR: could not write the build stamp.
  rmdir /s /q "%STAGE%"
  exit /b 1
)

echo [repack] Packing to %OUT% ...
rem Remove any prior build left in the repo root so only this build's .pbo remains;
rem each source produces a distinctly-named .pbo and stale ones would otherwise pile up.
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

:stage_working
echo [repack] Staging working tree src\ as %MISSION% ...
robocopy "src" "%STAGE%\%MISSION%" /MIR /NFL /NDL /NJH /NJS /NP >nul
rem robocopy returns 0-7 on success; 8 and up is a real failure.
if errorlevel 8 (
  echo [repack] ERROR: staging copy failed.
  exit /b 1
)
exit /b 0

:stage_commit
echo [repack] Staging src\ at commit %COMMIT% as %MISSION% ...
rem git archive of the src\ subtree at the chosen commit, extracted into the stage. The
rem <commit>:src tree-ish emits the subtree at the archive root, so it lands as %MISSION%\
rem the same way robocopy does. A zip via Expand-Archive avoids a tar dependency.
git archive --format=zip -o "%STAGE%\src.zip" "%COMMIT%:src" 2>nul
if errorlevel 1 (
  echo [repack] ERROR: git archive failed for %COMMIT%:src ^(does src\ exist at that commit?^).
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%STAGE%\src.zip' -DestinationPath '%STAGE%\%MISSION%' -Force"
if errorlevel 1 (
  echo [repack] ERROR: could not extract the commit archive.
  exit /b 1
)
del /q "%STAGE%\src.zip" 2>nul
exit /b 0
