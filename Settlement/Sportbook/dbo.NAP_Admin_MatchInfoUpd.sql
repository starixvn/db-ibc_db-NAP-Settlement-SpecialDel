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
	
	SELECT @HTDone = 0

	SELECT	@SportType = m.sporttype
			,@eventstatus = m.eventstatus
			,@matchcode = m.matchcode
			,@ChildMatchType = ChildMatchType
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId

	IF @SportType = 1
	BEGIN
		SELECT	@HTDone = CASE WHEN r.ResultStatusID = 5 THEN 1 ELSE 0 END
				,@IsRefundHT = CASE WHEN r.ResultStatusID = 2 THEN 1 ELSE 0 END
		FROM	dbo.ResultDetail r WITH(NOLOCK)
		WHERE	r.MatchID = @MatchId
				AND r.ResourceID = '01'

	END
	ELSE
	BEGIN			
		SELECT	@HTDone = IsHTCal 
		FROM	dbo.match_remark WITH(NOLOCK)
		WHERE	matchid = @matchid
	END

	IF @Action LIKE 'CAL%'
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

		-- update resultdetail
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
	ELSE IF @Action = 'UNDO'
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
	ELSE IF @Action LIKE 'REFUND%'
	BEGIN
		SELECT @refundCommand = CASE 
									WHEN @Action = 'REFUND-FT' THEN 'NAP_Admin_Settlement_Refund-FT'
									WHEN @Action = 'REFUND' OR (@IsRefundHT = 1 AND @Action = 'REFUND-FT') THEN 'NAP_Admin_Settlement_Refund-All'
									WHEN @Action = 'REFUND-HT' THEN 'NAP_Admin_Settlement_Refund-HT'
								END
		
		IF @SportType = 1
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
		ELSE
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
	END
END