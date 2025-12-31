import os
from flask import Flask, request, render_template, redirect, url_for, flash, session
import pyodbc
from dotenv import load_dotenv
from functools import wraps
from datetime import date, timedelta

app = Flask(__name__)
app.secret_key = os.getenv("APP_SECRET", "dev-secret")

# SQL Server connection
# Load environment variables from .env if present
load_dotenv()
SQL_SERVER = os.getenv("SQLSERVER_SERVER", "localhost")
SQL_DB = os.getenv("SQLSERVER_DB", "LogisticsDB")
SQL_USER = os.getenv("SQLSERVER_USER")
SQL_PASSWORD = os.getenv("SQLSERVER_PASSWORD")

# Build connection string (SQL auth or Windows auth)
if SQL_USER and SQL_PASSWORD:
    CONN_STR = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SQL_SERVER};DATABASE={SQL_DB};UID={SQL_USER};PWD={SQL_PASSWORD}"
else:
    # Windows Integrated Authentication
    CONN_STR = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SQL_SERVER};DATABASE={SQL_DB};Trusted_Connection=yes;"


def get_conn():
    return pyodbc.connect(CONN_STR)

# Login Decorator
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login', next=request.url))
        return f(*args, **kwargs)
    return decorated_function

def manager_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session or session.get('role') != 'Manager':
            flash("权限不足：仅主管可访问", "error")
            return redirect(url_for('index'))
        return f(*args, **kwargs)
    return decorated_function

@app.route("/")
@login_required
def index():
    return render_template("index.html")

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username")
        password = request.form.get("password")
        
        with get_conn() as conn:
            user = conn.execute("SELECT UserId, Username, Role, RelatedId FROM dbo.Users WHERE Username = ? AND Password = ?", (username, password)).fetchone()
            
            if user:
                session['user_id'] = user.UserId
                session['username'] = user.Username
                session['role'] = user.Role
                session['related_id'] = user.RelatedId
                
                # Get FleetId
                if user.Role == 'Manager':
                    manager = conn.execute("SELECT FleetId FROM dbo.Managers WHERE ManagerId = ?", (user.RelatedId,)).fetchone()
                    session['fleet_id'] = manager.FleetId if manager else None
                elif user.Role == 'Driver':
                    driver = conn.execute("SELECT FleetId FROM dbo.Drivers WHERE DriverId = ?", (user.RelatedId,)).fetchone()
                    session['fleet_id'] = driver.FleetId if driver else None
                
                flash(f"欢迎回来, {user.Username} ({user.Role})", "success")
                return redirect(url_for('index'))
            else:
                flash("用户名或密码错误", "error")
    return render_template("login.html")

@app.route("/logout")
def logout():
    session.clear()
    flash("已退出登录", "success")
    return redirect(url_for('login'))

@app.route("/drivers", methods=["GET", "POST"])
@login_required
@manager_required
def drivers():
    fleet_id = session.get('fleet_id')
    
    if request.method == "POST":
        employee_no = request.form.get("employee_no")
        name = request.form.get("name")
        license_level = request.form.get("license_level")
        phone = request.form.get("phone")
        # Manager can only add to their fleet
        
        if not all([employee_no, name, license_level]):
            flash("必填项不能为空", "error")
        elif license_level not in ["C1", "C2", "B1", "B2", "A1", "A2"]:
            flash("驾照等级不合法（允许：C1/C2/B1/B2/A1/A2）", "error")
        else:
            try:
                with get_conn() as conn:
                    conn.execute(
                        "INSERT INTO dbo.Drivers(EmployeeNo, Name, LicenseLevel, Phone, FleetId) VALUES (?, ?, ?, ?, ?)",
                        (employee_no, name, license_level, phone, fleet_id)
                    )
                    conn.commit()
                    flash("司机已创建", "success")
            except pyodbc.Error as e:
                flash(f"数据库错误：{e}", "error")
        return redirect(url_for("drivers"))

    # GET: fetch drivers for manager's fleet
    with get_conn() as conn:
        drivers = conn.execute("SELECT DriverId, EmployeeNo, Name, LicenseLevel, Phone, FleetId FROM dbo.Drivers WHERE FleetId = ? ORDER BY DriverId DESC", (fleet_id,)).fetchall()
        # Manager only sees their fleet, so no need to select fleet
        fleets = conn.execute("SELECT FleetId, Name FROM dbo.Fleets WHERE FleetId = ?", (fleet_id,)).fetchall()
    return render_template("drivers.html", drivers=drivers, fleets=fleets)


@app.route("/vehicles", methods=["GET", "POST"])
@login_required
@manager_required
def vehicles():
    fleet_id = session.get('fleet_id')
    
    if request.method == "POST":
        plate_no = request.form.get("plate_no")
        max_weight = request.form.get("max_weight")
        max_volume = request.form.get("max_volume")
        status = request.form.get("status")
        
        import re
        plate_regex = r"^[A-Z]{1}[A-Z0-9]{5}$"
        if not all([plate_no, max_weight, max_volume, status]):
            flash("必填项不能为空", "error")
        elif not re.match(plate_regex, plate_no.upper()):
            flash("车牌格式不合法（示例：A12345）", "error")
        elif status not in ["空闲", "运输中", "维修中", "异常"]:
            flash("车辆状态不合法", "error")
        else:
            try:
                with get_conn() as conn:
                    conn.execute(
                        "INSERT INTO dbo.Vehicles(FleetId, PlateNo, MaxWeight, MaxVolume, Status) VALUES (?, ?, ?, ?, ?)",
                        (fleet_id, plate_no, float(max_weight), float(max_volume), status)
                    )
                    conn.commit()
                    flash("车辆已创建", "success")
            except pyodbc.Error as e:
                flash(f"数据库错误：{e}", "error")
        return redirect(url_for("vehicles"))

    with get_conn() as conn:
        vehicles = conn.execute("SELECT VehicleId, PlateNo, MaxWeight, MaxVolume, Status, FleetId FROM dbo.Vehicles WHERE FleetId = ? ORDER BY VehicleId DESC", (fleet_id,)).fetchall()
        fleets = conn.execute("SELECT FleetId, Name FROM dbo.Fleets WHERE FleetId = ?", (fleet_id,)).fetchall()
    return render_template("vehicles.html", vehicles=vehicles, fleets=fleets)


@app.route("/orders/assign", methods=["GET", "POST"])
@login_required
@manager_required
def assign_order():
    fleet_id = session.get('fleet_id')
    
    if request.method == "POST":
        vehicle_id = request.form.get("vehicle_id")
        driver_id = request.form.get("driver_id")
        weight = request.form.get("weight")
        volume = request.form.get("volume")
        destination = request.form.get("destination")
        try:
            with get_conn() as conn:
                conn.execute(
                    "INSERT INTO dbo.Orders(VehicleId, DriverId, Weight, Volume, Destination, Status) VALUES (?, ?, ?, ?, ?, N'新建')",
                    (int(vehicle_id), int(driver_id) if driver_id else None, float(weight), float(volume), destination)
                )
                conn.commit()
                flash("运单已分配", "success")
        except pyodbc.Error as e:
            msg = str(e)
            if "51000" in msg or "超出最大载重" in msg:
                flash("超出最大载重：分配失败", "error")
            else:
                flash(f"数据库错误：{e}", "error")
        return redirect(url_for("assign_order"))

    with get_conn() as conn:
        # Only show idle vehicles in manager's fleet
        vehicles = conn.execute(
            "SELECT VehicleId, PlateNo, Status, RemainingWeight FROM dbo.vw_fleet_vehicle_load WHERE Status = N'空闲' AND RemainingWeight > 0 AND FleetId = ? ORDER BY PlateNo",
            (fleet_id,)
        ).fetchall()
        # Only show drivers in manager's fleet
        drivers = conn.execute("SELECT DriverId, Name FROM dbo.Drivers WHERE FleetId = ? ORDER BY Name", (fleet_id,)).fetchall()
    return render_template("assign_order.html", vehicles=vehicles, drivers=drivers)


@app.route("/exceptions", methods=["GET", "POST"])
@login_required
@manager_required
def exceptions():
    fleet_id = session.get('fleet_id')
    
    if request.method == "POST":
        vehicle_id = request.form.get("vehicle_id")
        driver_id = request.form.get("driver_id")
        exception_type = request.form.get("exception_type")
        phase = request.form.get("phase")
        fine = request.form.get("fine") or 0
        try:
            with get_conn() as conn:
                conn.execute(
                    "INSERT INTO dbo.Exceptions(VehicleId, DriverId, ExceptionType, Phase, FineAmount) VALUES (?, ?, ?, ?, ?)",
                    (int(vehicle_id), int(driver_id) if driver_id else None, exception_type, phase, float(fine))
                )
                conn.commit()
                flash("异常已记录，车辆状态置为异常", "success")
        except pyodbc.Error as e:
            flash(f"数据库错误：{e}", "error")
        return redirect(url_for("exceptions"))

    with get_conn() as conn:
        vehicles = conn.execute("SELECT VehicleId, PlateNo FROM dbo.Vehicles WHERE FleetId = ? ORDER BY PlateNo", (fleet_id,)).fetchall()
        drivers = conn.execute("SELECT DriverId, Name FROM dbo.Drivers WHERE FleetId = ? ORDER BY Name", (fleet_id,)).fetchall()
    return render_template("exceptions.html", vehicles=vehicles, drivers=drivers)


@app.route("/reports/fleet_monthly")
@login_required
@manager_required
def fleet_monthly():
    fleet_id = session.get('fleet_id')
    year = request.args.get("year")
    month = request.args.get("month")
    result = None
    if year and month:
        with get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute("EXEC dbo.sp_fleet_monthly_report @FleetId=?, @Year=?, @Month=?", (fleet_id, int(year), int(month)))
            result = cursor.fetchone()
    
    # Manager only sees their fleet
    with get_conn() as conn:
        fleets = conn.execute("SELECT FleetId, Name FROM dbo.Fleets WHERE FleetId = ?", (fleet_id,)).fetchall()
        
    return render_template("report.html", fleets=fleets, result=result)


@app.route("/views/week_exceptions")
@login_required
@manager_required
def week_exceptions():
    fleet_id = session.get('fleet_id')
    with get_conn() as conn:
        # Filter view by fleet? The view might not have FleetId.
        # Let's check if view has FleetId. If not, we might need to join.
        # Assuming view has VehicleId, we can join Vehicles.
        rows = conn.execute("""
            SELECT TOP 100 w.* 
            FROM dbo.vw_week_exception_alerts w
            JOIN dbo.Vehicles v ON w.VehicleId = v.VehicleId
            WHERE v.FleetId = ?
            ORDER BY w.OccurTime DESC
        """, (fleet_id,)).fetchall()
    return render_template("week_exceptions.html", rows=rows)


@app.route("/exceptions/process", methods=["GET", "POST"])
@login_required
@manager_required
def process_exceptions():
    fleet_id = session.get('fleet_id')
    
    if request.method == "POST":
        exception_id = request.form.get("exception_id")
        try:
            with get_conn() as conn:
                conn.execute(
                    "UPDATE dbo.Exceptions SET Processed = 1, ProcessedTime = SYSDATETIME() WHERE ExceptionId = ?",
                    (int(exception_id),)
                )
                conn.commit()
                flash("异常已处理，车辆状态将自动恢复", "success")
        except pyodbc.Error as e:
            flash(f"数据库错误：{e}", "error")
        return redirect(url_for("process_exceptions"))

    # GET: fetch unprocessed exceptions for manager's fleet
    with get_conn() as conn:
        exceptions = conn.execute(
            """SELECT e.ExceptionId, e.OccurTime, e.ExceptionType, e.Phase, e.FineAmount,
                      v.PlateNo, v.Status AS VehicleStatus,
                      d.Name AS DriverName
               FROM dbo.Exceptions e
               JOIN dbo.Vehicles v ON v.VehicleId = e.VehicleId
               LEFT JOIN dbo.Drivers d ON d.DriverId = e.DriverId
               WHERE e.Processed = 0 AND v.FleetId = ?
               ORDER BY e.OccurTime DESC""",
            (fleet_id,)
        ).fetchall()
    return render_template("process_exceptions.html", exceptions=exceptions)

@app.route("/reports/driver_performance")
@login_required
def driver_performance():
    role = session.get('role')
    related_id = session.get('related_id')
    fleet_id = session.get('fleet_id')
    
    target_driver_id = request.args.get("driver_id")
    start_date = request.args.get("start_date") or (date.today() - timedelta(days=30)).isoformat()
    end_date = request.args.get("end_date") or date.today().isoformat()
    
    drivers_list = []
    stats = None
    exceptions = []
    
    with get_conn() as conn:
        if role == 'Manager':
            # Manager can select any driver in their fleet
            drivers_list = conn.execute("SELECT DriverId, Name, EmployeeNo FROM dbo.Drivers WHERE FleetId = ? ORDER BY Name", (fleet_id,)).fetchall()
            if not target_driver_id and drivers_list:
                target_driver_id = drivers_list[0].DriverId
        else:
            # Driver can only see themselves
            target_driver_id = related_id
            
        if target_driver_id:
            # Verify permission if manager tries to access driver from another fleet
            if role == 'Manager':
                check = conn.execute("SELECT 1 FROM dbo.Drivers WHERE DriverId = ? AND FleetId = ?", (target_driver_id, fleet_id)).fetchone()
                if not check:
                    flash("无权查看该司机信息", "error")
                    return redirect(url_for('index'))
            
            # Execute Stored Procedure
            cursor = conn.cursor()
            cursor.execute("EXEC dbo.sp_driver_performance_report @DriverId=?, @StartDate=?, @EndDate=?", (target_driver_id, start_date, end_date))
            stats = cursor.fetchone()
            
            if cursor.nextset():
                exceptions = cursor.fetchall()
                
    return render_template("driver_performance.html", 
                           drivers=drivers_list, 
                           selected_driver_id=int(target_driver_id) if target_driver_id else None,
                           start_date=start_date,
                           end_date=end_date,
                           stats=stats,
                           exceptions=exceptions)

if __name__ == "__main__":
    # Allow changing port via environment variable to avoid conflicts
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=True)
