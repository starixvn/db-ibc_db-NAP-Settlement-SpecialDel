/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20230504@Aries
	Task: Un-calculate FT Only [Redmine: #146737]
	DB: DBLOG/bodb_CustomerLog

*/
USE bodb_CustomerLog
GO


IF NOT EXISTS (SELECT 1 FROM LogAction WHERE ActionID in (81040))
BEGIN
    INSERT INTO LogAction(ActionID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,ActionNameVI,ActionNameCN)
    VALUES(81040,'NAP_Admin_Settlement_1','Undo Settlement FT','Undo Settlement FT',N'撤销全场结算','Undo Settlement FT','Undo Settlement FT','Undo Settlement FT','Undo Settlement FT','Undo Settlement FT','Undo Settlement FT')
END

IF NOT EXISTS (SELECT 1 FROM LogAction WHERE ActionID in (81041))
BEGIN
    INSERT INTO LogAction(ActionID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,ActionNameVI,ActionNameCN)
    VALUES(81041,'NAP_Admin_Settlement_Profile_Parlay','Undo Parlay FT','Undo Parlay FT','Undo Parlay FT','Undo Parlay FT','Undo Parlay FT','Undo Parlay FT','Undo Parlay FT','Undo Parlay FT','Undo Parlay FT')
END
