@echo off
setlocal
cd /d "%~dp0"
if "%~1"=="" (
  echo Drag KPP-Native-Bridge-Binaries.tar.gz onto this file.
  pause
  exit /b 1
)
where py >nul 2>nul
if not errorlevel 1 (
  py -3 -u "%~dp0kpp_native_inspect.py" "%~1"
) else (
  where python >nul 2>nul
  if errorlevel 1 (
    echo FAILURE: Python 3 was not found. Use a PC with Python 3 already installed.
    pause
    exit /b 1
  )
  python -u "%~dp0kpp_native_inspect.py" "%~1"
)
pause
