/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Validation_Ticket
(
	 @matchid		INT = 0
	,@matchids		VARCHAR(500) = ''
	,@Action		VARCHAR(10)
	,@Mode			VARCHAR(10)
	,@IsAuto		BIT = 0
	,@IsAutoRefund	BIT = 0
	,@SPName		VARCHAR(255)
	,@SelectedResources	VARCHAR(MAX) = NULL
	,@InstantKey	INT = NULL --NAP_Admin_Settlement_1_InstantCalculation_Push
	,@SettleAbandonedMatchIBCParlay TINYINT	= 0 --NAP_Admin_Settlement_Refund_MP_Push
	,@SDTRecord		TINYINT	= 0  --NAP_Admin_Settlement_Refund_1_Push
	,@IsSettleDetermined	BIT	= 0 --NAP_Admin_Settlement_Fast_Market_Auto_1s_Push

	,@HalfTimeHome  INT = NULL
    ,@HalfTimeAway  INT = NULL
    ,@FullTimeHome  INT = NULL
    ,@FullTimeAway  INT = NULL

	,@ErrCode		INT		= 0     OUTPUT
	,@ErrMsg		NVARCHAR(300)  = ''    OUTPUT
	,@MatchIdsOutPut VARCHAR(500) = '' OUTPUT --for settle parlay - multiple match 
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

		@Action: CAL, CAL-HT, CAL-FT, CAL_MARKET, REFUND, REFUND-HT, REFUND-FT, REFUND-EAR,CAL-FM
		@Mode: ALL, HT, FT, EAR, INST-HT, INST-FT, INST-UNDO, FM, BB, MP

*/

BEGIN
SET NOCOUNT ON
	
	IF @Mode = 'BB'
		RETURN

	--calculate parlay other sports, single or multiple matches
	IF @Action = 'CAL' AND @Mode = 'MP'
	BEGIN
		EXEC NAP_Admin_Settlement_Validation_MP
			 @matchids		=  @matchids
			,@Action		=  @Action
			,@Mode			=  @Mode
			,@ErrCode		=  @ErrCode OUTPUT
			,@ErrMsg		  = @ErrMsg   OUTPUT
			,@MatchIdsOutPut  = @MatchIdsOutPut OUTPUT

		RETURN
	END

	DECLARE @SportType			SMALLINT
			,@LeagueGroupID		INT
			,@finalhomescore	INT
			,@finalawayscore	INT
			,@WaitingTime		VARCHAR(10)
			,@IsWaiting			BIT = 0
			,@IsSettleByProfile	BIT = 0
			,@IsEarly			BIT = 0
			,@IsCheckHoldEarly	BIT = 0
			,@IsMergedParlay	BIT = 0
			,@xmlResourceResult		XML
			,@xmlData			VARCHAR(MAX)
			,@IsCentral			BIT = 0

	DECLARE  @Inst_HomeScore		INT
			,@Inst_AwayScore		INT
			,@IsSettleAbandonedMatchIBC BIT --Refund DTM Soccer

	SELECT @sporttype = m.sporttype
			,@LeagueGroupID		= lg.GroupID
			,@finalhomescore	= m.finalhomescore
			,@finalawayscore	= m.finalawayscore
			,@IsSettleAbandonedMatchIBC = CASE WHEN @SDTRecord & 4 > 0 THEN 1 ELSE 0 END
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
		INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK)
			ON l.LeagueGroupID = lg.GroupID
	WHERE m.matchid = @matchid
		
	SELECT @IsMergedParlay = s.IsMergedParlay		
	FROM SettlementResultTableSetting s WITH(NOLOCK) --table contains sportbook only
	WHERE s.Sporttype = @SportType

	SELECT @IsEarly =  CASE WHEN @Mode LIKE '%EAR' THEN 1 ELSE 0 END
	SELECT @IsCheckHoldEarly =  CASE WHEN @Action LIKE '%EAR'  OR (@sportType = 50 AND @IsAuto = 1) THEN 1 ELSE 0 END

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	SET @xmlResourceResult = CAST(@SelectedResources AS XML)
	SET @xmlData		   = @SelectedResources

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

	--Check MoveBet date ( apply all sportbook)
	IF @Mode NOT LIKE '%INST%'
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_CheckingMoveBetDay
			@MatchIds =  @MatchId 
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
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
										AND f.GroupAction = CASE WHEN @Mode IN ( 'EAR', 'MP', 'FM') THEN @Mode
																	ELSE 'MNL' END
								) f
				WHERE s.matchid = @matchid
					AND s.IsCalculating IN (0, 1)
					AND 1 = CASE @SportType WHEN 1 THEN CASE WHEN f.GroupAction IS NOT NULL THEN 1
															ELSE 0 END
											ELSE 1 END
				)
	BEGIN
		SELECT @ErrCode = 1001003
			, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END

	IF @IsMergedParlay = 0 OR @Mode = 'INST'
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

	-- check waiting ticket
	IF NOT EXISTS ( SELECT TOP 1 1 WHERE @Action = 'CAL' AND @Mode = 'MP' )
	BEGIN
		IF @SportType = 1 AND @Action IN ( 'CAL', 'CAL-HT', 'CAL-FT') AND @LeagueGroupId <> 113
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
		

	--Start: Validation for Refund
	IF @Action = 'REFUND-FT' AND EXISTS ( SELECT TOP 1 1
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
	--/End: Validation for Refund

END
GO