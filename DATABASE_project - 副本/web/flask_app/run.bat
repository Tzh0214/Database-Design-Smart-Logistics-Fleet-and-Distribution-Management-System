@echo off
setlocal
cd /d "%~dp0"

echo [INFO] Checking Python environment...

REM Check if .venv exists
if not exist ".venv" (
    echo [INFO] Creating virtual environment...
    python -m venv .venv
    if errorlevel 1 (
        echo [ERROR] Failed to create virtual environment. Please ensure Python is installed and in your PATH.
        pause
        exit /b 1
    )
)

REM Activate environment
echo [INFO] Activating virtual environment...
call .venv\Scripts\activate.bat

REM Install dependencies
echo [INFO] Installing dependencies...
pip install -r requirements.txt
if errorlevel 1 (
    echo [ERROR] Failed to install dependencies.
    pause
    exit /b 1
)

REM Run the application
echo [INFO] Starting Flask application...
echo [INFO] Please open your browser to: http://127.0.0.1:5000
python app.py

pause
