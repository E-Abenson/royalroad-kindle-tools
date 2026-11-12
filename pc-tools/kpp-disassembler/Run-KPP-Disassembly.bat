@echo off
setlocal
title Kindle KPP one-time disassembly
cd /d "%~dp0"

echo ============================================================
echo KINDLE KPP — ONE-TIME LOCAL DISASSEMBLY
echo ============================================================
echo.
echo Uses Python 3.8+ already installed on this computer.
echo No pip packages, compiler, or admin rights are needed.
echo The disassembler source downloads from GitHub on first run.
echo Your Kindle bundle and the output stay on this computer.
echo Nothing from the Kindle is uploaded.
echo.

where py.exe >nul 2>nul
if not errorlevel 1 (
  py -3 "%~dp0kpp_disassemble.py" %*
  set RESULT=%ERRORLEVEL%
  goto finished
)

where python.exe >nul 2>nul
if not errorlevel 1 (
  python "%~dp0kpp_disassemble.py" %*
  set RESULT=%ERRORLEVEL%
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
if not "%RESULT%"=="0" echo The disassembler reported an error. See the message above.
pause
exit /b %RESULT%
