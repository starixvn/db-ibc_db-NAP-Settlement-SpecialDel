/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Validation_Event  
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

	,@ErrCode		INT		= 0     OUTPUT
	,@ErrMsg		NVARCHAR(300)  = ''    OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation event before settle  [Redmine:#175251]

	Param's Explanation:
		@Action: CAL, CAL-HT, CAL-FT, CAL_MARKET, REFUND, REFUND-HT, REFUND-FT, REFUND-EAR,CAL-FM
		@Mode: ALL, HT, FT, EAR, INST-HT, INST-FT, INST-UNDO, FM, BB, MP

*/

BEGIN
SET NOCOUNT ON

	DECLARE @SportType			SMALLINT
			,@LeagueGroupID		INT
			,@finalhomescore	INT
			,@finalawayscore	INT
			,@IsSettleByProfile	BIT = 0
			,@IsEarly			BIT = 0
			,@IsCheckHoldEarly	BIT = 0

	DECLARE  @Inst_HomeScore		INT
			,@Inst_AwayScore		INT
			,@IsSettleAbandonedMatchIBC BIT --Refund DTM Soccer

	SELECT @IsEarly =  CASE WHEN @Mode LIKE '%EAR' THEN 1 ELSE 0 END
	SELECT @IsCheckHoldEarly =  CASE WHEN @Action LIKE '%EAR'  OR (@sportType = 50 AND @IsAuto = 1) THEN 1 ELSE 0 END

	 --calculate parlay other sports, single or multiple matches
	IF @Action = 'CAL' AND @Mode = 'MP'
	BEGIN
		RETURN
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
		EXEC dbo.NAP_Set_HoldSettingChecking
		@MatchId	= @MatchId
		,@SelectedResources = @SelectedResources
		,@IsEarly	= @IsCheckHoldEarly
		,@ErrCode	= @ErrCode OUTPUT
		,@ErrMsg	= @ErrMsg OUTPUT

		IF ISNULL(@ErrCode,0) <> 0
		RETURN
		
		--SOP Refund (confirm refund on ResourceID )
		IF ( @Sporttype IN (5, 43, 6, 45, 9, 2, 50) AND @LeagueGroupID <> 122 AND (@Action LIKE 'CAL%' OR @Action LIKE 'REFUND%' ) )
		BEGIN
			EXEC dbo.NAP_Set_ResultSettingChecking
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
			EXEC dbo.NAP_Set_SettlementStatusChecking
				@MatchId		= @matchid
				,@Action		= @Action
				,@IsAutoRefund  = @IsAutoRefund
				,@IsSettleAbandonedMatchIBC = @SDTRecord --refund_1_Push
				,@IsSettleDetermined = @IsSettleDetermined --Fast market
				,@ErrCode		= @ErrCode	OUTPUT
				,@ErrMsg		= @ErrMsg	OUTPUT

			IF @ErrCode > 0
				RETURN
		END
	
		--Start: validation for Instant settle
		IF @Mode LIKE '%INST%'
		BEGIN
			IF @Action = 'CAL' AND @IsAuto = 1
			BEGIN 
				EXEC dbo.NAP_Set_SettlementStatusChecking
					@MatchId	= @matchid
					,@Action	= @action
					,@ErrCode	= @ErrCode	OUTPUT
					,@ErrMsg	= @ErrMsg	OUTPUT
			END
			
			IF @Action = 'UNDO'
			BEGIN
				EXEC dbo.NAP_Settlement_InstantCalculation_UndoChecking
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
							FROM dbo.ResultDetail with(NOLOCK)
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
			IF @sporttype = 18 AND EXISTS (SELECT 1 FROM dbo.match_remark WITH (NOLOCK) WHERE calculate = 1 AND matchid = @MatchId)
			BEGIN
				SELECT @ErrCode = 1001018
					, @ErrMsg   = 'Auto payout is cancelled because the match has been calculated manually.'
				RETURN
			END

		END
		--/End: Validation for Auto Settle

	END
END
GO