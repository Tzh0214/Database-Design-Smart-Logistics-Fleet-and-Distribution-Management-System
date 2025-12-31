USE LogisticsDB;
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

GO
PRINT N'初始化数据插入完成：3个配送中心、6个车队';
