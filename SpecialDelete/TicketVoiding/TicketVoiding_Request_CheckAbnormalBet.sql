/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_CheckAbnormalBet] @MatchId BIGINT
	,@TransIds VARCHAR(MAX) = NULL
	,@IsEdit BIT = 0
AS
/*  
	Created by: Raymond.Le  
	Date: 20190625
	Task: Validate matchId, betId of Abnormal bet
	DB: DBTXN/bodb02   
	Original:      

	Revisions:  
		- 20190625@Raymond.Le: Create new SP [Redmine: #115583]
		- 20190730@Raymond.Le: Incorporate BetBuilder [Redmine: #106898] 
		- 20191212@Max: AbnormalBet TVS [Redmine:#123691]
		- 20200213@Charles: Exclude bettypes of early settlement and fast market [Redmine:#127398]
		- 20200216@Max: Abnormal Void Bets Automation [Redmine: #128359]

	Param's Explanation:
		+ @MatchId: MatchId of current @TransIds
		+ @TransIds: Search by TransID
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @InvalidTransIds VARCHAR(MAX) = ''
	,@MovedTransIds VARCHAR(MAX) = ''
	,@DifferentMatchTransIds VARCHAR(MAX) = '' 
	,@InvalidMatchId VARCHAR(200) = '' 

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	DECLARE @tmpEarlyBettypes TABLE(
		bettype SMALLINT PRIMARY KEY
	)
	
	INSERT INTO @tmpEarlyBettypes(bettype)
	SELECT	bettype
	FROM	dbo.f_Set_GetEarlyBettypes()
	
	INSERT INTO @bettype_tmp (bettype)
	SELECT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND NOT EXISTS (SELECT TOP (1) 1 FROM @tmpEarlyBettypes t WHERE pt.bettype = t.bettype) -- Early settlement
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

	-- check valid match id
	IF NOT EXISTS (
			SELECT TOP 1 1
			FROM dbo.match AS m WITH (NOLOCK)
			WHERE m.matchid = @MatchId
				AND EXISTS (
					SELECT TOP 1 1
					FROM dbo.SportBettypeMatrix AS bm WITH (NOLOCK)
						INNER JOIN dbo.Sports AS s WITH (NOLOCK) ON s.SportType = bm.sporttype
					WHERE bm.ProductID = 1
						AND s.SportType = m.sporttype
					)
			)
	BEGIN
		SELECT @InvalidMatchId = @MatchId

		SELECT @InvalidMatchId AS InvalidMatchId
			,@InvalidTransIds AS InvalidTransIds
			,@MovedTransIds AS MovedTransIds
			,@DifferentMatchTransIds AS DifferentMatchTransIds

		RETURN;
	END

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)
	CREATE TABLE #TransidInRequest (TransId BIGINT)

	CREATE TABLE #validTransId (
		transid BIGINT
		,isInMatch BIT
		)

	IF (@TransIds IS NULL
		OR LEN(@TransIds) = 0
			) RETURN;

	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT val
	FROM dbo.f_SplitString(@TransIds, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

	IF @IsEdit = 1
	BEGIN
		INSERT INTO #TransidInRequest (TransId)
		SELECT tmp.transid
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
			CROSS APPLY (SELECT val AS transid
						 FROM dbo.f_SplitString(rd.TransIds, ',')
						) AS tmp
		WHERE req.IssueTypeId = 11 AND rd.MatchId = @MatchId
		OPTION (maxrecursion 0)

	
		SELECT @InvalidTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM #transIdTemp t 
											INNER JOIN #TransidInRequest tr ON t.transid = tr.TransId
										FOR XML PATH('')
								), 1, 1, ''), '')

		IF @InvalidTransIds <> ''
		BEGIN
			SELECT @InvalidMatchId AS InvalidMatchId
				,@InvalidTransIds AS InvalidTransIds
				,@MovedTransIds AS MovedTransIds
				,@DifferentMatchTransIds AS DifferentMatchTransIds

			RETURN;
		END
	END

	-- select valid TransId of Abnormal bet
	INSERT INTO #validTransId (
		transid
		,isInMatch
		)
	SELECT b.transid
		,CASE 
			WHEN b.matchid = @MatchId THEN 1
			ELSE 0
			END
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN #transIdTemp tmp ON b.transid = tmp.transid
	WHERE b.statusID NOT IN (101, 102) AND EXISTS (SELECT TOP 1 1 FROM @bettype_tmp bt WHERE bt.bettype = b.bettype)
		
	-- invalid transId
	;WITH t_invalid
	AS (
		SELECT transid
			,ISNULL(bm.isMoved, CAST(0 AS BIT)) AS isMoved
		FROM #transIdTemp AS TEMP
			OUTER APPLY (
			SELECT TOP 1 CAST(1 AS BIT) AS isMoved
			FROM dbo.bettrans14 WITH (NOLOCK)
			WHERE transid = TEMP.transid
			) bm
		WHERE NOT EXISTS (
				SELECT 1
				FROM #validTransId
				WHERE transid = TEMP.transid
				)
		)
	SELECT @InvalidTransIds = @InvalidTransIds + CASE 
			WHEN isMoved = 0 THEN CASE 
					WHEN @InvalidTransIds <> '' THEN ','
					ELSE ''
					END + CAST(transid AS VARCHAR(100))
			ELSE ''
			END
		,@MovedTransIds = @MovedTransIds + CASE 
			WHEN isMoved = 1 THEN CASE 
					WHEN @MovedTransIds <> '' THEN ','
					ELSE ''
					END + CAST(transid AS VARCHAR(100))
			ELSE ''
			END
	FROM t_invalid

	SELECT @DifferentMatchTransIds = ISNULL(STUFF((
				SELECT ',' + CAST(v.transid AS VARCHAR(50))
				FROM #validTransId AS v
				WHERE v.isInMatch = 0
				FOR XML PATH('')
				), 1, 1, ''), '')

	-- return table result
	SELECT @InvalidMatchId AS InvalidMatchId
			,@InvalidTransIds AS InvalidTransIds
			,@MovedTransIds AS MovedTransIds
			,@DifferentMatchTransIds AS DifferentMatchTransIds

	DROP TABLE #transIdTemp
	DROP TABLE #validTransId
	DROP TABLE #TransidInRequest
END