@echo off
echo Starting MiniCloud GCP Fix Tool...
echo.

REM Check if Git Bash is available
where bash >nul 2>nul
if %errorlevel% neq 0 (
    echo Git Bash not found. Please install Git for Windows first.
    echo Download from: https://git-scm.com/download/win
    pause
    exit /b 1
)

REM Run the fix script with Git Bash
bash run-fix.sh

pause