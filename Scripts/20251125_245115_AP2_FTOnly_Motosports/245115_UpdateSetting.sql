/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
/*
    Created: 20251125@Hughie
	Task: Support Template with FT only for Motosports [Redmine: #245115]
	DB: DBPRO/bodb02
*/


USE bodb02
GO
 UPDATE A WITH (ROWLOCK, UPDLOCK)
 SET A.Setting							= 2
	,A.AP_Group							= 1
	,A.AP_Check_M_Hold					= 1
	,A.AP_Check_M_Hedge					= 1
	,A.AP_Check_M_Setting				= 1
	,A.AP_Check_R_MactchCompleted		= 1
	,A.AP_Check_R_Hold					= 1
	,A.AP_Check_R_CnfRefund				= 1
	,A.AP_Main_NumberProvider			= 2
	,A.AP_Main_WaitingTime				= 1800
	,A.AP_EAR_NumberProvider			= 2
	,A.AP_EAR_WaitingTime				= 1800
	,A.AP_Main_CheckList				= '1,2,3,99'
	,A.AP_EAR_CheckList					= '1,2,3,99'
 FROM SettlementResultTableSetting A
 WHERE Sporttype = 11
GO