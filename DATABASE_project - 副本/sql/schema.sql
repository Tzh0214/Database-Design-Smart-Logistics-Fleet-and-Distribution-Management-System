-- Create database (idempotent)
IF DB_ID('LogisticsDB') IS NULL
    CREATE DATABASE LogisticsDB;
GO
USE LogisticsDB;
GO

-- Centers
CREATE TABLE dbo.Centers (
    CenterId INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    Region NVARCHAR(100) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

-- Fleets (under center)
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
CREATE TABLE dbo.Vehicles (
    VehicleId INT IDENTITY(1,1) PRIMARY KEY,
    FleetId INT NOT NULL,
    PlateNo NVARCHAR(20) NOT NULL UNIQUE,
    MaxWeight DECIMAL(12,2) NOT NULL,
    MaxVolume DECIMAL(12,2) NOT NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT N'空闲',
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Vehicles_Status CHECK (Status IN (N'空闲', N'装货中', N'运输中', N'维修中', N'异常')),
    CONSTRAINT FK_Vehicles_Fleets FOREIGN KEY (FleetId)
        REFERENCES dbo.Fleets(FleetId) ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- Orders (assigned to vehicle, optional driver)
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

-- Indexes
CREATE UNIQUE INDEX IX_Vehicles_PlateNo ON dbo.Vehicles(PlateNo);
CREATE INDEX IX_Orders_OrderDate ON dbo.Orders(OrderDate);
CREATE INDEX IX_Drivers_EmployeeNo ON dbo.Drivers(EmployeeNo);
CREATE INDEX IX_Exceptions_OccurTime ON dbo.Exceptions(OccurTime);
