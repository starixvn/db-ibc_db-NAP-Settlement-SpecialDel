/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20250821@Hughie
	Task: Apply SOP for Outright [Redmine: #232955]
	DB: DBLOG/bodb_CustomerLog

*/
USE bodb_CustomerLog
GO


IF NOT EXISTS (SELECT 1 FROM LogAction WHERE ActionID in (81064))
BEGIN
    INSERT INTO LogAction(ActionID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,ActionNameVI,ActionNameCN)
    VALUES(81064,'NAP_Set_ProviderResultDetailOutrightIns','Save Score','Save Score',NULL,NULL,NULL,NULL,NULL,NULL,NULL)
END