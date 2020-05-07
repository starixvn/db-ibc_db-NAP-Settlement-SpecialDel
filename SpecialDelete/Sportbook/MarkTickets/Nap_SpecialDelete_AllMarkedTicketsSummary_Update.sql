
/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Nap_SpecialDelete_AllMarkedTicketsSummary_Update] @Matches  XML           = NULL,
                                                                         @UserId   INT           = 0,
                                                                         @Username NVARCHAR(100) = N'',
                                                                         @IP       VARCHAR(15)   = NULL,
                                                                         @ErrMsg   NVARCHAR(200) = '' OUTPUT,
                                                                         @ErrCode  INT           = 0 OUTPUT
AS
/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion [108826]
		- 20190606@Raymond.Le: Mark Tickets Enhancement - Phase 4, change write log for mark/unmark [114596]
		- 20201604@Charles: Implement parlay tickets for Mark ticket [131670]
		
	Explanation's Param:
	@Matches: <Matches><Match MatchId="1" UserId="1" CreatedDate="2019-03-04 04:11:33.240"/></Matches>
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #Match (
		MatchId INT
		,UserId INT
		,CreatedDate DATETIME
		);

	CREATE TABLE #MarkedTransactionDeleted (
		TransId BIGINT
		,MatchId INT
		);

	INSERT INTO #Match (
		MatchId
		,UserId
		,CreatedDate
		)
	SELECT x.value('@MatchId', 'INT') AS MatchId
		,x.value('@UserId', 'INT') AS UserId
		,x.value('@CreatedDate', 'DATETIME') AS CreatedDate
	FROM @Matches.nodes('Matches/Match') XmlData(x)
	OPTION (OPTIMIZE FOR (@Matches = NULL));

	-- Delete transaction for single tickets
	WHILE (0 = 0)
	BEGIN
		DELETE TOP (2000) m
		OUTPUT DELETED.TransId
			,DELETED.MatchId
		INTO #MarkedTransactionDeleted(TransId, MatchId)
		FROM dbo.MarkedTransaction m WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = m.TransId AND b.MatchId = m.MatchId
		INNER JOIN #Match t ON t.MatchId = m.MatchId
								AND t.UserId = m.UserId
								AND m.CreatedDate = t.CreatedDate
		WHERE b.statusID IN(0, 1);				

		IF @@ROWCOUNT = 0
			BREAK;
	END;

	-- Delete transaction for parlay tickets
	WHILE (0 = 0)
	BEGIN
		DELETE TOP (2000) m
		OUTPUT DELETED.TransId
			,DELETED.MatchId
		INTO #MarkedTransactionDeleted(TransId, MatchId)
		FROM dbo.MarkedTransaction m WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.MatchId = m.MatchId
		INNER JOIN dbo.bettrans bt WITH (NOLOCK) ON bm.refno = bt.refno AND bt.TransId = m.TransId
		INNER JOIN #Match t ON t.MatchId = m.MatchId
								AND t.UserId = m.UserId
								AND m.CreatedDate = t.CreatedDate
		WHERE bm.statusID IN(0, 1);				

		IF @@ROWCOUNT = 0
			BREAK;
	END;

	-- Insert Settled_Message
	INSERT INTO [dbo].[Settled_Message] (
		[AdminId]
		,[MatchId]
		,[IP]
		,[Starttime]
		,[Action]
		,[Message]
		,[IsRead]
		,[Warning]
		,[IsSent]
		)
	SELECT 111
		,t.matchid
		,@IP
		,GETDATE()
		,'UNMARK'
		,'has all tickets unmarked by ' + @Username
		,0
		,NULL
		,0
    FROM #Match t 
        LEFT JOIN
		(
			SELECT m.matchid
			FROM dbo.MarkedTransaction m WITH (NOLOCK)
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = m.TransId
													AND b.statusID IN(0, 1)
		) mt ON mt.MatchId = t.MatchId
    WHERE mt.MatchId IS NULL;

	SELECT b.MatchId
		,m.HomeId
		,m.AwayId
		,m.SportType
		,m.IsNeutral
	FROM #Match b
		INNER JOIN match m WITH (NOLOCK) ON b.MatchId = m.MatchId;

	-- Write Log
	DECLARE @xmlLog VARCHAR(MAX);
	
	;WITH CTE_Match AS (
		SELECT DISTINCT MatchId
		FROM #Match
	)
	SELECT @xmlLog = CAST((
				SELECT 90502 AS '@LogActionId' -- 90502: Action Unmark All
					,@UserId AS '@UserId'
					,@IP AS '@IP'
					,m.MatchId AS '@MatchId'
					,STUFF((
							SELECT ',' + CAST(d.TransId AS NVARCHAR(100))
							FROM #MarkedTransactionDeleted AS d
							WHERE d.MatchId = m.MatchId
							FOR XML PATH('')
							), 1, 1, '') AS '@LogData'
				FROM CTE_Match AS m
				FOR XML PATH('r')
					,ROOT('root')
					,TYPE
				) AS VARCHAR(MAX));

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @xmlLog
		,@functionName = 'TicketVoiding'
		,@MessageType = 'MessageType_TicketVoiding_Log';

	DROP TABLE #Match;
	DROP TABLE #MarkedTransactionDeleted;

	SET NOCOUNT OFF;
END