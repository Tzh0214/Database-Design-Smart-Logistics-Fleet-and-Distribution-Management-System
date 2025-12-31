USE LogisticsDB;
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

    -- Optional: compute completion rate as completed / total
    -- Client can compute if needed
END
GO
