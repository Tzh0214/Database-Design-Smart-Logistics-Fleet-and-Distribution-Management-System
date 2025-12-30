USE LogisticsDB;
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
