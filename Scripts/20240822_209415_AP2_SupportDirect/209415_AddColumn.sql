/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240822@Aries
	Task: Enhance AutoPayout2 to support Direct Payout [Redmine:#209415]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
/************************Add setting Cal SDT**************************/
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  object_id = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'EAR_WaitingTime')
BEGIN
	ALTER TABLE  SettlementSetting ADD EAR_WaitingTime  INT;
END

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'Main_InactiveProvider')
BEGIN
	ALTER TABLE SettlementSetting ADD Main_InactiveProvider  VARCHAR(500);
END

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'EAR_InactiveProvider')
BEGIN
	ALTER TABLE SettlementSetting ADD EAR_InactiveProvider  VARCHAR(500);
END

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementSetting]') AND name = 'Enable')
BEGIN
	ALTER TABLE SettlementSetting ADD [Enable]  BIT;
END
