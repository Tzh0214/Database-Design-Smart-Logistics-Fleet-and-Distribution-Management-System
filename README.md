# 智慧物流车队与配送管理系统

数据库课程设计项目：SQL Server 数据库 + Flask Web 管理界面

## 快速开始（仅需 2 步）

### 步骤 1：初始化数据库
1. 打开 SQL Server Management Studio (SSMS)
2. 连接本地实例（服务器名：`localhost`）
3. 打开并执行 `DATABASE_project/sql/init_all.sql`

### 步骤 2：启动 Web 应用
进入 `DATABASE_project/web/flask_app` 目录，双击运行 `run.bat`

> 首次运行会自动安装依赖，需要等待 1-2 分钟

### 访问应用
浏览器打开：http://localhost:5000

## 环境要求
- Windows 10/11
- SQL Server（建议安装 SSMS 19）
- Python 3.8+
- ODBC Driver 17 for SQL Server

## 详细说明
完整功能介绍请查看：[DATABASE_project/运行说明.md](DATABASE_project/运行说明.md)

## 常见问题
- **端口被占用**：修改 `DATABASE_project/web/flask_app/.env` 中的 `PORT=5001`
- **数据库连接失败**：确保 SQL Server 服务已启动
- **缺少 ODBC 驱动**：到微软官网下载 ODBC Driver 17
