@echo off
REM FCM363X Zephyr Environment Setup (Windows Launcher)
REM This script launches setup_env.sh via Git Bash
REM
REM Usage:
REM   setup_env.bat           - Activate environment
REM   setup_env.bat --install - Install tools first

setlocal

REM Find Git Bash
where bash >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] bash not found in PATH.
    echo.
    echo Please install Git for Windows from:
    echo   https://git-scm.com/download/win
    echo.
    echo After installation, restart your terminal and try again.
    pause
    exit /b 1
)

REM Get script directory
set "SCRIPT_DIR=%~dp0"

REM Launch setup_env.sh via Git Bash
echo Launching FCM363X Zephyr setup via Git Bash...
echo.

REM Check if we should source or run directly
REM In Windows, we run it and then need to manually activate venv
bash "%SCRIPT_DIR%setup_env.sh" %*

echo.
echo ========================================
echo   Important for Windows Users
echo ========================================
echo.
echo The setup script has run. To activate the Python
echo virtual environment, run:
echo.
echo   %SCRIPT_DIR%.venv\Scripts\activate.bat
echo.
echo Or in PowerShell:
echo.
echo   %SCRIPT_DIR%.venv\Scripts\Activate.ps1
echo.

endlocal
