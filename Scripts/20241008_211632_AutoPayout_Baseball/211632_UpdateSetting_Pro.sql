/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240503@Aries
	Task: AutoPayout2 for Baseball AiO (Regular and Series Matches) [Redmine:#211632]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

UPDATE SettlementResultTableSetting
SET  AP_Group = 1
	,Setting = 7
	,AP_Check_M_Hold = 1
	,AP_Check_M_Hedge = 1
	,AP_Check_M_Setting = 1

	,AP_Check_R_MactchCompleted = 1
	,AP_Check_R_Hold = 1
	,AP_Check_R_CnfRefund = 1

	,AP_Main_NumberProvider = 2
	,AP_Main_WaitingTime = 1800
	,AP_Main_CheckList = '1,2,3,92,97,99'

	,AP_EAR_NumberProvider = 2
	,AP_EAR_WaitingTime = 1800
	,AP_EAR_CheckList  = '1,2,3,99'


WHERE Sporttype = 8
