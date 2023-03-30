/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_CheckVoidBetPermission] 
	 @TransInfoJson						VARCHAR(MAX) = NULL
	,@IsCashOutAsUnSettledTicket		BIT = 0
	,@MatchId							INT = NULL
	,@IsHostVoidSettledTickets			BIT = 0
	,@IsHostVoidInstantlySettledTickets BIT = 0
	,@IsHostVoidUnsettledTickets		BIT = 0
	,@IsCheckForTVS						BIT = 0
	,@ErrCode							INT = 0 OUTPUT
	,@ErrMsg							NVARCHAR(200) = '' OUTPUT
AS
/*  
	Created by: 20221124@Max
	Task: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20221124@Max: Create new SP [Redmine: #180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]

	Param's Explanation:
		+ @MatchId: 0 - For TVS with issuetype is abnormal account
		+ @IsCashOutAsUnSettledTicket : 0 - Consider Cash out as Settled ticket, need settled permission in order to void
										1 - Consider Cash out as un-settled ticket, no need settled permission
										
		+ @IsCheckForTVS: 0 - Special Delete, 1 - TVS ( show different message)
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @IsExistsSettledSingleTickets BIT = 0
			,@IsExistsSettledParlayTickets BIT = 0
			,@IsExistsSettledTickets BIT = 0
			,@IsExistsInstantlySettledTickets BIT = 0
			,@IsExistsSettledCashOutTickets BIT = 0
			,@IsExistsSettledCancelCashOutTickets BIT = 0

	DECLARE @TransIdTemp TABLE (transid BIGINT PRIMARY KEY)

	CREATE TABLE #InstantSettlementBettypes (bettype SMALLINT)
	CREATE CLUSTERED INDEX IDX_InstantSettlementBettypes_bettype ON #InstantSettlementBettypes (bettype)
	CREATE TABLE #tmpTransInfo(
	     matchid INT
		,transid BIGINT
		,Subtransid BIGINT
		,bettype SMALLINT
		,betdaqid BIGINT
		,statusID TINYINT
		,SubstatusID TINYINT
		,IsMixParlay BIT
		,IsMoved14 BIT
		,SiteDBGroupID SMALLINT
		,IsCancelCashOut BIT
		,statuswinlost TINYINT
	)

	INSERT INTO #tmpTransInfo( 
		 matchid 
		,transid
		,Subtransid 
		,bettype 
		,betdaqid 
		,statusID 
		,SubstatusID 
		,IsMixParlay 
		,IsMoved14 
		,SiteDBGroupID
		,IsCancelCashOut
		,statuswinlost
		)
	SELECT mid, t, s_t, btype, bdaq, sid, s_sid, isP, isM, sitedb, isCCO, statuswl
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid, t, s_t, btype, bdaq, sid, s_sid, isP, isM, sitedb, isCCO, statuswl
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, s_t BIGINT, btype SMALLINT, bdaq BIGINT, sid TINYINT, s_sid  TINYINT, isP BIT, isM BIT, sitedb SMALLINT, isCCO BIT, statuswl TINYINT)
		) tbl
	WHERE f.value <> ''

	-- Instant Settlement declaration
	DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
	DECLARE @IsHTCal BIT = 0
		,@eventstatus NVARCHAR(50) = ''

	IF @MatchId IS NOT NULL
	BEGIN
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
				FROM dbo.f_TVS_GetInstantBettypes() T
				WHERE T.InstantType IN (1, 3) -- 01, 11
			ELSE
				INSERT INTO #InstantSettlementBettypes (bettype)
				SELECT T.bettype
				FROM dbo.f_TVS_GetInstantBettypes() T
				WHERE T.InstantType IN (2, 3) -- 10, 11			
		END

		-- check Instant, normal settled of single ticket
		;WITH CTE_TransId (
			transid
			,SettledType -- 1: Instant Settlement, 2: Normal Settlement
			)
		AS (
			SELECT b.transid
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
			FROM #tmpTransInfo b
			WHERE ISNULL(b.betdaqid,0) <> -2 AND b.IsMixParlay = 0 AND b.IsMoved14 = 0
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
			SELECT b.transid
				,CASE 
					WHEN b.StatusId IN (111, 112, 113) AND ISNULL(m.eventstatus, '') <> 'completed'
						THEN CASE
								WHEN ISNULL(mr.IsHTCal, 0) = 0
										AND EXISTS (SELECT TOP 1 1
													FROM dbo.f_TVS_GetInstantBettypes() ib
													WHERE ib.InstantType IN (1, 3) AND ib.bettype = b.bettype)
										THEN 1
								WHEN ISNULL(mr.IsHTCal, 0) = 1
										AND EXISTS (SELECT TOP 1 1
													FROM dbo.f_TVS_GetInstantBettypes() ib
													WHERE ib.InstantType IN (2, 3) AND ib.bettype = b.bettype)
										THEN 1
								ELSE 2
							END
					WHEN b.StatusId IN (111, 112, 113) THEN 2
					ELSE 0
				END
			 FROM #tmpTransInfo b
			    LEFT JOIN dbo.match m WITH(NOLOCK) ON m.matchid = b.matchid
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = b.matchid
			WHERE b.matchid NOT IN (9, 29, 2799) AND ISNULL(b.betdaqid,0) <> -2 AND b.IsMoved14 = 0

			UNION ALL -- Apply for ticket void14 
			SELECT b.transid
				,CASE 
					WHEN b.StatusId IN (111, 112, 113) AND ISNULL(m.eventstatus, '') <> 'completed'
						THEN CASE
								WHEN ISNULL(mr.IsHTCal, 0) = 0
										AND EXISTS (SELECT TOP 1 1
													FROM dbo.f_TVS_GetInstantBettypes() ib
													WHERE ib.InstantType IN (1, 3) AND ib.bettype = b.bettype)
										THEN 1
								WHEN ISNULL(mr.IsHTCal, 0) = 1
										AND EXISTS (SELECT TOP 1 1
													FROM dbo.f_TVS_GetInstantBettypes() ib
													WHERE ib.InstantType IN (2, 3) AND ib.bettype = b.bettype)
										THEN 1
								ELSE 2
							END
					WHEN b.StatusId IN (111, 112, 113) THEN 2
					ELSE 0
				END
			  FROM #tmpTransInfo b
				LEFT JOIN dbo.match14 m WITH(NOLOCK) ON m.matchid = b.matchid
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = b.matchid
			WHERE b.matchid NOT IN (9, 29, 2799) AND ISNULL(b.betdaqid,0) <> -2 AND b.IsMoved14 = 1
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

	-- check settled parlay (sub-parlay, main-parlay (bettrans+ bettrans14)
	SELECT @IsExistsSettledParlayTickets = CASE WHEN EXISTS (
												SELECT TOP 1 1
												FROM #tmpTransInfo m
												WHERE m.SubstatusID IN (111, 112, 113) AND m.IsMixParlay = 1 
											) THEN 1
											ELSE 0
											END

	-- check settled ticket cash out (single + ticket 14)
	SET @IsExistsSettledCashOutTickets = (SELECT  TOP 1 1
										  FROM #tmpTransInfo b
										  WHERE b.statusID IN (111, 112, 113) AND b.betdaqid = -2 AND b.IsMixParlay = 0 AND b.IsCancelCashOut = 0
										  )
	
	-- check settled ticket CANCEL cash out (single + ticket 14) -- match settled
	SET @IsExistsSettledCancelCashOutTickets = (SELECT  TOP 1 1
										  FROM #tmpTransInfo b
										  WHERE b.statusID IN (111, 112, 113) AND b.betdaqid = -2 AND b.IsMixParlay = 0 AND b.IsCancelCashOut = 1
												AND b.statuswinlost IS NOT NULL
										  )


	SELECT @IsExistsSettledTickets = CASE WHEN @IsExistsSettledSingleTickets = 1 
											OR @IsExistsSettledParlayTickets = 1
											OR (@IsExistsSettledCashOutTickets = 1 AND @IsCashOutAsUnSettledTicket = 0)
											OR @IsExistsSettledCancelCashOutTickets = 1 THEN 1
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
		IF @IsCheckForTVS = 0 --Special delete
		BEGIN
			SELECT @ErrCode = 1 ,@ErrMsg = 'WARNING! Insufficient permission to void! You are about to back the page and try a new search.'
		END
		ELSE --TVS
		BEGIN
			SELECT @ErrCode = 1 ,@ErrMsg = 'This request will not be voided because you do not have permission to void instantly settled or settled ticket.'
		END
		RETURN
	END

	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #tmpTransInfo
END