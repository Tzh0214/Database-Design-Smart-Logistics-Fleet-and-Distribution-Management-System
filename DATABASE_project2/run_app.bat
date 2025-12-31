@echo off
echo ==========================================
echo 正在启动智慧物流管理系统...
echo ==========================================

cd web\flask_app

echo [1/3] 检查 Python 环境...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo 错误: 未检测到 Python，请先安装 Python。
    pause
    exit /b
)

echo [2/3] 安装依赖库...
pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo 警告: 依赖安装失败，尝试继续运行...
)

echo [3/3] 启动 Flask 应用...
echo 请在浏览器访问: http://localhost:5000
echo 按 Ctrl+C 停止运行
echo.

python app.py

pause
