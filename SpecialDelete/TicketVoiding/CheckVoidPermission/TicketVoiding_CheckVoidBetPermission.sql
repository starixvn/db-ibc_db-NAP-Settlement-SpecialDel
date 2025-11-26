/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_CheckVoidBetPermission] 
	 @TransInfoJson						VARCHAR(MAX) = NULL
	,@IsCashOutAsUnSettledTicket		BIT = 0
	,@MatchId							INT = NULL
	,@IsHostVoidSettledTickets			BIT = 0
	,@IsHostVoidInstantlySettledTickets BIT = 0
	,@IsHostVoidUnsettledTickets		BIT = 0
	,@IsHostVoidRealTickets 			BIT = 0
	,@IsHostVoidUusTickets 				BIT = 0
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
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20251008@July: Add new permission for voiding tickets that have UUS currency only [Redmine: #241141]

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
			,@IsExistsRealTickets BIT = 0
			,@IsExistsUusTickets BIT = 0

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
		,currency SMALLINT
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
		,currency
		)
	SELECT mid, t, s_t, btype, bdaq, sid, s_sid, isP, isM, sitedb, isCCO, statuswl, bid, curr
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid, t, s_t, btype, bdaq, sid, s_sid, isP, isM, sitedb, isCCO, statuswl, bid, curr
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, s_t BIGINT, btype SMALLINT, bdaq BIGINT, sid TINYINT, s_sid  TINYINT, isP BIT, isM BIT, sitedb SMALLINT, isCCO BIT, statuswl TINYINT, bid BIGINT, curr SMALLINT)
		) tbl
	WHERE f.value <> ''

	SET @IsExistsRealTickets = (SELECT TOP 1 1 FROM #tmpTransInfo WHERE currency NOT IN (20,72))
	SET @IsExistsUusTickets = (SELECT TOP 1 1 FROM #tmpTransInfo WHERE currency IN (20,72))

	-- Instant Settlement declaration
	DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
	CREATE TABLE #CTE_match (matchid INT, sporttype SMALLINT, eventstatus NVARCHAR(50))

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
	
	DECLARE @MatchIds VARCHAR(MAX)
	SELECT @MatchIds = STRING_AGG(CAST(MatchId AS VARCHAR(MAX)),',')
	FROM #CTE_match

	INSERT INTO #InstantSettlementBettypes (matchid,bettype,betid)
	SELECT matchid, bettype, betid
	FROM dbo.f_TVS_GetInstantSettlementBettypes(@MatchIds);
		
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
							WHERE b.bettype = i.bettype AND (b.betid = i.betid OR b.betid IS NULL)
							) THEN 1
						WHEN ib.bettype IS NOT NULL THEN 3
						ELSE 2
					END
			WHEN ib.bettype IS NOT NULL THEN 3
			ELSE 2
		END
	FROM #tmpTransInfo b
		LEFT JOIN @SupportInstantSettleSABABettype ib ON b.bettype = ib.bettype
	WHERE b.matchid NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) 
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

	IF @IsHostVoidUusTickets = 1 AND @IsExistsRealTickets = 1 
	BEGIN
		SELECT @ErrCode = 1 ,@ErrMsg = 'You do not have enough permission to void/cancel cash out REAL tickets of this request.'
		RETURN
	END
	IF @IsHostVoidRealTickets = 1 AND @IsExistsUusTickets = 1 
	BEGIN
		SELECT @ErrCode = 1 ,@ErrMsg = 'You do not have enough permission to void/cancel cash out UUS tickets of this request.'
		RETURN
	END

	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #tmpTransInfo
	DROP TABLE #tmpTransIdSettledType
	DROP TABLE #CTE_match
END