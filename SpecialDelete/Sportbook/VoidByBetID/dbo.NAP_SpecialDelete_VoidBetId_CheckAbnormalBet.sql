/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidBetId_CheckAbnormalBet] 
	 @MatchId	BIGINT
	,@TransIds	VARCHAR(MAX) = ''
AS
/*  
	Created by: 20190625@Raymond.Le  
	Task: Validate matchId, betId of Abnormal bet
	DB: DBTXN/bodb02   
	Original:      

	Revisions:  
		- 20190625@Raymond.Le: Create new SP [Redmine: #115583]
		- 20190730@Raymond.Le: Incorporate BetBuilder [Redmine: #106898] 
		- 20210705@July: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220818@July: Change of Void By Bet ID regarding to Scale out DBTrans [Redmine: #176811]
		- 20230427@July: Support sport Cricket for Void by betid [Redmine: #187052]

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
		   ,@MovebetDate DATETIME
		   ,@MatchDate DATETIME
		   ,@SportType TINYINT
		   ,@ChildMatchType TINYINT
		   ,@ParentID INT
		   ,@SiteDBGroupID SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	DECLARE @tmpTransIdMoveBet TABLE (Transid BIGINT)

	SELECT @MatchDate = eventdate, @SportType = sporttype, @ChildMatchType = ChildMatchType, @ParentID = matchid
	FROM dbo.match WITH(NOLOCK)
	WHERE matchid = @MatchId

	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDate OUTPUT

	-- check valid match id
	IF NOT EXISTS (
			SELECT TOP 1 1
			FROM dbo.SportBettypeMatrix WITH (NOLOCK)
			WHERE ProductID = 1 AND SportType = @SportType
		)
	OR ( @SportType = 50 AND @ChildMatchType = 200)
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
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	-- select valid TransId of Abnormal bet
	INSERT INTO #validTransId (
		transid
		,isInMatch
		)
	SELECT b.transid
		,CASE WHEN @SportType <> 50 AND b.matchid = @MatchId THEN 1
			  WHEN @SportType = 50 AND @ParentID = @MatchId THEN 1
			ELSE 0
			END
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN #transIdTemp TEMP ON b.transid = TEMP.transid
	WHERE b.bettype < 19001
		AND b.bettype NOT IN (9, 29, 2799) -- Parlay Tickets
		AND b.bettype NOT IN (10) -- outright tickets
		AND b.bettype NOT IN (1231, 1232, 1233, 1237, 1238) -- virtual sport
		AND b.bettype NOT IN (31, 32, 33, 71, 72, 73) -- NOT IN [Racing, Casino]
		AND b.bettype NOT BETWEEN 801 AND 806 -- MG
		AND b.bettype NOT BETWEEN 1501 AND 1599 -- NOT IN Keno
		AND b.bettype NOT IN (38) -- Bet Builder
		AND b.statusID NOT IN (101, 102)
		AND b.SiteDBGroupID = @SiteDBGroupID
	
	IF @MatchDate <= @MovebetDate
	BEGIN
		DELETE 
		FROM #validTransId
			OUTPUT	DELETED.TransId
			INTO @tmpTransIdMoveBet (TransId)
		WHERE  isInMatch = 1
	END
		
	-- invalid transId
	;WITH t_invalid
	AS (
		SELECT transid
			,ISNULL(bm.isMoved, CAST(0 AS BIT)) AS isMoved
		FROM #transIdTemp AS TEMP
			OUTER APPLY (
				SELECT TOP 1 CAST(1 AS BIT) AS isMoved
				FROM dbo.bettrans14 WITH (NOLOCK)
				WHERE transid = TEMP.transid AND SiteDBGroupID = @SiteDBGroupID
				UNION ALL
				SELECT TOP 1 CAST(1 AS BIT) AS isMoved
				FROM @tmpTransIdMoveBet m  
				WHERE m.transid = TEMP.transid
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