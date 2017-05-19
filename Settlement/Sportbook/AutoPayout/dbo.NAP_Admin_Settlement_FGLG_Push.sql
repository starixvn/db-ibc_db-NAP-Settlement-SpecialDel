/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_FGLG_Push] @AdminId INT
	, @action VARCHAR(10) = 'CAL-FT' -- CAL-FT, CAL-HT
	, @MatchId INT
	, @BetStatus NVARCHAR(50)
	, @IncludeLastGoal BIT = 0
	, @IP VARCHAR(15) = ''
	, @goalrecord VARCHAR(50) = ''
	, @IsLoopTempTable BIT = 0
	, @IsAutoCalculatePage BIT = 0
	, @ErrCode INT = 0 OUTPUT
	, @ErrMsg NVARCHAR(200) = '' OUTPUT
	
AS
/*	Creator: Kathy
	Date: 20140213
	Task: SP for settle FGLG
	DB: DBTXN/BODB02
	
	Revisions:
		- 20140506@Kathy: Don't allow to calculate exists matches in queue
		- 20140507@Kathy: Add param @action (for bettype 1H FGLG (127)) [Redmine:#14449]
		- 20140825@Kathy: Support 1H FGLG (127) for Apollo [Redmine:#16276]
		- 20151005@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
		- 20160315@Patrick: Auto payout [Redmine: #53262]
		- 20160905@Bobby: #63553 - Include FGLG (14,127) bet types
		
	Param's Explanation:
		+ @betstatus: FGLG status
		+ @IsLoopTempTable: 1 : is nested
							0 : Normal
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @matchcode NVARCHAR(50), @sporttype INT, @leagueid INT
		, @sqlCommand NVARCHAR(500), @mode VARCHAR(20), @procName NVARCHAR(50)

	SELECT @matchcode = m.matchcode, @sporttype = m.sporttype, @leagueid = m.leagueid
	FROM DBPRO.bodb02.dbo.match m with(NOLOCK)
	WHERE m.matchid = @MatchId

	IF @@ROWCOUNT = 0 
	BEGIN
		SELECT @ErrCode	= 1000001, @ErrMsg = 'Match does not exist!'
		RETURN
	END

	IF EXISTS (SELECT 1 from dbo.Single_Calculate_Queue with(NOLOCK) WHERE matchid = @matchid AND IsCalculating IN (0,1) )
		OR EXISTS (SELECT 1 from dbo.Parlay_Calculate_Queue with(NOLOCK) WHERE matchid = @matchid AND IsCalculating IN (0,1))
	BEGIN
		SELECT @ErrCode = 1000000
			, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'	
		RETURN
	END 
	
	-- check waiting ticket
	EXEC dbo.NAP_Admin_Settlement_Checking @MatchId = @MatchId
		, @Action = @Action
		, @Mode = 'CAL-FGLG'
		, @IsAutoCalculatePage = @IsAutoCalculatePage
		, @ErrCode = @ErrCode OUTPUT
		, @ErrMsg = @ErrMsg OUTPUT
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrCode, @ErrMsg
		RETURN
	END 

	SELECT @ErrCode = 0
		, @ErrMsg = ''
		, @mode = CASE WHEN @action = 'CAL-FT' THEN CASE WHEN @IncludeLastGoal = 0 THEN 'CAL-FTFGLG' 
													ELSE 'CAL-FTLG' END
						ELSE CASE WHEN @IncludeLastGoal = 0 THEN 'CAL-HTFGLG'
							ELSE 'CAL-HTLG'	END
				    END 
		, @procName = OBJECT_NAME(@@PROCID)
		, @sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_FGLG] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
			+ ', @action = ' + CASE WHEN @action IS NULL THEN 'CAL-FT' ELSE '''' + CONVERT(NVARCHAR(50), @action) + '''' END 
			+ ', @creator = ' + CONVERT(NVARCHAR(50), @AdminId) 
			+ ', @goalrecord = '+ CASE when @GoalRecord IS NULL THEN 'NULL' ELSE '''' + CONVERT(nvarchar(50),@GoalRecord)+ '''' END 
			+ ', @betstatus = ' + CASE when @BetStatus IS NULL THEN 'NULL' ELSE 'N''' + CONVERT(nvarchar(50),@BetStatus)+ '''' END 
			+ ', @IncludeLG = ' + CONVERT(NVARCHAR(1), @IncludeLastGoal) 
			+ ', @IsAutoCalculatePage = ' + CONVERT(NVARCHAR(1), @IsAutoCalculatePage) 
			+ ', @IsLoopTempTable = ' + CONVERT(NVARCHAR(1), @IsLoopTempTable) 
			+ ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
			+ ', @ErrCode = @ErrCode OUTPUT' 
			+ ', @ErrMsg = @ErrMsg OUTPUT' 

	IF (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- UAT1 -->UAT9
	BEGIN
		
		BEGIN TRY
			EXEC sys.sp_executesql @sqlCommand, N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
				, @ErrMsg = @ErrMsg OUTPUT
				, @ErrCode = @ErrCode OUTPUT
		END TRY

		BEGIN CATCH
			SELECT @ErrMsg = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
				, @ErrCode = @@ERROR
			RETURN
		END CATCH
		
	END
	ELSE
	BEGIN
		INSERT INTO dbo.Single_Calculate_Queue(matchid, matchcode, IsCalculating, LeagueID, SportType, AdminId, IP, Action, sqlCommand)
		SELECT @MatchId, @matchcode, 0, @leagueid, @sporttype, @AdminId, @IP, @action, @sqlCommand
	END
END
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_FGLG_Push] TO [vnteam]
GO 
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_FGLG_Push] TO [bodbAdminNet]
GO 
