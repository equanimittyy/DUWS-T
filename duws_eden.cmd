@echo off
rem Launcher for the DUWS Eden composition import TUI (double-clickable).
rem Runs duws_eden.ps1 with an execution-policy bypass so it works without
rem changing the machine's PowerShell policy. See docs/hq_layout_editing.md.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\duws_eden.ps1" %*
