/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20230323@Aries
	Task: Enhance Outright Settlement as User Feedback [Redmine: #185129]
	DB: DBLOG/bodb_CustomerLog

*/
USE bodb_CustomerLog
GO


IF NOT EXISTS (SELECT 1 FROM LogAction WHERE ActionID in (81042))
BEGIN
    INSERT INTO LogAction(ActionID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,ActionNameVI,ActionNameCN)
    VALUES(81042,'NAP_Admin_Settlement_Profile_Instant','Auto Instant','Auto Instant','Auto Instant','Auto Instant','Auto Instant','Auto Instant','Auto Instant','Auto Instant','Auto Instant')
END