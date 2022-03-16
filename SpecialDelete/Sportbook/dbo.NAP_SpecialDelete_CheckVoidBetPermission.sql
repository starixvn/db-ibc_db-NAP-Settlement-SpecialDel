/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_CheckVoidBetPermission] 
	@TransIds VARCHAR(MAX) = NULL
	,@IsCashOutAsUnSettledTicket BIT = 0
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
		- 20201223@Charles: Optimize Voiding Workflow [Redmine: #145719]
		- 20211111@Zane: Permission to void the settled tickets [Redmine: #162646]
		- 20211210@July: Implement New Cash Out Model [Redmine: #165097]
		- 20220303@July: Check permission to void instant settled tickets [Redmine: #168651]

	Param's Explanation:
		+ @MatchId: 0 - For TVS with issuetype is abnormal account
		+ @IsCashOutAsUnSettledTicket : 0 - Consider Cash out as Settled ticket, need settled permission in order to void
										1 - Consider Cash out as un-settled ticket, no need settled permission
										

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @IsExistsSettledSingleTickets BIT = 0
			,@IsExistsSettledParlayTickets BIT = 0
			,@IsExistsSettledTickets BIT = 0
			,@IsExistsInstantlySettledTickets BIT = 0
			,@IsExistsSettledCashOutTickets BIT = 0

	DECLARE @TransIdTemp TABLE (transid BIGINT PRIMARY KEY)

	CREATE TABLE #InstantSettlementBettypes (bettype SMALLINT)
	CREATE CLUSTERED INDEX IDX_InstantSettlementBettypes_bettype ON #InstantSettlementBettypes (bettype)

	-- get list transId (single + sub-parlay)
	INSERT INTO @TransIdTemp (transid)
	SELECT DISTINCT val
	FROM dbo.f_SplitString(@TransIds, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

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
			WHERE b.matchid NOT IN (9, 29, 2799) AND ISNULL(b.betdaqid,0) <> -2
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
	END
	
	IF ISNULL(@MatchId,0) = 0
	BEGIN
	-- check Instant, normal settled of single ticket
		;WITH CTE_TransId (
			transid
			,SettledType -- 1: Instant Settlement, 2: Normal Settlement
			)
		AS (
			SELECT t.transid
				,CASE 
					WHEN b.StatusId IN (111, 112, 113) AND ISNULL(m.eventstatus, '') <> 'completed'
						THEN CASE
								WHEN ISNULL(mr.IsHTCal, 0) = 0
										AND EXISTS (SELECT TOP 1 1
													FROM dbo.f_Set_Instant_GetBettypes() ib
													WHERE ib.InstantType IN (1, 3) AND ib.bettype = b.bettype)
										THEN 1
								WHEN ISNULL(mr.IsHTCal, 0) = 1
										AND EXISTS (SELECT TOP 1 1
													FROM dbo.f_Set_Instant_GetBettypes() ib
													WHERE ib.InstantType IN (2, 3) AND ib.bettype = b.bettype)
										THEN 1
								ELSE 2
							END
					WHEN b.StatusId IN (111, 112, 113) THEN 2
					ELSE 0
				END
			FROM @TransIdTemp AS t
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON t.transid = b.transid
				LEFT JOIN dbo.match m WITH(NOLOCK) ON m.matchid = b.matchid
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = b.matchid
			WHERE b.matchid NOT IN (9, 29, 2799) AND ISNULL(b.betdaqid,0) <> -2

			UNION ALL -- Apply for ticket void14 
			SELECT t.transid
				,CASE 
					WHEN b.StatusId IN (111, 112, 113) AND ISNULL(m.eventstatus, '') <> 'completed'
						THEN CASE
								WHEN ISNULL(mr.IsHTCal, 0) = 0
										AND EXISTS (SELECT TOP 1 1
													FROM dbo.f_Set_Instant_GetBettypes() ib
													WHERE ib.InstantType IN (1, 3) AND ib.bettype = b.bettype)
										THEN 1
								WHEN ISNULL(mr.IsHTCal, 0) = 1
										AND EXISTS (SELECT TOP 1 1
													FROM dbo.f_Set_Instant_GetBettypes() ib
													WHERE ib.InstantType IN (2, 3) AND ib.bettype = b.bettype)
										THEN 1
								ELSE 2
							END
					WHEN b.StatusId IN (111, 112, 113) THEN 2
					ELSE 0
				END
			FROM @TransIdTemp AS t
				INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK) ON t.transid = b.transid
				LEFT JOIN dbo.match14 m WITH(NOLOCK) ON m.matchid = b.matchid
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = b.matchid
			WHERE b.matchid NOT IN (9, 29, 2799) AND ISNULL(b.betdaqid,0) <> -2
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
			-- Apply for ticket main parlay void14 
			WHEN EXISTS (
				SELECT TOP 1 1
				FROM @TransIdTemp AS t
				INNER JOIN dbo.bettrans14 AS m WITH (NOLOCK) ON t.transid = m.transid
				WHERE m.statusID IN (111, 112, 113) AND m.matchid IN (9, 29, 2799)
			) THEN 1
			ELSE 0
			END

	-- check settled ticket cash out
	SELECT @IsExistsSettledCashOutTickets = CASE
												WHEN EXISTS (
														SELECT TOP 1 1
														FROM @TransIdTemp AS t
															INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON t.transid = b.transid
														WHERE b.statusID IN (111, 112, 113) AND b.betdaqid = -2
												) THEN 1
												WHEN EXISTS (
													SELECT TOP 1 1
														FROM @TransIdTemp AS t
															INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK) ON t.transid = b.transid
														WHERE b.statusID IN (111, 112, 113) AND b.betdaqid = -2
												) THEN 1
												ELSE 0
											END
	
	SELECT @IsExistsSettledTickets = CASE WHEN @IsExistsSettledSingleTickets = 1 
											OR @IsExistsSettledParlayTickets = 1
											OR (@IsExistsSettledCashOutTickets = 1 AND @IsCashOutAsUnSettledTicket = 0) THEN 1
										ELSE 0 END

	IF (
			@IsExistsSettledTickets = 1
			AND @IsHostVoidSettledTickets = 0
			)
		OR (
			@IsExistsInstantlySettledTickets = 1
			AND @IsHostVoidInstantlySettledTickets = 0 AND @IsHostVoidSettledTickets = 0
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