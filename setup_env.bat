@echo off
REM FCM363X Zephyr Environment Setup (Windows Launcher)
REM This script launches setup_env.sh via Git Bash
REM
REM Usage:
REM   setup_env.bat                 - Activate environment
REM   setup_env.bat --init-sdk      - Initialize NXP Zephyr SDK
REM   setup_env.bat --install       - Install JLink patch, blhost
REM   setup_env.bat --list-versions - List available SDK versions
REM   setup_env.bat --check         - Check dependencies only
REM
REM SDK Version Override:
REM   set SDK_VERSION=nxp-v4.3.0 && setup_env.bat --init-sdk
REM   set SDK_VERSION=latest && setup_env.bat --init-sdk

setlocal EnableDelayedExpansion

REM Get script directory
set "SCRIPT_DIR=%~dp0"

REM Find Git Bash
where bash >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] bash not found in PATH.
    echo.
    echo Please install Git for Windows from:
    echo   https://git-scm.com/download/win
    echo.
    echo After installation, restart your terminal and try again.
    echo.
    pause
    exit /b 1
)

REM Launch setup_env.sh via Git Bash
echo.
echo ========================================
echo   FCM363X Zephyr Setup (Windows)
echo ========================================
echo.
echo Launching via Git Bash...
echo.

bash "%SCRIPT_DIR%setup_env.sh" %*

REM Check result
if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo   Setup Complete
    echo ========================================
    echo.
    echo To activate environment in different shells:
    echo.
    echo   CMD:        call "%SCRIPT_DIR%.venv\Scripts\activate.bat"
    echo   PowerShell: . "%SCRIPT_DIR%.venv\Scripts\Activate.ps1"
    echo   Git Bash:   source "%SCRIPT_DIR%.venv/Scripts/activate"
    echo.
) else (
    echo.
    echo [ERROR] Setup failed. Check the error messages above.
    echo.
)

endlocal
