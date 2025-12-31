-- ========================================
-- 智慧物流系统 - 完整初始化脚本
-- 包含：建库、建表、视图、存储过程、触发器、初始数据
-- ========================================

-- 1. 创建数据库
IF DB_ID('LogisticsDB') IS NULL
    CREATE DATABASE LogisticsDB;
GO
USE LogisticsDB;
GO

PRINT N'正在创建表结构...';

-- Centers
IF OBJECT_ID('dbo.Centers', 'U') IS NULL
CREATE TABLE dbo.Centers (
    CenterId INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    Region NVARCHAR(100) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

-- Fleets (under center)
IF OBJECT_ID('dbo.Fleets', 'U') IS NULL
CREATE TABLE dbo.Fleets (
    FleetId INT IDENTITY(1,1) PRIMARY KEY,
    CenterId INT NOT NULL,
    Name NVARCHAR(100) NOT NULL,
    FleetType NVARCHAR(50) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Fleets_Centers FOREIGN KEY (CenterId)
        REFERENCES dbo.Centers(CenterId) ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- Drivers (belong to a fleet)
IF OBJECT_ID('dbo.Drivers', 'U') IS NULL
CREATE TABLE dbo.Drivers (
    DriverId INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeNo NVARCHAR(20) NOT NULL UNIQUE,
    Name NVARCHAR(100) NOT NULL,
    LicenseLevel NVARCHAR(20) NOT NULL,
    Phone NVARCHAR(30) NULL,
    FleetId INT NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Drivers_LicenseLevel CHECK (LicenseLevel IN (N'C1', N'C2', N'B1', N'B2', N'A1', N'A2')),
    CONSTRAINT FK_Drivers_Fleets FOREIGN KEY (FleetId)
        REFERENCES dbo.Fleets(FleetId) ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- Vehicles
IF OBJECT_ID('dbo.Vehicles', 'U') IS NULL
CREATE TABLE dbo.Vehicles (
    VehicleId INT IDENTITY(1,1) PRIMARY KEY,
    FleetId INT NOT NULL,
    PlateNo NVARCHAR(20) NOT NULL UNIQUE,
    MaxWeight DECIMAL(12,2) NOT NULL,
    MaxVolume DECIMAL(12,2) NOT NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT N'空闲',
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Vehicles_Status CHECK (Status IN (N'空闲', N'运输中', N'维修中', N'异常')),
    CONSTRAINT FK_Vehicles_Fleets FOREIGN KEY (FleetId)
        REFERENCES dbo.Fleets(FleetId) ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- Orders (assigned to vehicle, optional driver)
IF OBJECT_ID('dbo.Orders', 'U') IS NULL
CREATE TABLE dbo.Orders (
    OrderId INT IDENTITY(1,1) PRIMARY KEY,
    VehicleId INT NOT NULL,
    DriverId INT NULL,
    Weight DECIMAL(12,2) NOT NULL,
    Volume DECIMAL(12,2) NOT NULL,
    Destination NVARCHAR(200) NOT NULL,
    OrderDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    Status NVARCHAR(20) NOT NULL DEFAULT N'新建',
    CONSTRAINT CK_Orders_Status CHECK (Status IN (N'新建', N'装货中', N'运输中', N'已完成', N'取消')),
    CONSTRAINT FK_Orders_Vehicles FOREIGN KEY (VehicleId)
        REFERENCES dbo.Vehicles(VehicleId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Orders_Drivers FOREIGN KEY (DriverId)
        REFERENCES dbo.Drivers(DriverId) ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- Exceptions
IF OBJECT_ID('dbo.Exceptions', 'U') IS NULL
CREATE TABLE dbo.Exceptions (
    ExceptionId INT IDENTITY(1,1) PRIMARY KEY,
    VehicleId INT NOT NULL,
    DriverId INT NULL,
    OccurTime DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ExceptionType NVARCHAR(50) NOT NULL,
    Phase NVARCHAR(20) NOT NULL,
    FineAmount DECIMAL(12,2) NOT NULL DEFAULT 0,
    Processed BIT NOT NULL DEFAULT 0,
    ProcessedTime DATETIME2 NULL,
    CONSTRAINT CK_Exceptions_Type CHECK (ExceptionType IN (N'货物破损', N'车辆故障', N'严重延误', N'超速报警')),
    CONSTRAINT CK_Exceptions_Phase CHECK (Phase IN (N'运输中异常', N'空闲时异常')),
    CONSTRAINT FK_Exceptions_Vehicles FOREIGN KEY (VehicleId)
        REFERENCES dbo.Vehicles(VehicleId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Exceptions_Drivers FOREIGN KEY (DriverId)
        REFERENCES dbo.Drivers(DriverId) ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- History Log (audit)
IF OBJECT_ID('dbo.History_Log', 'U') IS NULL
CREATE TABLE dbo.History_Log (
    LogId INT IDENTITY(1,1) PRIMARY KEY,
    Entity NVARCHAR(50) NOT NULL,
    EntityId INT NOT NULL,
    Action NVARCHAR(50) NOT NULL,
    OldValue NVARCHAR(MAX) NULL,
    NewValue NVARCHAR(MAX) NULL,
    ChangedBy NVARCHAR(100) NULL,
    ChangedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

-- Managers (one per fleet)
IF OBJECT_ID('dbo.Managers', 'U') IS NULL
CREATE TABLE dbo.Managers (
    ManagerId INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    FleetId INT NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Managers_Fleets FOREIGN KEY (FleetId)
        REFERENCES dbo.Fleets(FleetId) ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- Users (for login)
IF OBJECT_ID('dbo.Users', 'U') IS NULL
CREATE TABLE dbo.Users (
    UserId INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(50) NOT NULL UNIQUE,
    Password NVARCHAR(100) NOT NULL, -- In real app, hash this
    Role NVARCHAR(20) NOT NULL, -- 'Manager', 'Driver'
    RelatedId INT NULL, -- DriverId or ManagerId
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Users_Role CHECK (Role IN (N'Manager', N'Driver'))
);

-- Indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Vehicles_PlateNo')
CREATE UNIQUE INDEX IX_Vehicles_PlateNo ON dbo.Vehicles(PlateNo);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Orders_OrderDate')
CREATE INDEX IX_Orders_OrderDate ON dbo.Orders(OrderDate);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Drivers_EmployeeNo')
CREATE INDEX IX_Drivers_EmployeeNo ON dbo.Drivers(EmployeeNo);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Exceptions_OccurTime')
CREATE INDEX IX_Exceptions_OccurTime ON dbo.Exceptions(OccurTime);
GO

PRINT N'正在创建视图...';
GO

-- View: Weekly exception alerts
CREATE OR ALTER VIEW dbo.vw_week_exception_alerts AS
SELECT e.ExceptionId, e.OccurTime, e.ExceptionType, e.Phase, e.FineAmount, e.Processed,
       v.VehicleId, v.PlateNo, v.Status AS VehicleStatus,
       d.DriverId, d.Name AS DriverName, d.EmployeeNo,
       f.FleetId, f.Name AS FleetName, c.CenterId, c.Name AS CenterName
FROM dbo.Exceptions e
JOIN dbo.Vehicles v ON v.VehicleId = e.VehicleId
LEFT JOIN dbo.Drivers d ON d.DriverId = e.DriverId
JOIN dbo.Fleets f ON f.FleetId = v.FleetId
JOIN dbo.Centers c ON c.CenterId = f.CenterId
WHERE e.OccurTime >= DATEADD(DAY, -7, SYSDATETIME());
GO

-- View: Fleet vehicle load summary
CREATE OR ALTER VIEW dbo.vw_fleet_vehicle_load AS
SELECT v.VehicleId, v.PlateNo, v.FleetId, v.Status,
       ISNULL(ActiveLoad.TotalWeight, 0) AS AssignedWeight,
       v.MaxWeight - ISNULL(ActiveLoad.TotalWeight, 0) AS RemainingWeight,
       ISNULL(ActiveLoad.TotalVolume, 0) AS AssignedVolume,
       v.MaxVolume - ISNULL(ActiveLoad.TotalVolume, 0) AS RemainingVolume
FROM dbo.Vehicles v
OUTER APPLY (
    SELECT SUM(o.Weight) AS TotalWeight, SUM(o.Volume) AS TotalVolume
    FROM dbo.Orders o
    WHERE o.VehicleId = v.VehicleId AND o.Status IN (N'新建', N'装货中', N'运输中')
) ActiveLoad;
GO

PRINT N'正在创建存储过程...';
GO

-- Stored Procedure: Monthly safety & efficiency report per fleet
CREATE OR ALTER PROCEDURE dbo.sp_fleet_monthly_report
    @FleetId INT,
    @Year INT,
    @Month INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartDate DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @EndDate DATE = EOMONTH(@StartDate);

    ;WITH FleetVehicles AS (
        SELECT VehicleId FROM dbo.Vehicles WHERE FleetId = @FleetId
    )
    SELECT 
        @FleetId AS FleetId,
        COUNT(*) AS TotalOrders,
        SUM(CASE WHEN o.Status = N'已完成' THEN 1 ELSE 0 END) AS CompletedOrders,
        SUM(CASE WHEN o.Status IN (N'新建', N'装货中', N'运输中') THEN 1 ELSE 0 END) AS ActiveOrders,
        (SELECT COUNT(*) FROM dbo.Exceptions e JOIN FleetVehicles fv ON fv.VehicleId = e.VehicleId
         WHERE e.OccurTime >= @StartDate AND e.OccurTime < DATEADD(DAY, 1, @EndDate)) AS TotalExceptions,
        (SELECT ISNULL(SUM(e.FineAmount), 0) FROM dbo.Exceptions e JOIN FleetVehicles fv ON fv.VehicleId = e.VehicleId
         WHERE e.OccurTime >= @StartDate AND e.OccurTime < DATEADD(DAY, 1, @EndDate)) AS TotalFineAmount,
        CAST(NULL AS DECIMAL(5,2)) AS CompletionRate
    FROM dbo.Orders o
    JOIN FleetVehicles fv ON fv.VehicleId = o.VehicleId
    WHERE o.OrderDate >= @StartDate AND o.OrderDate < DATEADD(DAY, 1, @EndDate);
END
GO

-- Stored Procedure: Driver Performance Tracking
CREATE OR ALTER PROCEDURE dbo.sp_driver_performance_report
    @DriverId INT,
    @StartDate DATETIME2,
    @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Order Statistics
    SELECT 
        COUNT(OrderId) AS TotalOrders,
        SUM(CASE WHEN Status = N'已完成' THEN 1 ELSE 0 END) AS CompletedOrders,
        SUM(Weight) AS TotalWeight,
        SUM(Volume) AS TotalVolume
    FROM dbo.Orders
    WHERE DriverId = @DriverId 
      AND OrderDate BETWEEN @StartDate AND @EndDate;

    -- 2. Exception Details
    SELECT 
        ExceptionId,
        VehicleId,
        OccurTime,
        ExceptionType,
        Phase,
        FineAmount,
        Processed
    FROM dbo.Exceptions
    WHERE DriverId = @DriverId
      AND OccurTime BETWEEN @StartDate AND @EndDate
    ORDER BY OccurTime DESC;
END
GO

PRINT N'正在创建触发器...';
GO

-- 1) Weight check on order assignment (INSTEAD OF INSERT)
CREATE OR ALTER TRIGGER dbo.TR_Orders_CheckWeight
ON dbo.Orders
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    -- Validate against vehicle capacity
    ;WITH NewByVehicle AS (
        SELECT VehicleId, SUM(Weight) AS NewWeight
        FROM inserted
        GROUP BY VehicleId
    ), CurrLoad AS (
        SELECT o.VehicleId, SUM(o.Weight) AS CurrWeight
        FROM dbo.Orders o
        WHERE o.Status IN (N'新建', N'装货中', N'运输中')
          AND EXISTS (SELECT 1 FROM inserted i WHERE i.VehicleId = o.VehicleId)
        GROUP BY o.VehicleId
    )
    SELECT v.VehicleId
    INTO #OverWeight
    FROM NewByVehicle n
    JOIN dbo.Vehicles v ON v.VehicleId = n.VehicleId
    LEFT JOIN CurrLoad c ON c.VehicleId = n.VehicleId
    WHERE (ISNULL(c.CurrWeight, 0) + n.NewWeight) > v.MaxWeight;

    IF EXISTS (SELECT 1 FROM #OverWeight)
    BEGIN
        DROP TABLE #OverWeight;
        THROW 51000, N'超出最大载重，运单分配失败', 1;
        RETURN;
    END

    -- Passed: insert rows
    INSERT INTO dbo.Orders (VehicleId, DriverId, Weight, Volume, Destination, OrderDate, Status)
    SELECT VehicleId, DriverId, Weight, Volume, Destination, ISNULL(OrderDate, SYSDATETIME()), ISNULL(Status, N'新建')
    FROM inserted;

    -- Set vehicle status to "运输中" when it has active orders
    UPDATE v
    SET v.Status = N'运输中'
    FROM dbo.Vehicles v
    WHERE EXISTS (
        SELECT 1 FROM dbo.Orders o
        WHERE o.VehicleId = v.VehicleId
          AND o.Status IN (N'新建', N'装货中', N'运输中')
    );
END
GO

-- 2) Vehicle status auto flow after order status updates
CREATE OR ALTER TRIGGER dbo.TR_Orders_AfterUpdate_Status
ON dbo.Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- When orders become active, set vehicle to "运输中"
    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.Status IN (N'新建', N'装货中', N'运输中')
    )
    BEGIN
        UPDATE v
        SET v.Status = N'运输中'
        FROM dbo.Vehicles v
        WHERE EXISTS (
            SELECT 1 FROM inserted i WHERE i.VehicleId = v.VehicleId
        );
    END

    -- When orders complete, if no active orders remain, set vehicle to "空闲"
    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.Status = N'已完成'
    )
    BEGIN
        UPDATE v
        SET v.Status = N'空闲'
        FROM dbo.Vehicles v
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.Orders o
            WHERE o.VehicleId = v.VehicleId
              AND o.Status IN (N'新建', N'装货中', N'运输中')
        )
        AND EXISTS (
            SELECT 1 FROM inserted i WHERE i.VehicleId = v.VehicleId
        );
    END
END
GO

-- 3) Set vehicle to "异常" when an exception is inserted
CREATE OR ALTER TRIGGER dbo.TR_Exceptions_AfterInsert_Status
ON dbo.Exceptions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE v
    SET v.Status = N'异常'
    FROM dbo.Vehicles v
    WHERE EXISTS (SELECT 1 FROM inserted i WHERE i.VehicleId = v.VehicleId);
END
GO

-- 4) Vehicle status restore when exception processed
CREATE OR ALTER TRIGGER dbo.TR_Exceptions_AfterUpdate_Processed
ON dbo.Exceptions
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- Audit logs when processed changes
    INSERT INTO dbo.History_Log (Entity, EntityId, Action, OldValue, NewValue, ChangedBy)
    SELECT N'Exception', d.ExceptionId, N'Processed',
           CONCAT(N'Processed(old)=', CAST(d.Processed AS NVARCHAR(5))),
           CONCAT(N'Processed(new)=', CAST(i.Processed AS NVARCHAR(5))),
           SUSER_SNAME()
    FROM deleted d
    JOIN inserted i ON i.ExceptionId = d.ExceptionId
    WHERE ISNULL(d.Processed, 0) <> ISNULL(i.Processed, 0);

    -- When processed=1, restore vehicle status
    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.Processed = 1
    )
    BEGIN
        UPDATE v
        SET v.Status = CASE
            WHEN EXISTS (
                SELECT 1 FROM dbo.Orders o
                WHERE o.VehicleId = v.VehicleId
                  AND o.Status IN (N'新建', N'装货中', N'运输中')
            ) THEN N'运输中' ELSE N'空闲' END
        FROM dbo.Vehicles v
        WHERE EXISTS (
            SELECT 1 FROM inserted i WHERE i.VehicleId = v.VehicleId AND i.Processed = 1
        );
    END
END
GO

-- 5) Audit when driver license level changes
CREATE OR ALTER TRIGGER dbo.TR_Drivers_AfterUpdate_LicenseAudit
ON dbo.Drivers
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.History_Log (Entity, EntityId, Action, OldValue, NewValue, ChangedBy)
    SELECT N'Driver', d.DriverId, N'LicenseLevelChange',
           CONCAT(N'LicenseLevel(old)=', d.LicenseLevel),
           CONCAT(N'LicenseLevel(new)=', i.LicenseLevel),
           SUSER_SNAME()
    FROM deleted d
    JOIN inserted i ON i.DriverId = d.DriverId
    WHERE d.LicenseLevel <> i.LicenseLevel;
END
GO

PRINT N'正在插入初始数据...';
GO

-- Insert sample centers
SET IDENTITY_INSERT dbo.Centers ON;
INSERT INTO dbo.Centers (CenterId, Name, Region, CreatedAt) VALUES
(1, N'华东配送中心', N'上海', SYSDATETIME()),
(2, N'华北配送中心', N'北京', SYSDATETIME()),
(3, N'华南配送中心', N'广州', SYSDATETIME());
SET IDENTITY_INSERT dbo.Centers OFF;

-- Insert sample fleets
SET IDENTITY_INSERT dbo.Fleets ON;
INSERT INTO dbo.Fleets (FleetId, CenterId, Name, FleetType, CreatedAt) VALUES
(1, 1, N'干线车队', N'长途运输', SYSDATETIME()),
(2, 1, N'同城配送车队', N'市内配送', SYSDATETIME()),
(3, 1, N'A队', N'通用', SYSDATETIME()),
(4, 2, N'B队', N'通用', SYSDATETIME()),
(5, 2, N'干线车队', N'长途运输', SYSDATETIME()),
(6, 3, N'快递车队', N'快递配送', SYSDATETIME());
SET IDENTITY_INSERT dbo.Fleets OFF;

-- Insert Drivers
INSERT INTO dbo.Drivers (Name, EmployeeNo, LicenseLevel, Phone, FleetId) VALUES
(N'张三', N'D001', N'A1', N'13800138001', 1),
(N'李四', N'D002', N'B2', N'13800138002', 1),
(N'王五', N'D003', N'C1', N'13800138003', 2);

-- Insert Vehicles
INSERT INTO dbo.Vehicles (FleetId, PlateNo, MaxWeight, MaxVolume, Status) VALUES
(1, N'沪A88888', 10.0, 20.0, N'空闲'),
(1, N'沪A66666', 15.0, 30.0, N'空闲'),
(2, N'沪B12345', 5.0, 10.0, N'空闲');

-- Insert Managers
INSERT INTO dbo.Managers (Name, FleetId) VALUES
(N'赵主管', 1),
(N'钱主管', 2);

-- Insert Users
-- Password '123456' for all
INSERT INTO dbo.Users (Username, Password, Role, RelatedId) VALUES
(N'manager1', N'123456', N'Manager', 1), -- Links to Zhao (Fleet 1)
(N'manager2', N'123456', N'Manager', 2), -- Links to Qian (Fleet 2)
(N'driver1', N'123456', N'Driver', 1),   -- Links to Zhang San
(N'driver2', N'123456', N'Driver', 2),   -- Links to Li Si
(N'driver3', N'123456', N'Driver', 3);   -- Links to Wang Wu

GO
PRINT N'========================================';
PRINT N'初始化完成！';
PRINT N'========================================';
