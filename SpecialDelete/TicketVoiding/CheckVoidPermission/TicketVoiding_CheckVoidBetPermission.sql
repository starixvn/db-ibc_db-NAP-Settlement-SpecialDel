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
		- 20230417@July: Update "Void" Permission of TVS [Redmine: #186659]
		- 20230606@July: Void permission - Add bet types of SABA Time Machine to Instant Settle list [Redmine: #188454]
	    - 20230822@July: [TVS] Instant Settlement of Basketball [Redmine: #185492]

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
			,@IsExistsInstantlySettledSABATickets BIT = 0

	DECLARE @SupportInstantSettleSABABettype  TABLE (bettype SMALLINT);

	INSERT INTO @SupportInstantSettleSABABettype (bettype)
	VALUES (228) --SABA OU Time Machine
		 , (229) --SABA HDP Time Machine

	CREATE TABLE #InstantSettlementBettypes (matchid INT, bettype SMALLINT, betid BIGINT)
	CREATE TABLE #tmpTransIdSettledType (
		TransId		BIGINT
	  , SettledType TINYINT -- 1: Instant Settlement, 2: Normal Settlement, 3: SABA Time Machine Settlement
	)

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
		,betid BIGINT
		,eventstatus NVARCHAR(50)
		,sporttype SMALLINT
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
		,betid
		)
	SELECT mid, t, s_t, btype, bdaq, sid, s_sid, isP, isM, sitedb, isCCO, statuswl, bid
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid, t, s_t, btype, bdaq, sid, s_sid, isP, isM, sitedb, isCCO, statuswl, bid
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, s_t BIGINT, btype SMALLINT, bdaq BIGINT, sid TINYINT, s_sid  TINYINT, isP BIT, isM BIT, sitedb SMALLINT, isCCO BIT, statuswl TINYINT, bid BIGINT)
		) tbl
	WHERE f.value <> ''

	-- Instant Settlement declaration
	DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
	CREATE TABLE #CTE_match (matchid INT, sporttype SMALLINT, eventstatus NVARCHAR(50))
	CREATE TABLE #CTE_isCal (matchid INT, IsHTCal BIT, ResourceId VARCHAR(20))

	IF @MatchId IS NOT NULL
	BEGIN
		INSERT INTO #CTE_match (matchid, sporttype, eventstatus)
		SELECT m.matchid, m.sporttype, m.eventstatus
		FROM dbo.match m WITH(NOLOCK) 
		WHERE matchid = @MatchId AND m.eventstatus <> @eventstatus_completed

	END
	IF ISNULL(@MatchId,0) = 0
	BEGIN
		INSERT INTO #CTE_match (matchid, sporttype, eventstatus)
		SELECT b.matchid, m.sporttype, m.eventstatus
		FROM #tmpTransInfo b
			CROSS APPLY( 
					SELECT m.sporttype, m.eventstatus
					FROM dbo.match m WITH(NOLOCK) 
					WHERE b.matchid = m.matchid AND m.eventstatus <> @eventstatus_completed
					UNION
					SELECT m14.sporttype, m14.eventstatus
					FROM dbo.match14 m14 WITH(NOLOCK) 
					WHERE b.matchid = m14.matchid AND m14.eventstatus <> @eventstatus_completed
			)m
	END	
	
	IF EXISTS (SELECT TOP 1 1 FROM #CTE_match WHERE sporttype = 1) --Soccer	 
	BEGIN
		INSERT INTO #CTE_isCal (matchid, IsHTCal)
		SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
		FROM #CTE_match m
			LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = m.matchid
		WHERE m.sporttype = 1

		INSERT INTO #InstantSettlementBettypes (matchid, bettype)
		SELECT c.matchid,  f.bettype
		FROM #CTE_isCal c
			CROSS APPLY (
					SELECT bettype
					FROM dbo.f_TVS_GetInstantBettypes() 
					WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
								   WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
							ELSE 0 END
			)f	
	END
	IF EXISTS (SELECT TOP 1 1 FROM #CTE_match WHERE sporttype = 2) --Basketball
	BEGIN
		INSERT INTO #CTE_isCal (matchid, ResourceId)
		SELECT m.matchid, rd.ResourceId
		FROM #CTE_match m
			INNER JOIN DBPRO.bodb02.dbo.ResultDetail rd WITH (NOLOCK) ON rd.matchid = m.matchid
		WHERE m.sporttype = 2
			AND ResultStatusID in (2,5)
			AND (ResourceId LIKE 'Q[1-4]' OR ResourceId IN ('01','OT')) 

		INSERT INTO #InstantSettlementBettypes (matchid, bettype, betid)
		SELECT DISTINCT c.matchid, f.bettype, f.betid
		FROM #CTE_isCal c
			CROSS APPLY (
					SELECT bettype, betid
					FROM dbo.f_TVS_GetInstantBettypes()
					WHERE InstantType IS NULL
					AND ResourceId NOT IN (SELECT ResourceId FROM #CTE_isCal)
			)f	 	
	END

	UPDATE t
	SET t.eventstatus = m.eventstatus
	   ,t.sporttype = m.sporttype
	FROM #tmpTransInfo t 
		INNER JOIN #CTE_match m ON t.matchid = m.matchid

	INSERT INTO #tmpTransIdSettledType (
		TransId
		,SettledType 
	)
	SELECT b.transid
		,CASE 
			WHEN ISNULL(b.eventstatus, '') <> 'completed'
				THEN CASE
						WHEN b.sporttype = 1 AND EXISTS (
							SELECT TOP 1 1
							FROM #InstantSettlementBettypes AS i
							WHERE b.bettype = i.bettype
							) THEN 1
						WHEN b.sporttype = 2 AND EXISTS (
							SELECT TOP 1 1
							FROM #InstantSettlementBettypes AS i
							WHERE b.bettype = i.bettype AND b.betid = i.betid
							) THEN 1
						WHEN ib.bettype IS NOT NULL THEN 3
						ELSE 2
					END
			WHEN ib.bettype IS NOT NULL THEN 3
			ELSE 2
		END
	FROM #tmpTransInfo b
		LEFT JOIN @SupportInstantSettleSABABettype ib ON b.bettype = ib.bettype
	WHERE b.matchid NOT IN (9, 29, 2799) 
		AND ISNULL(b.betdaqid,0) <> -2
		AND b.statusID IN (111, 112, 113) 

	SELECT @IsExistsInstantlySettledTickets = MAX(CASE WHEN SettledType = 1 THEN 1 ELSE 0 END)
		 , @IsExistsSettledSingleTickets = MAX(CASE WHEN SettledType = 2 THEN 1 ELSE 0 END)
		 , @IsExistsInstantlySettledSABATickets = MAX(CASE WHEN SettledType = 3 THEN 1 ELSE 0 END)
	FROM #tmpTransIdSettledType

	-- check settled parlay (sub-parlay, main-parlay (bettrans+ bettrans14)
	SET @IsExistsSettledParlayTickets = (SELECT TOP 1 1
										 FROM #tmpTransInfo m
										 WHERE m.SubstatusID IN (111, 112, 113) AND m.IsMixParlay = 1 
										)

	-- check settled ticket cash out & CANCEL cash out (single + ticket 14)
	SELECT  @IsExistsSettledCashOutTickets	     = MAX(CASE WHEN b.IsCancelCashOut = 0 THEN 1 ELSE 0 END)
		   ,@IsExistsSettledCancelCashOutTickets = MAX(CASE WHEN b.IsCancelCashOut = 1 AND b.statuswinlost IS NOT NULL THEN 1 ELSE 0 END) 
	FROM #tmpTransInfo b
	WHERE b.statusID IN (111, 112, 113) 
		AND b.betdaqid = -2 
		AND b.IsMixParlay = 0


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
		OR (
			@IsExistsInstantlySettledSABATickets = 1 AND @IsExistsSettledTickets = 1
			AND @IsHostVoidInstantlySettledTickets = 1 
			AND @IsHostVoidSettledTickets = 0
			)
	BEGIN
		IF @IsCheckForTVS = 0 --Special delete
		BEGIN
			SELECT @ErrCode = 1 ,@ErrMsg = 'WARNING! Insufficient permission to void! You are about to back the page and try a new search.'
		END
		ELSE --TVS
		BEGIN
			SELECT @ErrCode = 1 ,@ErrMsg = 'You do not have enough permission to void/cancel cash out tickets of this request.'
		END
		RETURN
	END

	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #tmpTransInfo
	DROP TABLE #tmpTransIdSettledType
	DROP TABLE #CTE_match
	DROP TABLE #CTE_isCal
END