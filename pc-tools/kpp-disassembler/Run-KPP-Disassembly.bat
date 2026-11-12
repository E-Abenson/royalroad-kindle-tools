@echo off
setlocal
title Kindle KPP one-time disassembly
cd /d "%~dp0"

echo ============================================================
echo KINDLE KPP — ONE-TIME LOCAL DISASSEMBLY
echo ============================================================
echo.
echo This tool needs Python 3.8+ and an internet connection for
echo its first run. It does not install Python or any packages.
echo It downloads the pure-Python hbctool source into this folder.
echo The Kindle bundle and findings stay on this computer.
echo Nothing is uploaded.
echo.

where py.exe >nul 2>nul
if not errorlevel 1 (
  py -3 "%~dp0kpp_disassemble.py" %*
  goto finished
)

where python.exe >nul 2>nul
if not errorlevel 1 (
  python "%~dp0kpp_disassemble.py" %*
  goto finished
)

echo Python was not found on PATH.
echo Install or repair the Python 3 launcher, then run this file again.
echo You do not need to install hbctool or any pip packages.
echo.
pause
exit /b 2

:finished
echo.
pause
