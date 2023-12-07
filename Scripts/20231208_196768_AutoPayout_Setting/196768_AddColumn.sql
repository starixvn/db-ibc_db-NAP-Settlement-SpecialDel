/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230711@Aries
	Task: Apply Settle Determined for Basketball [Redmine: #184124]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
/************************Add setting Cal SDT**************************/
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  object_id = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'RetryTime')
BEGIN
	ALTER TABLE  SettlementSetting ADD RetryTime  INT;
END

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'Main_HasTrader')
BEGIN
	ALTER TABLE SettlementSetting ADD Main_HasTrader  BIT ;
END

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'Main_NumberProvider')
BEGIN
	ALTER TABLE SettlementSetting ADD Main_NumberProvider  TINYINT ;
END

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'Main_PrimaryProvider')
BEGIN
	ALTER TABLE SettlementSetting ADD Main_PrimaryProvider  VARCHAR(500);
END

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'Main_TotalPrimaryProvider')
BEGIN
	ALTER TABLE SettlementSetting ADD Main_TotalPrimaryProvider  TINYINT;
END

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'Main_SecondaryProvider')
BEGIN
	ALTER TABLE SettlementSetting ADD Main_SecondaryProvider  VARCHAR(500);
END

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'Main_TotalSecondaryProvider')
BEGIN
	ALTER TABLE SettlementSetting ADD Main_TotalSecondaryProvider  TINYINT;
END



IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'EAR_HasTrader')
BEGIN
	ALTER TABLE SettlementSetting ADD EAR_HasTrader  BIT ;
END


IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'EAR_NumberProvider')
BEGIN
	ALTER TABLE SettlementSetting ADD EAR_NumberProvider  TINYINT ;
END

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'EAR_PrimaryProvider')
BEGIN
	ALTER TABLE SettlementSetting ADD EAR_PrimaryProvider  VARCHAR(500);
END

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'EAR_TotalPrimaryProvider')
BEGIN
	ALTER TABLE SettlementSetting ADD EAR_TotalPrimaryProvider  TINYINT;
END

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'EAR_SecondaryProvider')
BEGIN
	ALTER TABLE SettlementSetting ADD EAR_SecondaryProvider  VARCHAR(500);
END

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'EAR_TotalSecondaryProvider')
BEGIN
	ALTER TABLE SettlementSetting ADD EAR_TotalSecondaryProvider  TINYINT;
END

