/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE NAP_Admin_Settlement_Validation
(
	 @matchid	INT = 0
	,@ActionID	INT
	,@IsAuto	BIT
	,@SPName	VARCHAR(255)
	,@SelectedResources	VARCHAR(MAX) = NULL
	,@ErrCode	INT			= 0     OUTPUT
	,@ErrMsg	NVARCHAR(200)  = ''    OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation before settle  [Redmine:#175251]

	Param's Explanation:
		@SPName : SP will call to settle after pass validation
		@ActionID
			Parlay			
				CAL			:104
				REFUND-FT	:106		
				REFUND-HT	:120		
				REFUND		:107	
			Single			
				CAL			: 100
				CAL-EARLY SOCCER	: 148
				CAL_EAR OTHER		: 189
				CAL-INST FT Manual	: 178
				CAL-INST FT Auto	: 195
				CAL-INST HT Manual	: 179
				CAL-INST HT Auto	: 196
				UNDO				: 103
				UNDO-EARLY SOCCER	: 149
				UNDO_EAR			: 190	
				UNDO-INST			: 196
				REFUND 		: 109	
				REFUND-FT	: 111
				REFUND-HT	: 110
				REFUND-EARLY SOCCER : 150	
				REFUND_EAR OTHER	: 191

*/

BEGIN
SET NOCOUNT ON

	DECLARE @SportType			SMALLINT
			,@LeagueGroupID		INT
			,@finalhomescore	INT
			,@finalawayscore	INT
			,@WaitingTime		VARCHAR(10)
			,@IsWaiting			BIT = 0
			,@IsSettleByProfile	BIT = 0
			,@IsCheckHoldEarly	BIT = 0
			,@ActionName		VARCHAR(10)
			,@Mode				VARCHAR(10)
			,@IsMergedParlay	BIT = 0

	SELECT  @Mode = CASE WHEN @ActionID = 104 THEN 'CAL-MP'
						 WHEN @ActionID IN (106, 107, 120) THEN 'REFUND-MP'
						 WHEN @ActionID = 100 THEN 'CAL'
						 WHEN @ActionID = 100 THEN 'CAL'			 
						 WHEN @ActionID = 103 THEN 'UNDO'	 		
						 WHEN @ActionID = 109 THEN 'REFUND'		 	
						 WHEN @ActionID = 111 THEN 'REFUND-FT'	 
						 WHEN @ActionID = 110 THEN 'REFUND-HT'
						 WHEN @ActionID IN (178,195,179,196,182) THEN 'INST'
						 WHEN @ActionID IN (148,189,149,190,150,191 ) THEN 'EAR'
						 ELSE '' 
					END
			,@ActionName = CASE @ActionID WHEN 104 THEN 'CAL-MP'			
									WHEN 106 THEN 'REFUND-FTMP'	
									WHEN 120 THEN 'REFUND-HTMP'	
									WHEN 107 THEN 'REFUND-MP'		
									WHEN 100 THEN 'CAL'			 
									WHEN 103 THEN 'UNDO'	 		
									WHEN 109 THEN 'REFUND'		 	
									WHEN 111 THEN 'REFUND-FT'	 
									WHEN 110 THEN 'REFUND-HT'	 
									WHEN 148 THEN 'CAL-EARLY'
									WHEN 189 THEN 'CAL_EAR'	
									WHEN 149 THEN 'UNDO-EARLY'
									WHEN 190 THEN 'UNDO_EAR'		
									WHEN 150 THEN 'REFUND-EARLY'
									WHEN 191 THEN 'REFUND_EAR'
									WHEN 178 THEN 'INST-FT'
									WHEN 195 THEN 'INST-FT'
									WHEN 179 THEN 'INST-HT'
									WHEN 196 THEN 'INST-HT' 
									WHEN 182 THEN 'INST-UNDO'
							ELSE ''
							END

	
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
	IF @ActionID = 104 
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
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK)
				ON m.leagueid = l.leagueid
			INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK)
				ON l.LeagueGroupID = lg.GroupID
		WHERE m.matchid = @matchid
		
		SELECT @IsCheckHoldEarly = CASE 
									 WHEN  @ActionID IN (189, 190, 191)	OR (@sportType = 50 AND @IsAuto = 1) THEN 1
									 ELSE 0
									END
				,@IsMergedParlay = s.IsMergedParlay		
		FROM SettlementResultTableSetting s WITH(NOLOCK) --table contain sportbook only
		WHERE s.Sporttype = @SportType

		IF @SportType IS NULL
		BEGIN
			SELECT	 @ErrCode	= 1001001
					,@ErrMsg	= 'Match does not exist!'
			RETURN
		END		

		--CAL Horse Racing Fixed Odds
		IF @ActionID = 100 AND @sporttype = 154 AND ( ISNULL(@finalhomescore,0) = 0 OR ISNULL(@finalawayscore,0) = 0 )
		BEGIN
			SELECT	@ErrCode = 1001002
					,@ErrMsg    = 'Score is not valid.'
			RETURN
		END

		IF @IsAuto = 1
		BEGIN
			IF  ( @LeagueGroupId <> 113 AND @sporttype = 1 ) -- Auto Settle Pingoal soccer
				OR (@LeagueGroupId <> 42 AND @sporttype = 50 ) --Auto Settle Cricket
				OR (@LeagueGroupId <> 122 AND @sporttype = 2) -- Auto settle pingoal basketball
			BEGIN
				SELECT	 @ErrCode	= 1001052
						,@ErrMsg	= 'The auto-settlement failed due to wrong league group.'
				RETURN
			END
		END

		-- hold match, hold result
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
		IF ( @Sporttype IN (5, 43, 6, 45, 9, 2, 50) AND @LeagueGroupID <> 122 AND @Action LIKE 'CAL%[^M][^P]' OR @Action LIKE 'REFUND%[^M][^P]' )
		BEGIN
			EXEC DBPRO.bodb02.dbo.NAP_Set_ResultSettingChecking
				@MatchId	= @MatchId
				,@Action	= @ActionName
				,@IsAuto	= @IsAuto
				,@SelectedResources = @SelectedResources
				,@ErrCode	= @ErrCode OUTPUT
				,@ErrMsg	= @ErrMsg  OUTPUT
	
			IF ISNULL(@ErrCode,0) <> 0
			RETURN
		END
	
		--validate match.EventStatusReason, match.SettlementStatus, Odds
		IF @sporttype = 1 AND @IsAuto = 0 AND ( @ActionName LIKE 'CAL%[^M][^P]'  OR @ActionName LIKE 'REFUND%[^M][^P]')
		BEGIN
			EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
				@MatchId	= @matchid
				,@Action	= @ActionName
				,@ErrCode	= @ErrCode	OUTPUT
				,@ErrMsg	= @ErrMsg	OUTPUT

			IF @ErrCode > 0
				RETURN
		END

		--Check MoveBet date
		IF @SportType = 1 AND @ActionName NOT LIKE '%MP'
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
		-- check waiting ticket
		EXEC NAP_Admin_Settlement_Checking
			@MatchId = @MatchId
			,@Action = @ActionName
			,@Mode = 'CAL'
			,@xmlData = @SelectedResources
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	
		IF ISNULL(@ErrCode,0) <> 0
		BEGIN
			RETURN
		END
		
	END
END
GO