/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20230323@Aries
	Task: Enhance Outright Settlement as User Feedback [Redmine: #185129]
	DB: DBLOG/bodb_CustomerLog

*/
USE bodb_CustomerLog
GO


IF NOT EXISTS (SELECT 1 FROM LogAction WHERE ActionID in (81038, 81039))
BEGIN
    INSERT INTO LogAction(ActionID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,ActionNameVI,ActionNameCN)
    VALUES(81038,'NAP_Set_DeadHeatLeagueUpd','Change Dead Heat Setting','Change Dead Heat Setting','Change Dead Heat Setting','Change Dead Heat Setting','Change Dead Heat Setting','Change Dead Heat Setting','Change Dead Heat Setting','Change Dead Heat Setting','Change Dead Heat Setting'),
          (81039,'NAP_Admin_Outright_Update','Outright - Settlement Event','Outright - Settlement Event','Outright - Settlement Event','Outright - Settlement Event','Outright - Settlement Event','Outright - Settlement Event','Outright - Settlement Event','Outright - Settlement Event','Outright - Settlement Event')
END