/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20210701@Kathy
	Task :change action name
	DB: DBLOG/bodb_CustomerLog
*/
USE bodb_CustomerLog
GO

DECLARE @ActionName VARCHAR(50) 

-----
SET @ActionName = 'Calculate Parlay'
UPDATE l 
	SET ActionNameEN = @ActionName
		--,ActionNameCH = ''
		--,ActionNameCN = ''
		--,ActionNameCS = ''
		,ActionNameIT = @ActionName
		,ActionNameJP = @ActionName
		,ActionNameKO = @ActionName
		,ActionNameTH = @ActionName
		,ActionNameVI = @ActionName

FROM	dbo.LogAction l WITH (ROWLOCK, UPDLOCK)
WHERE	ActionID = 104

-----
SET @ActionName = 'Undo Parlay'
UPDATE l 
	SET ActionNameEN = @ActionName
		--,ActionNameCH = ''
		--,ActionNameCN = ''
		--,ActionNameCS = ''
		,ActionNameIT = @ActionName
		,ActionNameJP = @ActionName
		,ActionNameKO = @ActionName
		,ActionNameTH = @ActionName
		,ActionNameVI = @ActionName

FROM	dbo.LogAction l WITH (ROWLOCK, UPDLOCK)
WHERE	ActionID = 105

-----
SET @ActionName = 'Refund Parlay'
UPDATE l 
	SET ActionNameEN = @ActionName
		--,ActionNameCH = ''
		--,ActionNameCN = ''
		--,ActionNameCS = ''
		,ActionNameIT = @ActionName
		,ActionNameJP = @ActionName
		,ActionNameKO = @ActionName
		,ActionNameTH = @ActionName
		,ActionNameVI = @ActionName

FROM	dbo.LogAction l WITH (ROWLOCK, UPDLOCK)
WHERE	ActionID = 107


