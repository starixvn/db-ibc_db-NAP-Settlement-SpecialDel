/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20231002@Aries
	Task: Auto Payout for e-Sports  [Redmine: #191875]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
 
USE bodb02
GO

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementResultTableSetting]') AND name = 'AP_Group')
BEGIN
	ALTER TABLE SettlementResultTableSetting ADD AP_Group SMALLINT;
END

GO
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementResultTableSetting]') AND name = 'AP_Check_M_Hold')
BEGIN
	ALTER TABLE SettlementResultTableSetting ADD AP_Check_M_Hold BIT;
END
GO
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementResultTableSetting]') AND name = 'AP_Check_M_Hedge')
BEGIN
	ALTER TABLE SettlementResultTableSetting ADD AP_Check_M_Hedge BIT;
END
GO
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementResultTableSetting]') AND name = 'AP_Check_M_Setting')
BEGIN
	ALTER TABLE SettlementResultTableSetting ADD AP_Check_M_Setting BIT;
END
GO
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementResultTableSetting]') AND name = 'AP_Check_R_MactchCompleted')
BEGIN
	ALTER TABLE SettlementResultTableSetting ADD AP_Check_R_MactchCompleted BIT;
END
GO
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementResultTableSetting]') AND name = 'AP_Check_R_Hold')
BEGIN
	ALTER TABLE SettlementResultTableSetting ADD AP_Check_R_Hold BIT;
END
GO
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementResultTableSetting]') AND name = 'AP_Check_R_CnfRefund')
BEGIN
	ALTER TABLE SettlementResultTableSetting ADD AP_Check_R_CnfRefund BIT;
END
GO
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementResultTableSetting]') AND name = 'AP_Main_NumberProvider')
BEGIN
	ALTER TABLE SettlementResultTableSetting ADD AP_Main_NumberProvider  TINYINT ;
END

GO
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementResultTableSetting]') AND name = 'AP_Main_WaitingTime')
BEGIN
	ALTER TABLE SettlementResultTableSetting ADD AP_Main_WaitingTime  INT ;
END

GO
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementResultTableSetting]') AND name = 'AP_Main_CheckList')
BEGIN
	ALTER TABLE SettlementResultTableSetting ADD AP_Main_CheckList  VARCHAR(100) ;
END

GO
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementResultTableSetting]') AND name = 'AP_EAR_NumberProvider')
BEGIN
	ALTER TABLE SettlementResultTableSetting ADD AP_EAR_NumberProvider  TINYINT ;
END
GO

IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementResultTableSetting]') AND name = 'AP_EAR_WaitingTime')
BEGIN
	ALTER TABLE SettlementResultTableSetting ADD AP_EAR_WaitingTime  INT ;
END

GO
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  OBJECT_ID = OBJECT_ID(N'[dbo].[SettlementResultTableSetting]') AND name = 'AP_EAR_CheckList')
BEGIN
	ALTER TABLE SettlementResultTableSetting ADD AP_EAR_CheckList  VARCHAR(100) ;
END


GO
UPDATE SettlementResultTableSetting
SET  AP_Group = 1
	,AP_Check_M_Hold = 1
	,AP_Check_M_Hedge = 1
	,AP_Check_M_Setting = 1

	,AP_Check_R_MactchCompleted = 1
	,AP_Check_R_Hold = 1
	,AP_Check_R_CnfRefund = 1

	,AP_Main_NumberProvider = 2
	,AP_Main_WaitingTime = 1800
	,AP_Main_CheckList = '2,3,99'

	,AP_EAR_NumberProvider = 2
	,AP_EAR_WaitingTime = 1800
	,AP_EAR_CheckList  = '2,3,99'

WHERE Sporttype = 50

