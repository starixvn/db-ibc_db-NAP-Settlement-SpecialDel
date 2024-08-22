/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20240822@Aries
	Task: Enhance AutoPayout2 to support Direct Payout [Redmine:#209415]
	DB: DBLOG/bodb_CustomerLog

*/
USE bodb_CustomerLog
GO

IF NOT EXISTS (SELECT 1 FROM LogAction WITH(NOLOCK) WHERE ActionID in (81057))
BEGIN
    INSERT INTO LogAction(ActionID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,ActionNameVI,ActionNameCN)
    VALUES(81057,'NAP_Set_AutoPayout_LeagueSetting_Update','Auto Payout Setting League','Auto Payout Setting League','Auto Payout Setting Match','Auto Payout Setting Match','Auto Payout Setting Match','Auto Payout Setting Match','Auto Payout Setting Match','Auto Payout Setting Match','Auto Payout Setting Match')
END
    
IF NOT EXISTS (SELECT 1 FROM LogAction WITH(NOLOCK) WHERE ActionID in (81058))
BEGIN
    INSERT INTO LogAction(ActionID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,ActionNameVI,ActionNameCN)
    VALUES(81058,'NAP_Set_AutoPayout_SettingMatchUpd','Auto Payout Setting Match','Auto Payout Setting Match','Auto Payout Setting Match','Auto Payout Setting Match','Auto Payout Setting Match','Auto Payout Setting Match','Auto Payout Setting Match','Auto Payout Setting Match','Auto Payout Setting Match')
END
