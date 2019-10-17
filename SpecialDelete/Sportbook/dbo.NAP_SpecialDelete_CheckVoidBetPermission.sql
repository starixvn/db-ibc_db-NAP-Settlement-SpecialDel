/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_CheckVoidBetPermission] @TransIds VARCHAR(MAX) = NULL
	,@CashOutTransIds VARCHAR(MAX) = NULL
	,@MatchId INT = NULL
	,@IsHostVoidSettledTickets BIT = 0
	,@IsHostVoidInstantlySettledTickets BIT = 0
	,@IsHostVoidUnsettledTickets BIT = 0
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*  
	Created by: Raymond.Le  
	Date: 20190723
	Task: Check if user has permission to void bet in TransIds list
	DB: DBTXN/bodb02   
	Original:      

	Revisions:  
		- 20190723@Raymond.Le: Create new SP [Redmine: #117343]

	Param's Explanation:
		+ @CashOutTransIds: List id of cash out sub-ticket (911)

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @IsExistsSettledSingleTickets BIT = 0
			,@IsExistsSettledParlayTickets BIT = 0
			,@IsExistsSettledTickets BIT = 0
			,@IsExistsInstantlySettledTickets BIT = 0
			,@IsExistsSettledCashOutTickets BIT = 0

	DECLARE @TransIdTemp TABLE (transid BIGINT PRIMARY KEY)
	DECLARE @CashOutTransIdTemp TABLE (transid BIGINT PRIMARY KEY) 

	CREATE TABLE #InstantSettlementBettypes (bettype SMALLINT)
	CREATE CLUSTERED INDEX IDX_InstantSettlementBettypes_bettype ON #InstantSettlementBettypes (bettype)

	-- get list transId (single + sub-parlay)
	INSERT INTO @TransIdTemp (transid)
	SELECT DISTINCT val
	FROM dbo.f_SplitString(@TransIds, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

	-- get list cash out sub-ticket (911)
	INSERT INTO @CashOutTransIdTemp (transid)
	SELECT DISTINCT val
	FROM dbo.f_SplitString(@CashOutTransIds, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

	-- If MatchId has value => this function has instantly settled ticket
	IF @MatchId IS NOT NULL 
	BEGIN
		-- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
		DECLARE @IsHTCal BIT = 0
			,@eventstatus NVARCHAR(50) = ''

		--> Get status of match
		SELECT @IsHTCal = ISNULL(IsHTCal, 0)
		FROM match_remark(NOLOCK)
		WHERE matchid = @MatchId

		SELECT @eventstatus = ISNULL(eventstatus, '')
		FROM match(NOLOCK)
		WHERE matchid = @MatchId

		--> Build bettype list supported for instant settlement based on settlement status of match
		IF @eventstatus <> @eventstatus_completed
		BEGIN
			IF @IsHTCal = 0
				INSERT INTO #InstantSettlementBettypes (bettype)
				SELECT T.bettype
				FROM dbo.f_Set_Instant_GetBettypes() T
				WHERE T.InstantType IN (1, 3) -- 01, 11
			ELSE
				INSERT INTO #InstantSettlementBettypes (bettype)
				SELECT T.bettype
				FROM dbo.f_Set_Instant_GetBettypes() T
				WHERE T.InstantType IN (2, 3) -- 10, 11			
		END
	END

	----------	
	-- check Instant, normal settled of single ticket
	;WITH CTE_TransId (
		transid
		,SettledType -- 1: Instant Settlement, 2: Normal Settlement
		)
	AS (
		SELECT t.transid
			,CASE 
				WHEN b.StatusId IN (111, 112, 113)
					AND EXISTS (
						SELECT TOP 1 1
						FROM #InstantSettlementBettypes AS i
						WHERE b.bettype = i.bettype
						) THEN 1
				WHEN b.StatusId IN (111, 112, 113) THEN 2
				ELSE 0
				END
		FROM @TransIdTemp AS t
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON t.transid = b.transid
		WHERE b.matchid NOT IN (9, 29, 2799)
		)
	SELECT @IsExistsInstantlySettledTickets = CASE 
			WHEN EXISTS (
					SELECT TOP 1 1
					FROM CTE_TransId
					WHERE SettledType = 1
					) THEN 1
			ELSE 0
			END
		,@IsExistsSettledSingleTickets = CASE 
			WHEN EXISTS (
					SELECT TOP 1 1
					FROM CTE_TransId
					WHERE SettledType = 2
					) THEN 1
			ELSE 0
			END

	-- check settled parlay
	SELECT @IsExistsSettledParlayTickets = CASE
			WHEN EXISTS (
				SELECT TOP 1 1
				FROM @TransIdTemp AS t
				INNER JOIN dbo.bettransm AS m WITH (NOLOCK) ON t.transid = m.transid
				WHERE m.statusID IN (111, 112, 113)
			) THEN 1
			WHEN EXISTS (
				SELECT TOP 1 1
				FROM @TransIdTemp AS t
				INNER JOIN dbo.bettrans AS m WITH (NOLOCK) ON t.transid = m.transid
				WHERE m.statusID IN (111, 112, 113) AND m.matchid IN (9, 29, 2799)
			) THEN 1
			ELSE 0
			END

	-- check settled main cash out
	IF (@CashOutTransIds IS NOT NULL)
	BEGIN
		SELECT @IsExistsSettledCashOutTickets = CASE
				WHEN EXISTS (
						SELECT TOP 1 1
						FROM @CashOutTransIdTemp AS t
						INNER JOIN dbo.bettrans AS sub WITH (NOLOCK) ON t.transid = sub.transid
						INNER JOIN dbo.bettrans AS main WITH (NOLOCK) ON sub.refno = main.transid
						WHERE sub.bettype = 911
						AND main.statusID IN (111, 112, 113)
				) THEN 1
				ELSE 0
				END
	END
	
	SELECT @IsExistsSettledTickets = CASE WHEN @IsExistsSettledSingleTickets = 1 
											OR @IsExistsSettledParlayTickets = 1
											OR @IsExistsSettledCashOutTickets = 1 THEN 1
										ELSE 0 END

	IF (
			@IsExistsSettledTickets = 1
			AND @IsHostVoidSettledTickets = 0
			)
		OR (
			@IsExistsInstantlySettledTickets = 1
			AND @IsHostVoidInstantlySettledTickets = 0
			)
		OR (
			@IsHostVoidUnsettledTickets = 0
			AND @IsHostVoidSettledTickets = 0
			AND @IsHostVoidInstantlySettledTickets = 0
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'WARNING! Insufficient permission to void! You are about to back the page and try a new search.'

		RETURN
	END

	DROP TABLE #InstantSettlementBettypes
END