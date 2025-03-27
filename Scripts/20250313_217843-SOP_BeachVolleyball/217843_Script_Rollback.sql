/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250326@Louisa
	Task: Rollback setting [Redmine:#217843]
	DB: DBPRO/bodb02
*/



 ---Use for case rollback package only


USE bodb02
GO

UPDATE SettlementResultTableSetting WITH(ROWLOCK,UPDLOCK)
SET  AP_Group					= NULL
  ,AP_Check_M_Hold				= NULL
  ,AP_Check_M_Hedge				= NULL
  ,AP_Check_M_Setting			= NULL
  ,AP_Check_R_MactchCompleted	= NULL
  ,AP_Check_R_Hold				= NULL
  ,AP_Check_R_CnfRefund			= NULL
  ,AP_Main_NumberProvider		= NULL
  ,AP_Main_WaitingTime			= NULL
  ,AP_Main_CheckList			= NULL
  ,AP_EAR_NumberProvider		= NULL
  ,AP_EAR_WaitingTime			= NULL
  ,AP_EAR_CheckList				= NULL

  ,IsAppliedSOP					= 0  
  ,Setting						= 1
WHERE Sporttype	= 45

 