/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Validation_Ticket
(
	 @matchid		INT = 0
	,@matchids		VARCHAR(500) = ''
	,@DestinationMatchId	INT = 0
	,@Action		VARCHAR(10)
	,@Mode			VARCHAR(10)
	,@IsAuto		BIT = 0
	,@ResourceResult VARCHAR(MAX)	= NULL		--AutoPayout_Push
	,@SPName		 VARCHAR(255)
	,@SelectedResources	VARCHAR(MAX) = NULL
	,@InstantKey	INT = NULL					--NAP_Admin_Settlement_1_InstantCalculation_Push
	,@SettleAbandonedMatchIBCParlay TINYINT	= 0 --NAP_Admin_Settlement_Refund_MP_Push

	,@HalfTimeHome  INT = NULL
    ,@HalfTimeAway  INT = NULL
    ,@FullTimeHome  INT = NULL
    ,@FullTimeAway  INT = NULL
	,@SDTRecord		TINYINT	= 0					--NAP_Admin_Settlement_Refund_1_Push

	,@ErrCode		INT		= 0     OUTPUT
	,@ErrMsg		NVARCHAR(300)  = ''   OUTPUT
	,@MatchIdsOutPut VARCHAR(500) = '' OUTPUT	--for settle parlay - multiple match 
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation before settle  [Redmine:#175251]

	Param's Explanation:
		This SP is called after pass [NAP_Admin_Settlement_Validation_Event]

		@Action: CAL, CAL-HT, CAL-FT
				, REFUND, REFUND-HT, REFUND-FT, REFUND-EAR,CAL-FM
				,BetFair, BetDaq ( for Move Betdaq/betfair )

		@Mode: ALL, HT, FT, EAR, INST-HT, INST-FT, INST-UNDO, FM, MP

*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @SportType			SMALLINT
			,@LeagueGroupID		INT
			,@matchcode			NVARCHAR(50)
			,@ParentId			INT
			,@finalhomescore	INT
			,@finalawayscore	INT
			,@WaitingTime		VARCHAR(10)
			,@IsWaiting			BIT = 0
			,@IsSettleByProfile	BIT = 0
			,@IsEarly			BIT = 0
			,@IsCheckHoldEarly	BIT = 0
			,@IsMergedParlay	BIT = 0
			,@xmlResourceResult		XML
			,@xmlData			 VARCHAR(MAX)
			,@currentdate		 DATETIME
			,@IsCentral			 BIT = 0

	DECLARE  @Inst_HomeScore		INT
			,@Inst_AwayScore		INT
			,@IsSettleAbandonedMatchIBC BIT --Refund DTM Soccer
			,@IsAutoRefund			BIT = 0 
			,@IsWaitingTicket		BIT = 0
			,@InvalidMatchIds		VARCHAR(200)
			,@HaveWaitingTicket		VARCHAR(200)
			,@MovingMatchIds		VARCHAR(200)
			,@totalSingle			INT 
			,@totalParlay			INT
			,@sqlRemoteQuery		NVARCHAR(MAX)

	SELECT @sporttype = m.sporttype
			,@LeagueGroupID		= l.LeagueGroupID
			,@matchcode		   	= m.matchcode
			,@ParentId			= m.ParentID
			,@finalhomescore	= m.finalhomescore
			,@finalawayscore	= m.finalawayscore
			,@IsSettleAbandonedMatchIBC = CASE WHEN @SDTRecord & 4 > 0 THEN 1 ELSE 0 END
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE m.matchid = @matchid
		AND ISNULL(@matchid,0) > 0
	
	SELECT @IsMergedParlay = s.IsMergedParlay
			,@IsSettleByProfile = s.IsSettleByProfile
	FROM SettlementResultTableSetting s WITH(NOLOCK) --table contains sportbook only
	WHERE s.Sporttype = @SportType

	SELECT @IsEarly =  CASE WHEN @Mode LIKE '%EAR' THEN 1 ELSE 0 END
			,@IsAutoRefund	=  CASE WHEN @Action = 'REFUND' AND @IsAuto = 1 THEN 1
									ELSE 0 END
	
	SELECT @IsCheckHoldEarly =  CASE WHEN @Action LIKE '%EAR'  OR (@sportType = 50 AND @IsAuto = 1) THEN 1 ELSE 0 END

	SET @currentdate = CURRENT_TIMESTAMP

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	SET @xmlResourceResult = CAST(@ResourceResult AS XML)

	-----------------------------------------------------
	IF @Action = 'MoveTicket' AND @Mode = '43'
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_MoveTicketChecking_Ticket
			 @MatchId			 = @MatchId
			,@DestinationMatchId = @DestinationMatchId
			,@ErrCode			 = @ErrCode OUTPUT
			,@ErrMsg			 = @ErrMsg OUTPUT

		RETURN
	END

	--check ticket central and site at CentralDB
	IF @Action = 'MoveTicket' AND @Mode = '50' AND @IsCentral = 1
	BEGIN

		DECLARE @tmpResourceId50 TABLE (ResourceId VARCHAR(20))
		DECLARE @tmpBettypeResourceId50 TABLE (Bettype SMALLINT, BetId BIGINT, ResourceId VARCHAR(20) )

		SET @sqlRemoteQuery = ' SELECT	ResourceID 
							FROM DBPRO.bodb02.dbo.ResultDetailOS WITH(NOLOCK)
							WHERE	matchid = ' + CAST (@MatchId AS VARCHAR) + '
									AND ResultStatusID = 5'

		INSERT INTO @tmpResourceId50(ResourceId)
		EXECUTE sys.sp_executesql @sqlRemoteQuery

		INSERT INTO @tmpBettypeResourceId50(Bettype, BetId, ResourceId)
		SELECT	s.BetType, s.BetID, t.ResourceID
		FROM	@tmpResourceId50 t
			CROSS APPLY (
				SELECT	s.BetType, s.BetID
				FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
				WHERE	s.SportType = 50
						AND (s.ResourceID = t.ResourceId
							OR s.RefResourceId = t.ResourceId)
			)s
		
		IF NOT EXISTS ( SELECT TOP 1 1	FROM dbo.bettrans b WITH(NOLOCK)
							CROSS APPLY (	SELECT TOP 1 t.Bettype, t.BetId, t.ResourceId
											FROM	@tmpBettypeResourceId50 t
											WHERE	t.Bettype = b.bettype
													AND (t.BetId = 0 OR t.BetId = b.betid)
													--AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
										)t				
						WHERE	b.matchid = @MatchId
					)
			AND
			NOT EXISTS ( SELECT	TOP 1 1	FROM	dbo.bettransm bm WITH(NOLOCK)
							CROSS APPLY (	SELECT TOP 1 t.Bettype, t.BetId, t.ResourceId
											FROM	@tmpBettypeResourceId50 t
											WHERE	t.Bettype = bm.bettype
													AND (t.BetId = 0 OR CAST(t.Betid AS NVARCHAR(50)) = bm.betcheck)
													--AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
										)t				
						WHERE	bm.matchid = @MatchId
					)
		BEGIN
			SELECT	@ErrCode = 1001049
					,@ErrMsg = 'WARNING! Cannot continue due to current has no valid ticket to move.'		
			RETURN
		END
		

		RETURN
	END
	-----------------------------------------------------
	-- Check SP settle is in deployment progress
	EXEC dbo.NAP_Set_SPDeploymentInfo 
		@SPName = @SPName
		,@WaitingTime = @WaitingTime OUTPUT
		,@IsWaiting = @IsWaiting OUTPUT
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	IF @IsWaiting = 1
	BEGIN
		WAITFOR DELAY @WaitingTime
		RETURN
	END

	IF @IsAutoRefund = 1
	BEGIN
		EXEC NAP_Set_AutoRefund_MatchChecking_Ticket
			@MatchId		= @matchid
			,@sporttype		= @SportType
			,@ResourceIds	= @SelectedResources
			,@ErrCode 		= @ErrCode OUTPUT
			,@ErrMsg 		= @ErrMsg OUTPUT

		IF ISNULL(@ErrCode, 0) > 0
		RETURN
	END

	--Check MoveBet date ( apply all sportbook)
	IF @Mode NOT LIKE '%INST%'
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_CheckingMoveBetDay
			@MatchIds		 = @MatchId 
			,@MovingMatchIds = @InvalidMatchIds OUTPUT
			,@ErrCode		 = @ErrCode OUTPUT
			,@ErrMsg		 = @ErrMsg OUTPUT

		IF @ErrCode <> 0 AND @SPName <> 'NAP_Admin_Settlement_Refund_MP_Push'
		BEGIN
			SELECT @ErrCode = @ErrCode
					,@ErrMsg = 'Cannot proceed due to this match is in during move-bet progress. Please contact admin for support.'
			RETURN
		END
	END
		
	--Start: Check is match in Queue
	IF EXISTS (SELECT TOP 1 1
				FROM dbo.Single_Calculate_Queue s WITH (NOLOCK)
					OUTER APPLY (	SELECT TOP 1 f.GroupAction
									FROM dbo.f_Set_GetAction() f
									WHERE s.Action = f.Action
										AND f.GroupAction = CASE WHEN @Mode IN ( 'EAR', 'MP') THEN @Mode
																	ELSE 'MNL' END
								) f
				WHERE s.matchid = @matchid
					AND s.IsCalculating IN (0, 1)
					AND 1 = CASE WHEN @Action IN ( 'BetFair', 'BetDaq' ) THEN 1
								 WHEN @SportType = 1 THEN CASE WHEN f.GroupAction IS NOT NULL THEN 1
															ELSE 0 END
								 ELSE 1 END
				)
	BEGIN
		SELECT @ErrCode = 1001003
			, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END

	IF ( @IsMergedParlay = 0 
			OR @Mode = 'INST'
			OR @Action IN ('BetFair', 'BetDaq')
		)

	BEGIN
		IF EXISTS (	SELECT TOP 1 1
					FROM dbo.Parlay_Calculate_Queue WITH (NOLOCK)
					WHERE matchid = @matchid
						AND IsCalculating IN (0, 1)
					)
		BEGIN
			SELECT @ErrCode = 1001003
				, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
			RETURN
		END
	END
	--End: Check is match in Queue

	IF @IsSettleByProfile = 1 AND @SelectedResources IS NOT NULL
	BEGIN
		SET @xmlData = @SelectedResources
	END

	-- check waiting ticket for calculate cal-ht/ft/call/early,  all undo
	IF NOT EXISTS ( SELECT TOP 1 1 WHERE @Action IN ( 'CAL', 'REFUND' ) AND @Mode IN ( 'INST') )
		AND @SPName <> 'NAP_Admin_Settlement_Refund_MP_Push'
	BEGIN
		IF (  @SportType = 1  
				AND @Action IN ( 'CAL', 'CAL-HT', 'CAL-FT') 
				AND @SelectedResources IS NULL
			)
		BEGIN
			;WITH cteGoalResource
			AS
			(
				SELECT  T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
				FROM    @xmlResourceResult.nodes('/Results/Resource') AS T(C)
			)
			,cteResource
			AS
			(
				SELECT	CAST('01' AS VARCHAR(20)) AS ResourceID
				WHERE	@action IN ('CAL', 'CAL-HT', 'UNDO')
				UNION ALL
				SELECT 	CAST('00' AS VARCHAR(20)) AS ResourceID
				WHERE	@action IN ('CAL', 'CAL-FT', 'UNDO')
				UNION ALL
				SELECT  ResourceId
				FROM	cteGoalResource
				WHERE   ResourceID IS NOT NULL
			)
			
			SELECT @xmlData = CAST((SELECT	ResourceID AS '@Id'
			FROM	cteResource
			FOR XML PATH ('Resource'), ROOT('Resources'), TYPE) AS VARCHAR(MAX))

		END
		
		EXEC NAP_Admin_Settlement_Checking
			@MatchId  = @MatchId
			,@Action  = @Action
			,@Mode	  = @Mode
			,@xmlData = @xmlData
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg  = @ErrMsg OUTPUT
	
		IF ISNULL(@ErrCode,0) <> 0
		RETURN
	END

	--Start: validation for Instant settle
	IF @Action = 'CAL' AND @Mode LIKE '%INST%'
	BEGIN
		EXEC dbo.NAP_Settlement_InstantCalculation_Checking 
			@MatchId 		= @MatchId
			, @InstantKey	= @InstantKey
			, @Action 		= @Action
			, @Mode			= @Mode
			, @ErrCode 		= @ErrCode OUTPUT
			, @ErrMsg 		= @ErrMsg OUTPUT

		IF ISNULL(@ErrCode,0)>0
		RETURN

	END
	--/ END validation for Instant settle
		

	--Start: Validation for Refund Single
	IF @Action = 'REFUND-FT' AND @Mode <> 'MP' AND EXISTS ( SELECT TOP 1 1
				FROM	dbo.bettrans b WITH(NOLOCK)
					CROSS APPLY ( SELECT TOP 1 b.bettype
									FROM dbo.f_Set_GetGroupBettypes() f
									WHERE b.bettype = f.BetType
									AND f.GroupId IN (1,3)
								) f
				WHERE	b.matchid = @MatchId
						AND b.statusID = 0
						AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
			)
		BEGIN
			SELECT	@ErrCode = 1001031
					,@ErrMsg = 'Error! Cannot proceed due to running Half Time tickets. Please proceed with Half Time settlement and try again.'
			RETURN
		END
	--/End: Validation for Refund Single

	--Start: Validation for Refund Parlay
	IF @Action LIKE 'REFUND%' AND @Mode = 'MP'
	BEGIN
		SET @MovingMatchIds		= ''
		SET @HaveWaitingTicket  = ''

		SELECT	@MovingMatchIds = COALESCE(@MovingMatchIds + ',' + @matchcode, @matchcode)
		FROM	STRING_SPLIT (@InvalidMatchIds, ',') f
		WHERE	f.[value] = @MatchId

		SELECT @HaveWaitingTicket = 
						(	SELECT TOP 1 @matchcode
							FROM dbo.bettransm bm WITH(NOLOCK)
								INNER JOIN dbo.[f_Set_GetGroupBettypes]() f
									ON bm.bettype = f.BetType
							WHERE bm.matchid = @MatchId
								AND ( 	bm.statusID = 1 -- waiting status
										OR ( bm.statusID = 0 AND bm.SecAcceptFlag = 1 AND ISNULL(bm.checktime, @currentdate) > @currentdate)
									)
								AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
							)

		IF  ISNULL(@HaveWaitingTicket,'') <> '' OR ISNULL(@MovingMatchIds,'') <> '' 
		BEGIN
			SELECT   @ErrCode = 1001011
					,@ErrMsg = 'This match is being calculated, except following matches ' 
								+ CASE WHEN ISNULL(@HaveWaitingTicket, '') <> ''
										THEN ' (existing some PENDING tickets): ' + @HaveWaitingTicket
										ELSE ''
									END
								+ CASE WHEN ISNULL(@MovingMatchIds, '') <> ''
										THEN ' (during move-bet progress): ' + @MovingMatchIds + '. Please contact Starix IT for further support!'
										ELSE ''
									END
			RETURN
		END
		
    END
	--/End: Validation for Refund Single

END
GO