/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20250923@Hughie
	Task: Apply SOP for Outright phase 2 [Redmine: #233004]
	DB: DBLOG/bodb_CustomerLog

*/
USE bodb_CustomerLog
GO


IF NOT EXISTS (SELECT 1 FROM LogAction WHERE ActionID in (81065))
BEGIN
    INSERT INTO LogAction(ActionID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,ActionNameVI,ActionNameCN)
    VALUES(81065,'NAP_Set_OutrightResultDetailUpd','Save Trader Score','Save Trader Score',NULL,NULL,NULL,NULL,NULL,NULL,NULL)
END