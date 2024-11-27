/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Validation_Event
(
	 @matchid				INT = 0
	,@DestinationMatchId	INT = 0 --for Move Ticket
	,@Action				VARCHAR(20)
	,@Mode					VARCHAR(20) = NULL
	,@IsAuto				BIT = 0
	,@IsAutoRefund			BIT = 0
	,@SPName				VARCHAR(255)
	,@SelectedResources		VARCHAR(MAX) = NULL 
	,@InstantKey			INT = NULL			--InstantCalculation_Push
	,@SettleAbandonedMatchIBCParlay TINYINT	= 0 --_Refund_MP_Push
	,@SDTRecord				TINYINT	= 0			--Refund_1_Push
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
		- 20221201@Louisa: PinGoal ESports [Redmine:#180808]
		- 202212-5@Louisa: Auto Payout Real Cricket [Redmine:#181137]
		- 20230214@Louisa: Apply Settlement by Profile for Remaining Sports [Redmine: #182677]
		- 20230328@Aries: Support Auto Payout for Main Tennis Matches [Redmine: #182329]
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]
		- 20231219@Louisa: RedCat88 [Redmine:#198365]
		- 20231229@Aries: Enhancement of Auto Settlement [Redmine:#199004]
		- 20240718@Kathy: Implement AiO for Baseball - 8 new bettypes [Redmine:#208026]
		- 20241028@Aries: Direct payout for early soccer [Redmine:#211079]

	Param's Explanation:
		@Action: CAL, CAL-HT, CAL-FT
				REFUND, REFUND-HT, REFUND-FT, REFUND-EAR
				, BetFair, BetDaq ( for refund betdaq,/betfair )
				, MoveTicket ( move betdaq,betfair, ESport )
				,'CAL-INST-HT', 'CAL-INST-FT' 'UNDO-INST-FT', 'UNDO-INST-HT'
		@Mode: ALL, HT, FT, EAR, MP
				,BetFair, BetDaq ( for Move Betdaq/betfair )
		
		@SelectedResources: Appy for Instant soccer, Othersports settle by Profile, FastMarket, TimeMachine, BB
			BB: @SelectedResources = '<Resources><rsc m="1"/><rsc m="2"/><rsc m="3"/><rsc m="4"/><rsc m="5"/></Resources>'

*/

BEGIN
	SET NOCOUNT ON
	
	IF @Mode IN ('FM', 'BB', 'BetDaq') --fastmarket, betbuilder, move betdaq
	BEGIN
		RETURN
	END

	DECLARE @SportType			SMALLINT
			,@LeagueGroupID		INT
			,@matchcode			NVARCHAR(100)
			,@eventdate			DATETIME
			,@eventstatus		NVARCHAR(100)
			,@betstatus			NVARCHAR(100)
			,@childMatchType	TINYINT	
			,@finalhomescore	INT
			,@finalawayscore	INT
			,@hthomescore		INT
			,@htawayscore		INT
			,@livehomescore		INT
			,@liveawayscore		INT
			,@IsSettleByProfile	BIT = 0
			,@IsEarly			BIT = 0
			,@AutoSetting		TINYINT
			,@ParentId			INT
			,@SettlementStatus	TINYINT
			,@isCalculatedHT	BIT

	DECLARE  @Inst_HomeScore		INT
			,@Inst_AwayScore		INT
			,@IsSettleAbandonedMatchIBC BIT --Refund DTM Soccer			
			,@IsCheckHoldEarly		BIT = 0
			,@IsCheckSettlementStatusEarly	BIT = 0
			,@xmlResourceResult		XML
			,@xmlData				VARCHAR(MAX)
			,@IsFailed				BIT = 0
			
			,@IsSettlementStatusChecking	BIT = 0 --call NAP_Set_SettlementStatusChecking
			,@IsHoldChecking				BIT = 0 --call NAP_Set_HoldSettingChecking
			,@IsResultSettingChecking		BIT = 0 --call NAP_Set_ResultSettingChecking
			
	SELECT @sporttype = m.sporttype
			,@ParentId			= m.ParentID
			,@matchcode			= m.matchcode
			,@betstatus			= m.betstatus
			,@childMatchType	= m.ChildMatchType
			,@LeagueGroupID		= lg.GroupID
			,@eventdate			= m.eventdate
			,@eventstatus		= m.eventstatus
			,@finalhomescore	= m.finalhomescore
			,@finalawayscore	= m.finalawayscore
			,@hthomescore		= m.hthomescore
			,@htawayscore		= m.htawayscore
			,@IsSettleAbandonedMatchIBC = CASE WHEN @SDTRecord & 4 > 0 THEN 1 ELSE 0 END
			,@AutoSetting		= ISNULL( m.AutoSetting, l.AutoSetting )
			,@SettlementStatus	=  ISNULL(m.SettlementStatus, 0)
			,@isCalculatedHT	= ISNULL(mr.IsHTCal, 0)
			,@livehomescore		= m.livehomescore
			,@liveawayscore		= m.liveawayscore
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
		LEFT JOIN dbo.LeagueGroup lg WITH(NOLOCK)
			ON l.LeagueGroupID = lg.GroupID
		INNER JOIN dbo.match_remark mr WITH(NOLOCK)
			ON m.matchid = mr.matchid
	WHERE m.matchid = @matchid

	SELECT @IsEarly =  CASE WHEN @Mode LIKE '%EAR' THEN 1 ELSE 0 END
			,@IsAuto = CASE WHEN @Action LIKE '%_MARKET' THEN 0 ELSE @IsAuto END
			,@IsCheckHoldEarly =  CASE WHEN @Action LIKE '%EAR'  OR (@sportType = 50 AND @IsAuto = 1)  THEN 1 
									   WHEN @Action LIKE 'CAL'  AND @sportType = 1 AND @IsAuto = 1 AND   @Mode = 'EAR'  THEN 1 
									ELSE 0 END
			,@IsCheckSettlementStatusEarly = CASE WHEN @Mode = 'EAR' THEN 1
													ELSE 0 END

	--alway check hold status
	SELECT @IsHoldChecking = 1

	SELECT @IsResultSettingChecking =  CASE WHEN  @SportType = 2 AND @LeagueGroupID = 122						THEN 0
											WHEN  @SportType = 43 AND @LeagueGroupID IN (151, 215)				THEN 0
											WHEN  @sporttype IN (8, 50) AND @ChildMatchType = 200  					THEN 0
											WHEN  Setting & 4 > 0 AND @Action = 'REFUND' AND @IsAuto = 1		THEN 0	
											ELSE  1
										END
	FROM dbo.SettlementResultTableSetting s WITH(NOLOCK)
	WHERE s.Sporttype = @SportType
		AND ISNULL(s.Setting,0) & 1 = 1
		AND ISNULL(@SelectedResources,'') <> ''
		AND (@Action LIKE 'CAL%' OR @Action LIKE 'REFUND%')
		


	--validate match.EventStatusReason, match.SettlementStatus, Odds
	-- action cal/refund exclude auto fm, parlay, betbuider
	IF @SportType = 1 
		AND  1 = ( CASE  
					WHEN @Action LIKE 'CAL%'  OR @Action LIKE 'REFUND%'
						THEN CASE 
								WHEN @Mode = 'MP' THEN 0
								WHEN @Action LIKE '%INST%' AND @IsAuto = 1 THEN 0
								ELSE 1 
							END
					ELSE 0 
				END 
			)
	BEGIN
		SELECT @IsSettlementStatusChecking = 1
	END
	--------------------------------------------------------------------

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
	IF @IsHoldChecking = 1
	BEGIN 
		EXEC dbo.NAP_Set_HoldSettingChecking
			@MatchId	= @MatchId
			,@SelectedResources = @SelectedResources
			,@IsEarly	= @IsCheckHoldEarly
			,@ErrCode	= @ErrCode OUTPUT
			,@ErrMsg	= @ErrMsg OUTPUT

		IF ISNULL(@ErrCode,0) <> 0
		RETURN
	END

	IF @IsResultSettingChecking = 1
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
	
	IF @IsAutoRefund  = 1
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

	IF @IsSettlementStatusChecking = 1
	BEGIN
		EXEC dbo.NAP_Set_SettlementStatusChecking
			@MatchId		= @matchid
			,@Action		= @Action
			,@IsEarly 		= @IsCheckSettlementStatusEarly 
			,@IsAutoRefund  = @IsAutoRefund
			,@IsSettleAbandonedMatchIBC = @SDTRecord --refund_1_Push
			,@ErrCode		= @ErrCode	OUTPUT
			,@ErrMsg		= @ErrMsg	OUTPUT

		IF @ErrCode > 0
			RETURN
	END

	------------PARTIAL CHECKING ( Special rule checking ) --------------------

	--Start: validation for Instant settle ( Auto Inst, Manual Inst )
	IF @Action LIKE '%INST%'
	BEGIN
		IF @Action LIKE 'CAL%'
		BEGIN
			IF @AutoSetting & 2 <> 2 OR @SettlementStatus & 87 	> 0 --  disabled instant calculation setting, does not allow doing Inst.C for Pending, Undecided, MTDHold, UnderSettlement, Hold Key
				SELECT @ErrCode = 1001001
					, @ErrMsg   = 'This match has been disabled instant calculation setting!'
			ELSE IF CHARINDEX('hedge', @matchcode) > 0 -- does not allow doing Inst.C for hedge match
				SELECT	@ErrCode = 1001004
						,@ErrMsg   = 'The selected match is a hedge match. Therefore, it cannot be instantly calculated.'
			ELSE IF(@Action = 'CAL-INST-FT' AND @isCalculatedHT = 0)
				SELECT	@ErrCode = 1001003
						,@ErrMsg   = 'Cannot execute FT instant calculation due to HT process (auto/manual) has not done yet.'				
			ELSE IF EXISTS (SELECT TOP 1 1
							FROM dbo.ProviderResultDetail ps WITH (NOLOCK) 
							WHERE	ps.ProviderResultDetailId = @InstantKey
									AND (ps.HomeValue > @LiveHomeScore OR CAST(ps.AwayValue AS INT) > @LiveAwayScore)
							)	
				SELECT	@ErrCode = 1001005
                      ,	 @ErrMsg   = 'Instant Settlement cannot be executed because the Home/Away score which is used for Instant Settlement is greater than the current Home/Away score.'
			ELSE IF(@Action = 'CAL-INST-HT' AND @isCalculatedHT = 1)
				SELECT	@ErrCode = 1001003
						,@ErrMsg   = 'Failed Auto Instant: HT has been settled.'	 

			IF @ErrCode > 0
				RETURN
		END
		ELSE IF @Action LIKE 'UNDO%'
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
		
	IF @IsAuto = 1 AND @Action NOT LIKE '%INST%'
	BEGIN
		--Auto payout soccer
		--NAP_Admin_Settlement_1_AutoPayout_Push.
		IF @SportType = 1 AND @Action LIKE 'CAL%' AND ISNULL(@LeagueGroupId,0) <> 113 AND  ISNULL(@Mode,'') != 'EAR'
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

	--Start: validation for refund parlay 
	IF @Mode = 'MP' AND @Action LIKE 'REFUND%'
	BEGIN
		IF (SELECT CASE 
						WHEN @Action = 'REFUND' AND @SettleAbandonedMatchIBCParlay =  1 THEN 'ABANDONED-1H'
						WHEN @Action = 'REFUND-FT' AND @SettleAbandonedMatchIBCParlay =  2 THEN 'ABANDONED-2H'
						ELSE @Action
					END AS Mode) 
			NOT IN ('REFUND', 'REFUND-HT','REFUND-FT','ABANDONED-1H','ABANDONED-2H')
		BEGIN
			SELECT	@ErrCode = 1001001
					,@ErrMsg    = 'The match or action is invalid!'
			RETURN
		END

		IF  EXISTS (
			SELECT 1
			WHERE 1 = CASE 
						WHEN @betstatus LIKE 'Abandoned 1H%' THEN CASE WHEN (@hthomescore IS NULL OR @htawayscore IS NULL) THEN 1 ELSE 0 END
						WHEN @MatchId = CASE WHEN @SportType IN (8,50) AND ISNULL(@childMatchType,0) = 200 THEN @ParentId 
											 ELSE @matchId END 
							AND (@finalhomescore IS NULL OR @finalawayscore IS NULL OR @hthomescore IS NULL OR @htawayscore IS NULL) THEN 1
						ELSE 0
					END
			)
		BEGIN
			SELECT   @ErrCode = 1001011
				,@ErrMsg = 'This match is being calculated, except following matches (not keyed in score yet): ' + @matchcode
			RETURN
		END
	END
	--End: validation for refund parlay

END
GO