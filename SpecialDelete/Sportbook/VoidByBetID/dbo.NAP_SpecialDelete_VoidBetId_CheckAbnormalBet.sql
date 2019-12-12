/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidBetId_CheckAbnormalBet] @MatchId BIGINT
	,@TransIds VARCHAR(MAX) = NULL
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
	
	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT bettype
	FROM dbo.SportBettypeMatrix WITH (NOLOCK)
	WHERE ProductID = 1 -- Sportsbook
		AND bettype NOT IN (10, 9, 29) -- outright, parlay
		AND SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

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
				SELECT ',' + CAST(v.transid AS VARCHAR(100))
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
END