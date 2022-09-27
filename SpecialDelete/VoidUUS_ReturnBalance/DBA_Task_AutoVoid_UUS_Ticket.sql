/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[DBA_Task_AutoVoid_UUS_Ticket]
	@CheckTime DATETIME = NULL
AS

/*
	Created: 20190118@Patrick
	Task: Auto void UUS ticket which exceed 24 hour from place bet
	DB: DBTrans.bodb02
	Revision:
		- 20211216@July: Update column RepUpdateTime when Void/Recover - [Redmine: #164236]
		- 20220926@Max: Change code for scale out dbtrans [Redmine: #175412]
*/
BEGIN
	SET NOCOUNT ON

	IF @CheckTime IS NULL
		SET @CheckTime = DATEADD(HOUR, -12, GETDATE())

	DECLARE @__checkTime DATETIME

	SELECT @__checkTime = @CheckTime

	--//get all test match
	CREATE TABLE #__matchList (matchid INT)
	INSERT INTO #__matchList (matchid)
	SELECT DISTINCT m.matchid
	FROM dbo.match m WITH(NOLOCK)
	WHERE leagueid IN (SELECT l.leagueid FROM dbo.League l WITH(NOLOCK) WHERE l.isTest = 1)
	
	CREATE TABLE #__autoVoid_TransList (TransId BIGINT)
	INSERT INTO #__autoVoid_TransList (TransId)
	SELECT b.TransId
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE b.matchid IN (SELECT t.matchid FROM #__matchList t)
		AND b.currency = 20 AND b.transdate < @__checkTime
		AND b.bettype <= 19000 AND b.statusID = 1 --waiting

	IF EXISTS (SELECT TOP 1 1 FROM #__autoVoid_TransList)
	BEGIN
		DECLARE @__transIdsTmp TABLE(transId BIGINT)
		
		WHILE 1 = 1 
		BEGIN

			DELETE FROM @__transIdsTmp

			DELETE TOP(1000) 
			FROM #__autoVoid_TransList
			OUTPUT deleted.transid INTO @__transIdsTmp

			IF @@ROWCOUNT = 0
				BREAK

			UPDATE b
			SET winlost = actual_stake, ruben = 1, statuswinlost = 6, status = 'VOID', statusid = 102
				, awinlost = 0, mwinlost = 0, swinlost = 0, playercomm = 0, comm  = 0, acomm = 0
				, scomm = 0, transdesc = '[Waiting-AutoVoid]' + transdesc
				, FcUpdateTime = SYSDATETIME()
			FROM @__transIdsTmp t
				INNER JOIN dbo.bettrans b WITH (ROWLOCK, UPDLOCK) ON t.TransId = b.transid
			OPTION (FORCE ORDER) --hint for case bad plan

			--about updatting Balance Table will leave it for "Balance Correction" job.
		END

	END

	DROP TABLE #__AutoVoid_TransList
	DROP TABLE #__matchList
END
GO


