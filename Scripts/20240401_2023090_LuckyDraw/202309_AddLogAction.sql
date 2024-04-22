/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20240327@Aries
    Task: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize)
    [Redmine:#202309,#200194]

*/
USE bodb_CustomerLog
GO

IF NOT EXISTS (SELECT 1 FROM LogAction WHERE ActionID in (81052))
BEGIN
    INSERT INTO LogAction(ActionID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,ActionNameVI,ActionNameCN)
    VALUES(81052,' Correct Score Lucky Draw',' Correct Score Lucky Draw','Correct Score Lucky Draw','Correct Score Lucky Draw','Correct Score Lucky Draw','Correct Score Lucky Draw','Correct Score Lucky Draw','Correct Score Lucky Draw','Correct Score Lucky Draw','Correct Score Lucky Draw')
END

