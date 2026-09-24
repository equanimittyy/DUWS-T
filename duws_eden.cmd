@echo off
rem Launcher for the DUWS composition TUI (double-clickable).
rem Runs duws_eden.ps1 with an execution-policy bypass so it works without
rem changing the machine's PowerShell policy. See docs/info/architecture/composition_tooling.md.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\duws_eden.ps1" %*
