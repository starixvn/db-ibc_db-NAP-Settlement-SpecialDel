/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Validation
(
	 @matchid		INT = 0
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

	,@SessionID		BIGINT = 0		OUTPUT
	,@ErrCode		INT		= 0     OUTPUT
	,@ErrMsg		NVARCHAR(300)  = ''    OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation before settle  [Redmine:#175251]

	Param's Explanation:
		@Action: CAL, CAL-HT, CAL-FT, CAL_MARKET, REFUND, REFUND-HT, REFUND-FT, REFUND-EAR,FM
		@Mode: ALL, HT, FT, EAR, INST-HT, INST-FT, INST-UNDO, FM, BB, MP

		@SettleAbandonedMatchIBCParlay
		
		select top 1 1 * from bettrans

*/

BEGIN
SET NOCOUNT ON
	
	SET  @SessionID = SCOPE_IDENTITY()

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
			,@xmlData			XML = ''

	DECLARE  @Inst_HomeScore		INT
			,@Inst_AwayScore		INT
			,@IsSettleAbandonedMatchIBC BIT --Refund DTM Soccer

	SELECT @IsEarly =  CASE WHEN @Mode LIKE '%EAR' THEN 1 ELSE 0 END
	SELECT @IsCheckHoldEarly =  CASE WHEN @Action LIKE '%EAR'  OR (@sportType = 50 AND @IsAuto = 1) THEN 1 ELSE 0 END

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

	 --calculate parlay other sports, single or multiple matches
	IF @Action = 'CAL' AND @Mode = 'MP'
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM dbo.SystemSettings WHERE VName = 'isCalculatingParlay' AND VValue <> '0')
			OR EXISTS (SELECT TOP 1 1 FROM dbo.ParlayLocking)
		BEGIN
			SELECT	@ErrCode = 1000000
					,@ErrMsg = 'Another parlay settlement is in progress or some parlay tickets are being deleted, please wait a few seconds until the on-going process has finished and try again.'
			RETURN	
		END
	END

	ELSE
	BEGIN
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
		FROM SettlementResultTableSetting s WITH(NOLOCK) --table contain sportbook only
		WHERE s.Sporttype = @SportType

		IF @SportType IS NULL
		BEGIN
			SELECT	 @ErrCode	= 1001001
					,@ErrMsg	= 'Match does not exist!'
			RETURN
		END		

		--CAL Horse Racing Fixed Odds
		IF @Action = 'CAL' AND @sporttype = 154 AND ( ISNULL(@finalhomescore,0) = 0 OR ISNULL(@finalawayscore,0) = 0 )
		BEGIN
			SELECT	@ErrCode = 1001002
					,@ErrMsg    = 'Score is not valid.'
			RETURN
		END

		--Check hold match, hold result
		EXEC DBPRO.bodb02.dbo.NAP_Set_HoldSettingChecking
		@MatchId	= @MatchId
		,@SelectedResources = @SelectedResources
		,@IsEarly	= @IsCheckHoldEarly
		,@ErrCode	= @ErrCode OUTPUT
		,@ErrMsg	= @ErrMsg OUTPUT

		IF ISNULL(@ErrCode,0) <> 0
		BEGIN
			RETURN
		END
		
		--SOP Refund (confirm refund on ResourceID )
		IF ( @Sporttype IN (5, 43, 6, 45, 9, 2, 50) AND @LeagueGroupID <> 122 AND @Action LIKE 'CAL%' OR @Action LIKE 'REFUND%' )
		BEGIN
			EXEC DBPRO.bodb02.dbo.NAP_Set_ResultSettingChecking
				@MatchId	= @MatchId
				,@Action	= @Action
				,@IsAuto	= @IsAuto
				,@SelectedResources = @SelectedResources
				,@ErrCode	= @ErrCode OUTPUT
				,@ErrMsg	= @ErrMsg  OUTPUT
	
			IF ISNULL(@ErrCode,0) <> 0
			RETURN
		END
	
		--validate match.EventStatusReason, match.SettlementStatus, Odds
		IF @sporttype = 1 AND ( @Action LIKE 'CAL%'  OR @Action LIKE 'REFUND%')
		BEGIN
			EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
				@MatchId		= @matchid
				,@Action		= @Action
				,@IsAutoRefund  = @IsAutoRefund
				,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC --refund_1_Push
				,@IsSettleDetermined = @IsSettleDetermined --Fast market
				,@ErrCode		= @ErrCode	OUTPUT
				,@ErrMsg		= @ErrMsg	OUTPUT

			IF @ErrCode > 0
				RETURN
		END

		--Check MoveBet date
		IF @SportType = 1 AND @Mode NOT LIKE '%INST%'
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
											AND f.GroupAction = CASE WHEN @Mode IN ( 'EAR', 'MP') THEN @Mode
																	 ELSE 'MNL' END
									) f
					WHERE s.matchid = @matchid
					  AND s.IsCalculating IN (0, 1)
					  AND 1 = CASE @SportType WHEN 1 THEN CASE WHEN f.GroupAction IS NOT NULL THEN 1
																ELSE 0 END
												ELSE 0 END
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
				SET @xmlData = CAST(@SelectedResources AS XML)

				;WITH cteGoalResource AS
				(	
					SELECT  T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
					FROM   @xmlData.nodes('/Results/Resource') AS T(C)
				)
				,cteResource AS
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
				,@Mode	  =  @Mode
				,@xmlData = @SelectedResources
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg  = @ErrMsg OUTPUT
	
			IF ISNULL(@ErrCode,0) <> 0
			RETURN
		END

		--Start: validation for Instant settle
		IF @Mode LIKE '%INST%'
		BEGIN
			IF @Action = 'CAL'
			BEGIN
				EXEC dbo.NAP_Settlement_InstantCalculation_Checking 
					@MatchId 		= @MatchId
					, @InstantKey	= @InstantKey
					, @Action 		= @Action
					, @Mode			= @Mode
					, @ErrCode 		= @ErrCode OUTPUT
					, @ErrMsg 		= @ErrMsg OUTPUT

				IF @IsAuto = 1
				BEGIN
					EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
						@MatchId	= @matchid
						,@Action	= @action
						,@ErrCode	= @ErrCode	OUTPUT
						,@ErrMsg	= @ErrMsg	OUTPUT
				END
			END
			
			IF @Action = 'UNDO'
			BEGIN
				EXEC DBPRO.bodb02.dbo.NAP_Settlement_InstantCalculation_UndoChecking
					@MatchId		= @MatchId
					, @InstantCheck	= @InstantKey
					, @ErrCode 		= @ErrCode OUTPUT
					, @ErrMsg		= @ErrMsg OUTPUT
			END

			IF ISNULL(@ErrCode,0)>0
			RETURN

		END
		--/ END validation for Instant settle
		
		--Start: Validation for Auto Settle
		IF @IsAuto = 1 AND @Mode NOT LIKE '%INST%' AND @Mode <> 'FM'
		BEGIN
			IF  ( @LeagueGroupId <> 113 AND @sporttype = 1 ) -- Auto Settle Pingoal soccer
				OR (@LeagueGroupId <> 42 AND @sporttype = 50 ) --Auto Settle Cricket
				OR (@LeagueGroupId <> 122 AND @sporttype = 2) -- Auto settle pingoal basketball
			BEGIN
				SELECT	 @ErrCode	= 1001052
						,@ErrMsg	= 'The auto-settlement failed due to wrong league group.'
				RETURN
			END

			--Auto payout soccer
			IF @SportType = 1 AND @Action LIKE 'CAL%' AND @LeagueGroupId <> 113
			BEGIN
				IF EXISTS (SELECT TOP 1 1
							FROM DBPRO.bodb02.dbo.ResultDetail with(NOLOCK)
							WHERE matchid = @matchid
								AND 1 = CASE 
											WHEN resourceId = '00' AND @Action IN ('CAL', 'CAL-FT') THEN 1
											WHEN resourceId = '01' AND @Action  = 'CAL-HT' THEN 1
											ELSE 0
										END
								AND resultStatusId = 5 -- completed (manual)
							)
				BEGIN
					SELECT @ErrCode = 1001018
						, @ErrMsg   = 'Auto payout is cancelled because the match has been calculated manually.'
					RETURN
				END



			END

			--Auto Payout Table Tennis
			IF @sporttype = 18 AND EXISTS (SELECT 1 FROM DBPRO.bodb02.dbo.match_remark WITH (NOLOCK) WHERE calculate = 1 AND matchid = @MatchId)
			BEGIN
				SELECT @ErrCode = 1001018
					, @ErrMsg   = 'Auto payout is cancelled because the match has been calculated manually.'
				RETURN
			END

		END
		--/End: Validation for Auto Settle

		--Start: Validation for Refund
		IF @Action LIKE 'REFUND%'
		BEGIN
			--IF @Sporttype = 1 AND @Mode = 'ALL'
			--BEGIN
			--	SELECT	@Inst_HomeScore = HomeValue
			--			,@Inst_AwayScore = AwayValue
			--	FROM	(	SELECT	HomeValue
			--						,AwayValue
			--						,ROW_NUMBER() OVER (ORDER BY AutoPayoutResultId DESC) AS rn
			--				FROM	DBPRO.bodb02.dbo.AutoPayoutResult WITH (NOLOCK)
			--				WHERE	matchid = @Matchid
			--						AND CalculationType = 101
			--						AND statusId IN (1,2) -- Waiting, Completed
			--			) s
			--			WHERE	rn = 1
			
			--	IF (@HalfTimeHome < @Inst_HomeScore  OR @HalfTimeAway < @Inst_AwayScore	)
			--	BEGIN
			--		SELECT @ErrCode = 1001029
			--			,@ErrMsg    = 'This match has been executed Instant Settlement with score '+ CAST(@Inst_HomeScore AS VARCHAR) + '-' + CAST(@Inst_AwayScore AS VARCHAR) + '. Please uncalculate it first!'
			--		RETURN
			--	END
			--END

			--refund FT
			IF @Action = 'REFUND-FT' AND EXISTS ( SELECT TOP 1 1
						FROM	dbo.bettrans b WITH(NOLOCK)
							CROSS APPLY ( SELECT TOP 1 b.bettype
										  FROM dbo.f_Set_GetGroupBettypes() f
										  WHERE b.bettype = f.BetType
											AND f.GroupId IN (1,3)
										) f
						WHERE	b.matchid = @MatchId
								AND b.statusID = 0
					)
				BEGIN
					SELECT	@ErrCode = 1001031
							,@ErrMsg = 'Error! Cannot proceed due to running Half Time tickets. Please proceed with Half Time settlement and try again.'
					RETURN
				END

		END
		--/End: Validation for Auto Settle

	END
END
GO