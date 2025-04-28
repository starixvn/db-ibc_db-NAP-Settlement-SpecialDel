/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20250401@Max
    Task: [TVS] Virtual Sports 7 (Kiron Virtual Sports) [Redmine: #219045]
    DB: DBLOG-bodb_CustomerLog

*/
USE bodb_CustomerLog
GO

IF NOT EXISTS (SELECT 1 FROM LogAction WHERE ActionID in (90519))
BEGIN
    INSERT INTO LogAction(ActionID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,ActionNameVI,ActionNameCN)
    VALUES(90519,'Recover Virtual Sports','Recover Virtual Sports','Recover Virtual Sports','Recover Virtual Sports','Recover Virtual Sports','Recover Virtual Sports','Recover Virtual Sports','Recover Virtual Sports','Recover Virtual Sports','Recover Virtual Sports')
END


