/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Validation_Event
(
	 @matchid			INT = 0
	,@DestinationMatchId	INT = 0 --for Move Ticket
	,@Action				VARCHAR(10)
	,@Mode					VARCHAR(10)
	,@IsAuto				BIT = 0
	--,@IsAutoRefund	BIT = 0
	,@SPName				VARCHAR(255)
	,@SelectedResources		VARCHAR(MAX) = NULL 
	,@InstantKey			INT = NULL			--InstantCalculation_Push
	,@SettleAbandonedMatchIBCParlay TINYINT	= 0 --_Refund_MP_Push
	,@SDTRecord				TINYINT	= 0			--Refund_1_Push
	,@IsSettleDetermined	BIT	= 0				--Fast_Market_Auto_1s_Push

	,@VendorID				SMALLINT = 34
	,@childMatchIdCricket	INT		 = 0 OUTPUT
	,@ErrCode				INT		 = 0 OUTPUT
	,@ErrMsg				NVARCHAR(300)  = ''    OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation event before settle  [Redmine:#175251]

	Param's Explanation:
		@Action: CAL, CAL-HT, CAL-FT, CAL_MARKET
				REFUND, REFUND-HT, REFUND-FT, REFUND-EAR,CAL-FM
				, BetFair, BetDaq ( for refund betdaq,/betfair )
				, MoveTicket ( move betdaq,betfair, ESport )

		@Mode: ALL, HT, FT, EAR, INST-HT, INST-FT, INST-UNDO, FM, BB, MP
				,BetFair, BetDaq ( for Move Betdaq/betfair )
		
		@SelectedResources: Appy for Instant soccer, Othersports settle by Profile, FastMarket, TimeMachine, BB
			BB: @SelectedResources = '<Resources><rsc m="1"/><rsc m="2"/><rsc m="3"/><rsc m="4"/><rsc m="5"/></Resources>'

*/

BEGIN
SET NOCOUNT ON
	
	DECLARE @SportType			SMALLINT
			,@LeagueGroupID		INT
			,@eventdate			DATETIME
			,@eventstatus		NVARCHAR(100)
			,@finalhomescore	INT
			,@finalawayscore	INT
			,@IsSettleByProfile	BIT = 0
			,@IsEarly			BIT = 0
			,@AutoSetting		TINYINT
			,@ParentId			INT
			,@maxNumProcessBB	INT = 50000

	DECLARE  @Inst_HomeScore		INT
			,@Inst_AwayScore		INT
			,@IsSettleAbandonedMatchIBC BIT --Refund DTM Soccer			
			,@IsCheckHoldEarly		BIT = 0
			,@IsCheckSettlementStatusEarly	BIT = 0
			,@xmlResourceResult		XML
			,@xmlData				VARCHAR(MAX)
			,@IsFailed				BIT = 0
			,@IsAutoRefund			BIT = 0 

	SELECT @IsEarly =  CASE WHEN @Mode LIKE '%EAR' THEN 1 ELSE 0 END
			,@IsAuto = CASE WHEN @Action LIKE '%_MARKET' THEN 0 ELSE @IsAuto END
			,@IsCheckHoldEarly =  CASE WHEN @Action LIKE '%EAR'  OR (@sportType = 50 AND @IsAuto = 1) THEN 1 
									ELSE 0 END
			,@IsCheckSettlementStatusEarly = CASE WHEN @IsAuto = 0 AND @Mode = 'FM' THEN 1 
													WHEN @Mode = 'EAR' THEN 1
													ELSE 0 END
			,@IsAutoRefund	=  CASE WHEN @Action = 'REFUND' AND @IsAuto = 1 THEN 1
									ELSE 0 END

	SELECT @sporttype = m.sporttype
			,@ParentId			= m.ParentID
			,@LeagueGroupID		= lg.GroupID
			,@eventdate			= m.eventdate
			,@eventstatus		= m.eventstatus
			,@finalhomescore	= m.finalhomescore
			,@finalawayscore	= m.finalawayscore
			,@IsSettleAbandonedMatchIBC = CASE WHEN @SDTRecord & 4 > 0 THEN 1 ELSE 0 END
			,@AutoSetting		= ISNULL( m.AutoSetting, l.AutoSetting )
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
		INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK)
			ON l.LeagueGroupID = lg.GroupID
	WHERE m.matchid = @matchid

	--------------------------------------------------------------------
	--calculate parlay other sports, single or multiple matches
	IF	( @Action = 'CAL' AND @Mode = 'MP' )
		OR @Mode = 'BetDaq' --move betdaq
	BEGIN
		RETURN
	END

	IF @Mode = 'Betfair' --move betfair
	BEGIN
		IF	NOT EXISTS (	SELECT TOP 1 1
							FROM	dbo.odds WITH (NOLOCK)
							WHERE	matchid = @DestinationMatchId
								AND liveindicator IN (0 , 1 )
						)
		BEGIN
			SELECT	@ErrCode = 102
					,@ErrMsg  =  'The selected match has not any odds for moving tickets. Please select another match with existing odds.'
		END

		RETURN
	END

	--Move ticket Cricket
	IF @Action = 'MoveTicket' AND @Mode = '43'
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_MoveTicketChecking_Event
			 @MatchId			 = @MatchId
			,@DestinationMatchId = @DestinationMatchId
			,@ErrCode			 = @ErrCode OUTPUT
			,@ErrMsg			 = @ErrMsg OUTPUT
		
		IF ISNULL(@ErrCode, 0) > 0
			RETURN

		RETURN
	END

	IF @Action = 'MoveTicket' AND @Mode = '50'
	BEGIN
		
		IF @eventstatus = 'completed'
		BEGIN
			SELECT	@ErrCode = 1001050
					,@ErrMsg = 'WARNING! Cannot continue due to current match is completed.'	
			RETURN
		END

		EXEC dbo.NAP_Set_HoldSettingChecking
			@MatchId	= @Matchid
			,@ErrCode	= @ErrCode OUTPUT
			,@ErrMsg	= @ErrMsg OUTPUT

		IF ISNULL(@ErrCode,0) > 0
		RETURN

		IF NOT EXISTS( SELECT TOP 1 1
						FROM	dbo.match m WITH(NOLOCK)
						WHERE	m.ParentID = @MatchId
								AND m.ChildMatchType = 200
								AND m.eventdate = @eventdate
								AND ISNULL(m.IsDeleted,0) = 0
						ORDER BY m.matchid
					)
		BEGIN
			SELECT	@ErrCode = 1001048
					,@ErrMsg = 'WARNING! Cannot continue due to destination match not found.'	
			RETURN
		END

		RETURN
	END

	------------COMMON CHECKING ( Apply for almost sports ) --------------------

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
	
	IF @SportType = 1 AND @IsAutoRefund = 1
	BEGIN
		EXEC NAP_Set_AutoRefund_MatchChecking_Event
			@MatchId		= @matchid
			,@sporttype		= @SportType
			,@ParentId		= @ParentId
			,@TypeId		= 1
			,@ErrCode 		= @ErrCode OUTPUT
			,@ErrMsg 		= @ErrMsg OUTPUT

		IF ISNULL(@ErrCode,0) > 0
			RETURN
	END

	--validate match.EventStatusReason, match.SettlementStatus, Odds
	IF @sporttype = 1 AND ( @Action LIKE 'CAL%'  OR @Action LIKE 'REFUND%')
	BEGIN
		EXEC dbo.NAP_Set_SettlementStatusChecking
			@MatchId		= @matchid
			,@Action		= @Action
			,@IsEarly 		= @IsCheckSettlementStatusEarly 
			,@IsAutoRefund  = @IsAutoRefund
			,@IsSettleAbandonedMatchIBC = @SDTRecord --refund_1_Push
			,@IsSettleDetermined = @IsSettleDetermined --Fast market
			,@ErrCode		= @ErrCode	OUTPUT
			,@ErrMsg		= @ErrMsg	OUTPUT

		IF @ErrCode > 0
			RETURN
	END
	
	------------PARTIAL CHECKING ( Special rule checking ) --------------------

	--Start: validation for Instant settle ( Auto Inst, Manual Inst )
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
		
	--Start: Validation Betbuider
	IF @IsAuto = 1 AND @Mode = 'BB'
	BEGIN
			
			IF @AutoSetting & 8 = 0  -- 100 -- setting of BetBuilder
			BEGIN
				SELECT	@ErrCode = 1001017
						,@ErrMsg = 'The auto-settlement failed due to OFF setting.'
				RETURN
			END					
			
			EXEC  dbo.NAP_Admin_Settlement_Validation_BB 
			 @matchid		= @matchid
			,@Action		= @Action
			,@SelectedResources	= @SelectedResources
			,@maxNumProcess	= @maxNumProcessBB
			,@VendorID		= @VendorID
			,@ErrCode		= @ErrCode    OUTPUT
			,@ErrMsg		= @ErrMsg   OUTPUT
				
			IF ISNULL(@ErrCode,0) > 0
			RETURN

	END
	--/End validation Betbuider
	
	
	IF @IsAuto =1 AND @Mode NOT LIKE '%INST%' AND @Mode <> 'FM' AND @Mode <> 'BB'
	BEGIN
		IF  @SPName = 'NAP_Admin_Settlement_Profile_Push'
			AND (	( @LeagueGroupId <> 113 AND @sporttype = 1 ) -- Auto Settle Pingoal soccer
						OR (@LeagueGroupId <> 42 AND @sporttype = 50 ) --Auto Settle Cricket
						OR (@LeagueGroupId <> 122 AND @sporttype = 2) -- Auto settle pingoal basketball
				)
		BEGIN
			SELECT	 @ErrCode	= 1001052
					,@ErrMsg	= 'The auto-settlement failed due to wrong league group.'
			RETURN
		END

		--Auto payout soccer
		--NAP_Admin_Settlement_1_AutoPayout_Push.
		IF @SportType = 1 AND @Action LIKE 'CAL%' AND @LeagueGroupId <> 113
		BEGIN
			IF EXISTS (SELECT TOP 1 1
						FROM dbo.ResultDetail with(NOLOCK)
						WHERE matchid = @matchid
							AND 1 = CASE WHEN resourceId = '00' AND @Action IN ('CAL', 'CAL-FT') THEN 1
										 WHEN resourceId = '01' AND @Action  = 'CAL-HT' THEN 1
										 ELSE 0
									END
							AND resultStatusId = 5 -- completed (manual)
						)
			SET @IsFailed  = 1
		END

		--Auto Payout Table Tennis
		IF @sporttype = 18 AND EXISTS (SELECT 1 FROM dbo.match_remark WITH (NOLOCK) WHERE calculate = 1 AND matchid = @MatchId)
		BEGIN
			SET @IsFailed = 1
		END

		IF @IsFailed = 1
		BEGIN
			SELECT @ErrCode = 1001018
				, @ErrMsg   = 'Auto payout is cancelled because the match has been calculated manually.'
			RETURN
		END

	END
	--/End: Validation for Auto Settle

	--Fast Market
	IF @Mode = 'FM'
	BEGIN
		EXEC NAP_Admin_Settlement_ValidationFM_Event
			 @matchid		= @matchid
			,@Action		= @Action
			,@IsAuto		= @IsAuto
			,@SelectedResources	= @SelectedResources
			,@AutoSetting	= @AutoSetting	
			,@ErrCode		= @ErrCode   OUTPUT
			,@ErrMsg		= @ErrMsg    OUTPUT

		IF ISNULL(@ErrCode,0)>0
			RETURN
	END


END
GO