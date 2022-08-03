/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_MatchInfoUpd
	@MatchId			INT
	,@Action			VARCHAR(20)
	,@FullTimeHome		SMALLINT        = NULL
    ,@FullTimeAway		SMALLINT        = NULL
    ,@HalfTimeHome		SMALLINT        = NULL
    ,@HalfTimeAway		SMALLINT        = NULL 
	,@GoalRecord		VARCHAR(50)     = NULL
    ,@BetStatus			NVARCHAR(50)    = NULL
	,@ResourceResult	VARCHAR(MAX)	= NULL
	,@SDTRecord			TINYINT = NULL
	,@SelectedResources	VARCHAR(MAX)	= NULL
	,@IsDirectly		BIT				= 0
	,@IsAuto			BIT				= 0
	,@AdminId			INT
AS
/*
    Created: 20220719@Kathy
    Task : Update match info 

    Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

*/
BEGIN
	DECLARE @eventstatus	NVARCHAR(50)
			,@matchcode		NVARCHAR(50)
			,@HTDone		BIT
			,@SportType		SMALLINT
			,@ChildMatchType TINYINT
			,@refundCommand VARCHAR(100)
			,@refundCommand_1s VARCHAR(100)
			,@IsRefundHT	BIT
			,@IsSettleByProfile	BIT
			,@existsFinalRound	BIT
			,@existsHTRound BIT
			,@LeagueGroupID SMALLINT
			,@handle	INT

	DECLARE @tmpSelectedRID TABLE(ResourceID VARCHAR(20))

	SELECT @HTDone = 0

	SELECT	@SportType = m.sporttype
			,@eventstatus = m.eventstatus
			,@matchcode = m.matchcode
			,@ChildMatchType = ChildMatchType
			,@LeagueGroupID = ISNULL(l.LeagueGroupID, 0)
	FROM	dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE	m.matchid = @MatchId

	SELECT	@IsSettleByProfile = IsSettleByProfile
	FROM	dbo.SettlementResultTableSetting s WITH(NOLOCK)
	WHERE	s.Sporttype = @SportType

	IF @SportType = 1
	BEGIN
		SELECT	@HTDone = CASE WHEN r.ResultStatusID = 5 THEN 1 ELSE 0 END
				,@IsRefundHT = CASE WHEN r.ResultStatusID = 2 THEN 1 ELSE 0 END
		FROM	dbo.ResultDetail r WITH(NOLOCK)
		WHERE	r.MatchID = @MatchId
				AND r.ResourceID = '01'
	END
	ELSE IF @IsSettleByProfile = 0
	BEGIN			
		SELECT	@HTDone = IsHTCal 
		FROM	dbo.match_remark WITH(NOLOCK)
		WHERE	matchid = @matchid
	END

	IF  @IsSettleByProfile = 1 AND @SelectedResources IS NOT NULL
	BEGIN
		EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
		INSERT INTO @tmpSelectedRID(ResourceID)
		SELECT Id
		FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)																
											) AS tbl
		EXEC sp_xml_removedocument @handle

		SET @existsFinalRound = 0
  		SELECT TOP 1 @existsFinalRound = 1
  		FROM @tmpSelectedRID sr
  		WHERE sr.ResourceID = '00'

  		SET @existsHTRound = 0
  		SELECT TOP 1 @existsHTRound = 1					
  		FROM @tmpSelectedRID sr
  		WHERE sr.ResourceID = '01' 
			AND 1 = CASE 
						WHEN @sportType = 2 THEN 1
						WHEN @sportType = 1 AND @LeagueGroupID = 113 THEN 1---PinGoal
						ELSE 0
					END

		IF @existsHTRound = 1 
		BEGIN
			SELECT  @HalfTimeHome	= COALESCE (@HalfTimeHome, 0)
					,@HalfTimeAway   = COALESCE (@HalfTimeAway, 0)
		END
			
  		IF @existsFinalRound = 1
  		BEGIN
	  		SELECT  @HalfTimeHome	= COALESCE (@HalfTimeHome, 0)
					,@HalfTimeAway   = COALESCE (@HalfTimeAway, 0)
					,@FullTimeHome   = COALESCE (@FullTimeHome, 0)
					,@FullTimeAway   = COALESCE (@FullTimeAway, 0)
		END
	END

	IF @Action LIKE 'CAL%'
	BEGIN
		IF (@SportType = 1 AND @LeagueGroupID <> 113)
			OR (@SportType = 1 AND @LeagueGroupID = 113 AND @SelectedResources IS NULL) -- cal pingoal manually
			OR @IsSettleByProfile = 0
		BEGIN
			SELECT	@eventstatus = CASE 
										WHEN @action = 'CAL' THEN N'completed'
										WHEN @action = 'CAL-HT' AND @matchcode LIKE '%hedge%' THEN @eventstatus -- Jamie@20120330: Not change eventstatus='completed' for Hedge Match although 
										WHEN @action = 'CAL-FT' AND @HTDone = 1 THEN N'completed'
										ELSE @eventstatus
										END			

			EXEC dbo.NAP_Admin_Match_Update 
				@Command            = 'NAP_Admin_Settlement_1-CAL'
				,@MatchID           = @matchid
				,@FTHome            = @FullTimeHome
				,@FTAway            = @FullTimeAway
				,@HTHome            = @HalfTimeHome
				,@HTAway            = @HalfTimeAway
				,@BetStatus         = @BetStatus
				,@GoalRecord        = @GoalRecord              
				,@Action            = @Action
				,@HTDone            = @HTDone
				,@creator           = @AdminId

			IF @eventstatus = 'completed' AND @BetStatus NOT LIKE '%Refund;%' AND @BetStatus NOT LIKE '%Refund FT;%' AND @BetStatus NOT LIKE '%Abandoned%' 
			BEGIN
				EXEC dbo.NAP_updateMatch_remark 
					@matchid    = @matchid
					,@command    = 'C'                
			END
			ELSE IF (@action = 'CAL-HT')
			BEGIN
				EXEC dbo.NAP_updateMatch_remark 
					@matchid    = @matchid
					,@command    = 'H'
			END

			IF @SportType = 1
			BEGIN
				EXEC dbo.NAP_Admin_Result_Update_1s
					@Command         = 'NAP_Admin_Settlement_1-CAL',
					@MatchID         = @MatchID,
					@fth             = @FullTimeHome,
					@fta             = @FullTimeAway,
					@hth             = @HalfTimeHome,
					@hta             = @HalfTimeAway,
					@ResourceResult	 = @ResourceResult,
					@Action          = @Action,
					@IsAuto          = 0,
					@creator		 = @AdminId
			END
		END
		ELSE
		BEGIN
			EXEC dbo.NAP_Admin_Match_Update
					@Command				= 'profile'
					,@Action				= 'CAL'
					,@MatchID				= @matchid
					,@FTHome				= @FullTimeHome
					,@FTAway				= @FullTimeAway
					,@HTHome				= @HalfTimeHome
					,@HTAway				= @HalfTimeAway
					,@creator				= @AdminId
					,@IsFinalRound			= @existsFinalRound
					,@IsHTRound				= @existsHTRound
					,@BetStatus				= @BetStatus

			IF  @existsFinalRound = 1
			BEGIN				 
				EXEC dbo.NAP_updateMatch_remark
							@matchid				= @matchid
							,@command				= 'C'
			END

			ELSE IF @existsHTRound = 1
			BEGIN				 
				EXEC dbo.NAP_updateMatch_remark 
						@matchid    = @matchid
						,@command    = 'H'
			END

			EXEC dbo.NAP_Admin_Result_Update_9001
				@action					= 'CAL'
				,@MatchID				= @MatchID
				,@creator				= @AdminId
				,@Sporttype				= @Sporttype
				,@SelectedRID   		= @SelectedResources
				,@IsDirectly			= @IsDirectly
				,@IsAuto				= @IsAuto
		END

	END
	ELSE IF @Action LIKE 'UNDO%'
	BEGIN
		IF (@SportType = 1 AND @LeagueGroupID <> 113)
			OR (@SportType = 1 AND @LeagueGroupID = 113 AND @SelectedResources IS NULL) -- cal pingoal manually
			OR @IsSettleByProfile = 0
		BEGIN
			EXEC dbo.NAP_Admin_Match_Update 
				@Command        = 'NAP_Admin_Settlement_1-UNDO'
				,@MatchID       = @matchid
				,@betstatus     = @betstatus               
				,@creator       = @AdminId

			EXEC dbo.NAP_UpdateMatch_Remark 
				@matchid        = @matchid
				,@command        = 'U'                
        
			IF @SportType <> 1 -- update parlay
			BEGIN
				EXEC dbo.NAP_Admin_Match_Update @Command = 'NAP_Admin_Settlement_Parlay'
					,@Matchid = @matchid
					,@creator = @AdminId
			END
		
			IF @SportType = 1-- Soccer
			BEGIN
				IF @ChildMatchType = 204 -- Corner
				BEGIN
					EXEC dbo.NAP_Admin_Result_Update_1s 
						@Command            = 'NAP_Admin_Settlement_1-Corner-UNDO',
						@MatchID            = @MatchID,
						@creator            = @AdminId 
				END
				ELSE
				BEGIN
					EXEC dbo.NAP_Admin_Result_Update_1s 
						@Command            = 'NAP_Admin_Settlement_1-UNDO',
						@MatchID            = @MatchID,
						@creator            = @AdminId 
				END

				EXEC dbo.NAP_Set_AutoPayoutResultUpd 
					@MatchId = @matchid
					,@TypeId = NULL
					,@StatusId = NULL 
					,@IsUndoMatch = 1 --Clear data in table AutoPayoutResult if match has been undo

			END   
		END
		ELSE
		BEGIN
			EXEC dbo.NAP_Admin_Match_Update
				@Command			='profile'
				,@Action			='UNDO'
				,@MatchID			= @matchid
				,@creator			= @AdminId
				,@IsFinalRound		= @existsFinalRound
				,@IsHTRound			= @existsHTRound
				,@BetStatus			= @BetStatus
			
			IF @existsFinalRound = 1
			BEGIN
				EXEC dbo.NAP_updateMatch_remark
					@matchid			= @matchid
					,@command			= 'U'
					,@IsFinalRound		= @existsFinalRound
			END
			ELSE IF @existsHTRound = 1
			BEGIN
				EXEC dbo.NAP_updateMatch_remark
					@matchid			= @matchid
					,@command			= 'U'							

			END

			EXEC dbo.NAP_Admin_Result_Update_9001
				@action  			= 'UNDO'
				,@matchid 			= @MatchId
				,@SelectedRID   	= @SelectedResources
				,@Sporttype			= @Sporttype
				,@creator 			= @AdminId			
		END
	END
	ELSE IF @Action LIKE 'REFUND%'
	BEGIN
		SELECT @refundCommand = CASE 
									WHEN @Action = 'REFUND-FT' THEN 'NAP_Admin_Settlement_Refund-FT'
									WHEN @Action = 'REFUND' OR (@IsRefundHT = 1 AND @Action = 'REFUND-FT') THEN 'NAP_Admin_Settlement_Refund-All'
									WHEN @Action = 'REFUND-HT' THEN 'NAP_Admin_Settlement_Refund-HT'
								END
		
		IF (@SportType = 1 AND @LeagueGroupID <> 113)
			OR (@SportType = 1 AND @LeagueGroupID = 113 AND @SelectedResources IS NULL) -- cal pingoal manually
		BEGIN
			SELECT @refundCommand_1s =  @refundCommand

			IF @SDTRecord & 4 > 0
			BEGIN
				SET @refundCommand = @refundCommand + '-Abandoned'
				SET @refundCommand_1s = CASE 
											WHEN @Action = 'REFUND-FT' THEN 'NAP_Admin_Settlement_RefundFT-Abandoned' 
											ELSE @refundCommand
										END
			END

			SELECT @HTDone = CASE 
							WHEN @Action = 'REFUND' THEN 1						
							WHEN @Action = 'REFUND-FT' AND @HTDone = 1 THEN 1 
							ELSE 0 END

			EXEC dbo.NAP_Admin_Match_Update 
				@Command         = @refundCommand
				,@MatchID        = @matchid
				,@creator        = @AdminId
				,@BetStatus 	 = @betstatus
				,@GoalRecord	 = @GoalRecord 
				,@HTHome		 = @HalfTimeHome
				,@HTAway		 = @HalfTimeAway
				,@FTHome		 = @FullTimeHome
				,@FTAway		 = @FullTimeAway
				,@HTDone		 = @HTDone
			
			EXEC dbo.NAP_updateMatch_remark 
				@matchid       = @matchid
				,@command      = 'F'		

			EXEC dbo.[NAP_Admin_Result_Update_1s] 
				@Command        = @refundCommand_1s
				,@MatchID       = @matchid
				,@creator       = @AdminId
				,@SDTRecord		= @SDTRecord
				,@fth			= @FullTimeHome
				,@fta			= @FullTimeAway
				,@hth			= @HalfTimeHome
				,@hta			= @HalfTimeAway
				,@ResourceResult = @ResourceResult
				,@Action        = @Action
		END
		ELSE IF @IsSettleByProfile = 0
		BEGIN
			EXEC dbo.NAP_Admin_Match_Update 
				@Command 	= @refundCommand --'NAP_Admin_Settlement_Refund-FT'
				,@MatchID 	= @matchid		
				,@creator 	= @adminid
				,@BetStatus = @betstatus	
				
			EXEC dbo.NAP_updateMatch_remark 
				@matchid    = @matchid
				,@command   = 'F'

		END
		ELSE
		BEGIN
			SELECT  @HalfTimeHome	= COALESCE (@HalfTimeHome, 0)
					,@HalfTimeAway   = COALESCE (@HalfTimeAway, 0)
					,@FullTimeHome   = COALESCE (@FullTimeHome, 0)
					,@FullTimeAway   = COALESCE (@FullTimeAway, 0)

			EXEC dbo.NAP_Admin_Match_Update
							@matchid			= @matchid
							,@command			= 'profile'
							,@Action			= 'REFUND'
							,@FTHome			= @FullTimeHome
							,@FTAway			= @FullTimeAway
							,@HTHome			= @HalfTimeHome
							,@HTAway			= @HalfTimeAway
							,@IsFinalRound  	= @existsFinalRound
							,@IsHTRound			= @existsHTRound
							,@BetStatus			= @BetStatus
							
			EXEC dbo.NAP_Admin_Result_Update_9001
							@action				= 'REFUND'
							,@MatchID			= @MatchID
							,@creator			= @AdminId
							,@Sporttype			= @Sporttype
							,@SelectedRID   	= @SelectedResources
							,@IsAuto			= @IsAuto
							
			IF  @existsFinalRound = 1 OR @existsHTRound = 1
			BEGIN
					EXEC dbo.NAP_updateMatch_remark
						@matchid			= @matchid
						,@command			= 'F'
						,@IsFinalRound		= @existsFinalRound

			END
		END
	END
END