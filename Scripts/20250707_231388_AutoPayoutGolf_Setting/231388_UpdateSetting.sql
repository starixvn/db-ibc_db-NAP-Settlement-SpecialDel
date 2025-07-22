/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250709@Max
	Task: Auto Payout 2- Support Template with FT only for Golf [Redmine: #231388]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

UPDATE SettlementResultTableSetting WITH (ROWLOCK, UPDLOCK)
SET  Setting = 2
	,AP_Group = 1
	,AP_Check_M_Hold = 1
	,AP_Check_M_Hedge = 1
	,AP_Check_M_Setting = 1

	,AP_Check_R_MactchCompleted = 1
	,AP_Check_R_Hold = 1
	,AP_Check_R_CnfRefund = 1

	,AP_Main_NumberProvider = 2
	,AP_Main_WaitingTime = 1800
	,AP_Main_CheckList = '1,2,3,99'

	,AP_EAR_NumberProvider = 2
	,AP_EAR_WaitingTime = 1800
	,AP_EAR_CheckList  = '1,2,3,99'

WHERE Sporttype = 10

