import os
from flask import Flask, request, render_template, redirect, url_for, flash
import pyodbc
from dotenv import load_dotenv

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


@app.route("/")
def index():
    return render_template("index.html")


# Drivers CRUD (create minimal)
@app.route("/drivers", methods=["GET", "POST"])
def drivers():
    if request.method == "POST":
        employee_no = request.form.get("employee_no")
        name = request.form.get("name")
        license_level = request.form.get("license_level")
        phone = request.form.get("phone")
        fleet_id = request.form.get("fleet_id")
        # Basic validation
        if not all([employee_no, name, license_level, fleet_id]):
            flash("必填项不能为空", "error")
        elif license_level not in ["C1", "C2", "B1", "B2", "A1", "A2"]:
            flash("驾照等级不合法（允许：C1/C2/B1/B2/A1/A2）", "error")
        else:
            try:
                with get_conn() as conn:
                    conn.execute(
                        "INSERT INTO dbo.Drivers(EmployeeNo, Name, LicenseLevel, Phone, FleetId) VALUES (?, ?, ?, ?, ?)",
                        (employee_no, name, license_level, phone, int(fleet_id))
                    )
                    conn.commit()
                    flash("司机已创建", "success")
            except pyodbc.Error as e:
                flash(f"数据库错误：{e}", "error")
        return redirect(url_for("drivers"))

    # GET: fetch drivers and fleets for dropdown
    with get_conn() as conn:
        drivers = conn.execute("SELECT DriverId, EmployeeNo, Name, LicenseLevel, Phone, FleetId FROM dbo.Drivers ORDER BY DriverId DESC").fetchall()
        fleets = conn.execute("SELECT FleetId, Name FROM dbo.Fleets ORDER BY Name").fetchall()
    return render_template("drivers.html", drivers=drivers, fleets=fleets)


# Vehicles CRUD (create minimal)
@app.route("/vehicles", methods=["GET", "POST"])
def vehicles():
    if request.method == "POST":
        plate_no = request.form.get("plate_no")
        max_weight = request.form.get("max_weight")
        max_volume = request.form.get("max_volume")
        status = request.form.get("status")
        fleet_id = request.form.get("fleet_id")
        # Basic validation: plate regex simple
        import re
        plate_regex = r"^[A-Z]{1}[A-Z0-9]{5}$"  # 简化示例：如粤A12345，实际可更严格
        if not all([plate_no, max_weight, max_volume, status, fleet_id]):
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
                        (int(fleet_id), plate_no, float(max_weight), float(max_volume), status)
                    )
                    conn.commit()
                    flash("车辆已创建", "success")
            except pyodbc.Error as e:
                flash(f"数据库错误：{e}", "error")
        return redirect(url_for("vehicles"))

    with get_conn() as conn:
        vehicles = conn.execute("SELECT VehicleId, PlateNo, MaxWeight, MaxVolume, Status, FleetId FROM dbo.Vehicles ORDER BY VehicleId DESC").fetchall()
        fleets = conn.execute("SELECT FleetId, Name FROM dbo.Fleets ORDER BY Name").fetchall()
    return render_template("vehicles.html", vehicles=vehicles, fleets=fleets)


# Assign order to vehicle
@app.route("/orders/assign", methods=["GET", "POST"])
def assign_order():
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
        # Only show idle vehicles with remaining capacity > 0
        vehicles = conn.execute(
            "SELECT VehicleId, PlateNo, Status, RemainingWeight FROM dbo.vw_fleet_vehicle_load WHERE Status = N'空闲' AND RemainingWeight > 0 ORDER BY PlateNo"
        ).fetchall()
        drivers = conn.execute("SELECT DriverId, Name FROM dbo.Drivers ORDER BY Name").fetchall()
    return render_template("assign_order.html", vehicles=vehicles, drivers=drivers)


# Record exception
@app.route("/exceptions", methods=["GET", "POST"])
def exceptions():
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
        vehicles = conn.execute("SELECT VehicleId, PlateNo FROM dbo.Vehicles ORDER BY PlateNo").fetchall()
        drivers = conn.execute("SELECT DriverId, Name FROM dbo.Drivers ORDER BY Name").fetchall()
    return render_template("exceptions.html", vehicles=vehicles, drivers=drivers)


# Fleet monthly report
@app.route("/reports/fleet_monthly")
def fleet_monthly():
    fleet_id = request.args.get("fleet_id")
    year = request.args.get("year")
    month = request.args.get("month")
    result = None
    if fleet_id and year and month:
        with get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute("EXEC dbo.sp_fleet_monthly_report @FleetId=?, @Year=?, @Month=?", (int(fleet_id), int(year), int(month)))
            result = cursor.fetchone()
    with get_conn() as conn:
        fleets = conn.execute("SELECT FleetId, Name FROM dbo.Fleets ORDER BY Name").fetchall()
    return render_template("report.html", fleets=fleets, result=result)


# Weekly exception view
@app.route("/views/week_exceptions")
def week_exceptions():
    with get_conn() as conn:
        rows = conn.execute("SELECT TOP 100 * FROM dbo.vw_week_exception_alerts ORDER BY OccurTime DESC").fetchall()
    return render_template("week_exceptions.html", rows=rows)


# Exception processing (mark as processed)
@app.route("/exceptions/process", methods=["GET", "POST"])
def process_exceptions():
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

    # GET: fetch unprocessed exceptions
    with get_conn() as conn:
        exceptions = conn.execute(
            """SELECT e.ExceptionId, e.OccurTime, e.ExceptionType, e.Phase, e.FineAmount,
                      v.PlateNo, v.Status AS VehicleStatus,
                      d.Name AS DriverName
               FROM dbo.Exceptions e
               JOIN dbo.Vehicles v ON v.VehicleId = e.VehicleId
               LEFT JOIN dbo.Drivers d ON d.DriverId = e.DriverId
               WHERE e.Processed = 0
               ORDER BY e.OccurTime DESC"""
        ).fetchall()
    return render_template("process_exceptions.html", exceptions=exceptions)


if __name__ == "__main__":
    # Allow changing port via environment variable to avoid conflicts
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=True)
