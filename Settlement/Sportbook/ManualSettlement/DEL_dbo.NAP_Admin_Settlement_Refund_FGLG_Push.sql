/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_FGLG_Push] 
	@MatchId				INT
	,@action				VARCHAR(10) 	= 'REFUND' -- REFUND, REFUND-FT, REFUND-HT
	,@AdminId				INT
	,@LastGoalOnly			BIT
	,@IP					VARCHAR(15) 	= ''
	,@IsLoopTempTable		BIT				= 0
	,@ErrCode				INT				= 0		OUTPUT
	,@ErrMsg				NVARCHAR(200)	= ''	OUTPUT
AS
/*
Created: 20140213@Kathy
Task : Refund Half-time in case there are HT tickets bet on special matches that have 3 sets
DB: DBTXN/BODB02
Original: Admin_Settlement_Refund_FGLG

Revisions:
	- 20140506@Kathy: Don't allow to calculate exists matches in queue
	- 20140507@Kathy: Add param @action (for bettype 1H FGLG (127)) [Redmine:#14449]
	- 20140825@Kathy: Support 1H FGLG (127) for Apollo [Redmine:#16276]
	- 20150401@Kathy: Add checking ticket status before performing settlement [Redmine:#33493]
	- 20151005@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
		
Param's Explanation:
		+ @matchid: matchid of match to Refund HT
		+ @IsLoopTempTable: 1 : is nested
							0 : Normal

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @matchcode	NVARCHAR(50)
		,@sporttype		INT
		,@leagueid		INT
		,@sqlCommand	NVARCHAR(500)
		,@mode			VARCHAR(20)
		,@procName		NVARCHAR(50)

	SELECT @matchcode	= m.matchcode
		,@sporttype		= m.sporttype
		,@leagueid		= m.leagueid
	FROM DBPRO.bodb02.dbo.match m WITH (NOLOCK)
	WHERE m.matchid = @MatchId

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 1000001
			,@ErrMsg	= 'Match does not exist!'

		RETURN
	END

	IF EXISTS (
			SELECT 1
			FROM Single_Calculate_Queue WITH (NOLOCK)
			WHERE matchid = @matchid
				AND IsCalculating IN (0, 1)
			)
		OR EXISTS (
			SELECT 1
			FROM Parlay_Calculate_Queue WITH (NOLOCK)
			WHERE matchid = @matchid
				AND IsCalculating IN (0, 1)
			)
	BEGIN
		SELECT @ErrCode = 1000000
			,@ErrMsg	= 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

		RETURN
	END
	
	-- check waiting ticket
				EXEC NAP_Admin_Settlement_Checking
		@MatchId = @MatchId
		,@Action = @Action
		,@Mode = 'REFUND-FGLG'
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrCode
			,@ErrMsg
		
		RETURN
	END

	SELECT @ErrCode		= 0
		,@ErrMsg		= ''
		,@procName		= OBJECT_NAME(@@procid)
		,@mode			= CASE 
								WHEN @action = 'REFUND'	   THEN CASE 
																	WHEN @LastGoalOnly = 1 THEN 'Refund-LG'
																	ELSE 'Refund-FGLG'
																END
								WHEN @action = 'REFUND-FT' THEN CASE 
																	WHEN @LastGoalOnly = 1 THEN 'Refund-FTLG'
																	ELSE 'Refund-FTFGLG'
																END
								WHEN @action = 'REFUND-HT' THEN CASE 
																	WHEN @LastGoalOnly = 1 THEN 'Refund-HTLG'
																	ELSE 'Refund-HTFGLG'
																END
						   END
		,@sqlCommand	= 'EXEC [dbo].[NAP_Admin_Settlement_Refund_FGLG] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
																	+ ', @action = ' + CASE 
																							WHEN @action IS NULL THEN 'REFUND-FT'
																							ELSE '''' + CONVERT(NVARCHAR(50), @action) + ''''
																					   END 
																	+ ', @adminid = ' + CONVERT(NVARCHAR(50), @AdminId) 
																	+ ', @LGOnly= ' + CONVERT(NVARCHAR(1), @LastGoalOnly) 
																	+ ', @IsLoopTempTable = ' + CONVERT(NVARCHAR(1), @IsLoopTempTable) 
																	+ ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
																	+ ', @ErrCode = @ErrCode OUTPUT' 
																	+ ', @ErrMsg = @ErrMsg OUTPUT'

	IF (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- UAT1 -->UAT9
	BEGIN
		DECLARE @fth		SMALLINT
			,@fta 			SMALLINT
			,@hth 			SMALLINT
			,@hta 			SMALLINT
			,@GoalRecord	VARCHAR(50)
			,@BetStatus		NVARCHAR(50)
			,@ActionId		INT

		BEGIN TRY
			EXEC sys.sp_executesql @sqlCommand
				,N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
				,@ErrMsg	= @ErrMsg	OUTPUT
				,@ErrCode	= @ErrCode	OUTPUT
		END TRY

		BEGIN CATCH
			SELECT @ErrMsg	= @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
				,@ErrCode	= @@error

			RETURN
		END CATCH

		SELECT @ActionId	= CASE 
									--WHEN @mode = 'Refund-LG' OR @mode = 'Refund-FTLG' then 18
									--when @mode = 'Refund-FGLG' OR @mode = 'Refund-FTFGLG' THEN 17
									WHEN @mode = 'Refund-FTFGLG' THEN 17
									WHEN @mode = 'Refund-FTLG' THEN 18
									WHEN @mode = 'Refund-HTFGLG' THEN 19
									WHEN @mode = 'Refund-HTLG' THEN 21
									WHEN @mode = 'Refund-FGLG' THEN 20
									WHEN @mode = 'Refund-LG' THEN 22
									ELSE - 1
								END
			,@fth 			= m.finalhomescore
			,@fta 			= m.finalawayscore
			,@hth 			= m.hthomescore
			,@hta 			= m.htawayscore
			,@GoalRecord	= m.GoalRecord
			,@BetStatus 	= m.betstatus
			,@sporttype 	= sporttype
		FROM DBPRO.BODB02.dbo.match m WITH (NOLOCK)
		WHERE m.matchid = @MatchId

		IF @ActionId <> - 1
		BEGIN
			EXEC Acc_Set_ConfirmedAction 
				@matchid 		= @MatchId
				,@action 		= @ActionId
				,@fth 			= @fth
				,@fta 			= @fta
				,@hth 			= @hth
				,@hta 			= @hta
				,@goalrecord	= @GoalRecord
				,@betstatus		= @BetStatus
		END
	END
	ELSE
	BEGIN
		INSERT INTO Single_Calculate_Queue (
			matchid
			,matchcode
			,IsCalculating
			,LeagueID
			,SportType
			,AdminId
			,IP
			,Action
			,sqlCommand
			)
		SELECT @MatchId
			,@matchcode
			,0
			,@leagueid
			,@sporttype
			,@AdminId
			,@IP
			,@mode
			,@sqlCommand
	END
END
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_Refund_FGLG_Push] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_Refund_FGLG_Push] TO [bodbAdminNet]
GO 
