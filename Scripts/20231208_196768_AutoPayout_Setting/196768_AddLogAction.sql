/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20231211@Aries
	Task: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
	DB: DBLOG/bodb_CustomerLog

*/
USE bodb_CustomerLog
GO

IF NOT EXISTS (SELECT 1 FROM LogAction WHERE ActionID in (81048))
BEGIN
    INSERT INTO LogAction(ActionID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,ActionNameVI,ActionNameCN)
    VALUES(81048,'NAP_Set_AutoPayout_LeagueSetting_Update','Update Auto Payout League Setting','Update Auto Payout League Setting','Update Auto Payout League Setting','Update Auto Payout League Setting','Update Auto Payout League Setting','Update Auto Payout League Setting','Update Auto Payout League Setting','Update Auto Payout League Setting','Update Auto Payout League Setting')
END
