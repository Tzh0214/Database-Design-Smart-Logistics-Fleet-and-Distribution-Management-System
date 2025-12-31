USE LogisticsDB;
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
