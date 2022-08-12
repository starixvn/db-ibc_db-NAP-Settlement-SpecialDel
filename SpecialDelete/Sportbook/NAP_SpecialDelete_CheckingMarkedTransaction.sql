/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_SpecialDelete_CheckingMarkedTransaction
	@TransId VARCHAR(MAX) 
	,@Username VARCHAR(50)
	,@MatchId INT = 0
	,@Action VARCHAR(10) = 'VOID'
AS
/*
	Created by: 20190419@Kathy
	Task : Check marked transaction
	DB: DBTXN/bodb02

	Revisions:
		- 20190419@Kathy: Mark Ticket for Settlement Exclusion [Redmine:#108826]
		
	Param's Explanation: 
		@MatchId = 0 for list transid with more than 1 match
		@Action: VOID/MARK/UNMARK
	*/

BEGIN
	
	DECLARE @Message VARCHAR(MAX)

	DECLARE @tmpTransId TABLE (transid BIGINT, matchid INT)
	DECLARE @tmpMatchId TABLE (matchid INT)
	DECLARE @tmpResult TABLE (matchId INT, TotalVoidedMarkedTicket INT, TotalRunningTicket INT, IsFinished BIT DEFAULT(0))

	INSERT INTO @tmpTransId (transid, matchid)
	SELECT	val, @MatchId
	FROM	dbo.f_SplitString (@transId, ',')
	OPTION (maxrecursion 0)

	IF @MatchId = 0
	BEGIN
		UPDATE t 
			SET matchid = b.matchid
		FROM	@tmpTransId t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON t.transid = b.transid
		
		INSERT INTO @tmpMatchId (matchid)
		SELECT	matchid
		FROM	@tmpTransId
		GROUP BY matchid
	END			
	ELSE
	BEGIN
		INSERT INTO @tmpMatchId (matchid)
		SELECT	@MatchId
	END

	INSERT INTO @tmpResult (matchId, TotalRunningTicket, TotalVoidedMarkedTicket)
	SELECT	b.matchid
			,SUM(CASE WHEN b.statusID IN (0,1) THEN 1 ELSE 0 END) TotalRunningTicket
			,SUM(CASE WHEN t.transid IS NOT NULL THEN 1 ELSE 0 END) TotalVoidedMarkedTicket
	FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON mt.TransId = b.transid
		LEFT JOIN @tmpTransId t
			ON t.transid = mt.TransId
	WHERE mt.MatchId IN (SELECT matchid FROM @tmpMatchId)
	GROUP BY b.matchid

	IF @@ROWCOUNT = 0
		RETURN
	
	DELETE @tmpResult
	WHERE	TotalRunningTicket > 0 OR TotalVoidedMarkedTicket = 0

	SET @Message = 'has all tickets unmarked by '+ @Username

	WHILE (1 = 1)
	BEGIN
		UPDATE TOP (1) @tmpResult
			SET IsFinished = 1
				,@MatchId = matchId
		WHERE	IsFinished = 0

		IF @@ROWCOUNT = 0
			BREAK

		EXEC dbo.NAP_Set_NotificationIns
			@AdminId = 111
			,@MatchId = @MatchId
			,@Action =  @Action
			,@Message =  @Message
	END
END
GO