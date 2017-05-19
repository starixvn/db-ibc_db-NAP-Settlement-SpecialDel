
USE bodb02
GO

ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Corner_Push] @AdminId INT
	, @Matchid				INT
	, @fthCorners			SMALLINT		= NULL
	, @ftaCorners			SMALLINT		= NULL
	, @hthCorners			SMALLINT		= NULL
	, @htaCorners			SMALLINT		= NULL 
	, @FTFCorner			VARCHAR(1)		= NULL
	, @FTLCorner			VARCHAR(1)		= NULL
	, @HTFCorner			VARCHAR(1)		= NULL
	, @HTLCorner			VARCHAR(1)		= NULL 	
	, @Action				VARCHAR(10)		= 'CAL'
	, @IP					VARCHAR(15)		= ''
	, @ErrCode				INT				= 0		OUTPUT
	, @ErrMsg				NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: Jamie
	Date: 20150618
	Task: Settlement Corner bets ONLY 
	DB: DBTXN/BODB02

	Revisions:		
		- 20151005@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
		- 20160317@Patrick: Auto payout [Redmine: #53262]
		
	Param's Explanation:

		
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @matchcode NVARCHAR(50), @sporttype INT, @leagueid INT, @sqlCommand	NVARCHAR(MAX)
		, @procName NVARCHAR(50), @betstatus NVARCHAR(50)

	SELECT @matchcode = m.matchcode, @sporttype = m.sporttype, @leagueid = m.leagueid, @betstatus = m.betstatus
	FROM DBPRO.bodb02.dbo.match m WITH(NOLOCK)
	WHERE m.matchid = @MatchId

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode	= 1001001 , @ErrMsg	= 'Match does not exist!'
		RETURN
	END

	IF EXISTS (SELECT 1
				FROM dbo.Single_Calculate_Queue s WITH (NOLOCK)
				WHERE s.matchid = @matchid AND s.IsCalculating IN (0, 1)
			) OR EXISTS (
				SELECT 1
				FROM dbo.Parlay_Calculate_Queue p WITH (NOLOCK)
				WHERE p.matchid = @matchid AND p.IsCalculating IN (0, 1))
	BEGIN
		SELECT @ErrCode = 1001003
			, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END

	-- check waiting ticket
	EXEC dbo.NAP_Admin_Settlement_Checking @MatchId = @MatchId
		, @Action = @Action
		, @Mode = 'CAL-CORNER'
		, @ErrCode = @ErrCode OUTPUT
		, @ErrMsg = @ErrMsg OUTPUT
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrCode, @ErrMsg
		RETURN
	END

	SELECT @ErrCode = 0, @ErrMsg = '', @procName = OBJECT_NAME(@@PROCID)
		, @sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_Corner] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
															+ ', @AdminId = ' + CONVERT(NVARCHAR(50), @AdminId)																							
															+ ', @fthCorners = ' + ISNULL(CONVERT(NVARCHAR(50), @fthCorners), 'NULL') 
															+ ', @ftaCorners = ' + ISNULL(CONVERT(NVARCHAR(50), @ftaCorners), 'NULL') 
															+ ', @hthCorners = ' + ISNULL(CONVERT(NVARCHAR(50), @hthCorners), 'NULL') 
															+ ', @htaCorners = ' + ISNULL(CONVERT(NVARCHAR(50), @htaCorners), 'NULL') 
															+ ', @FTFCorner = ' + CASE WHEN @FTFCorner IS NULL THEN 'NULL'	
																						ELSE '''' + @FTFCorner + '''' END 
															+ ', @FTLCorner = ' + CASE WHEN @FTLCorner IS NULL THEN 'NULL'	
																							ELSE '''' + @FTLCorner + '''' END 
															+ ', @HTFCorner = ' + CASE WHEN @HTFCorner IS NULL THEN 'NULL'	
																							ELSE '''' + @HTFCorner + '''' END 
															+ ', @HTLCorner = ' + CASE WHEN @HTLCorner IS NULL THEN 'NULL'	
																							ELSE '''' + @HTLCorner+ '''' END 
															+ ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + '''' 													
															+ ', @IP = ''' + CONVERT(VARCHAR(15), @IP) + '''' 
															+ ', @ErrCode = @ErrCode OUTPUT' 
															+ ', @ErrMsg = @ErrMsg OUTPUT'
														
	IF LEN(@sqlCommand)> 1000 --Max Field 
	BEGIN
		SELECT @ErrCode = 1001010
			, @ErrMsg  = 'There are too many inputted results to proceed at one time. Please select each one to execute separately.'	
		RETURN 
	END
	
	IF (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- UAT1 -->UAT9
	BEGIN
		BEGIN TRY
			EXEC sys.sp_executesql @sqlCommand
				, N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
				, @ErrMsg	= @ErrMsg OUTPUT
				, @ErrCode	= @ErrCode OUTPUT
		END TRY

		BEGIN CATCH
			SELECT @ErrMsg	= @ErrMsg + ISNULL(ERROR_MESSAGE(),''), @ErrCode= @ErrCode
			RETURN
		END CATCH
	END
	ELSE
	BEGIN
		INSERT INTO Single_Calculate_Queue (matchid, matchcode, IsCalculating, LeagueID, SportType, AdminId,IP, Action, sqlCommand)
		SELECT @MatchId, @matchcode, 0, @leagueid, @sporttype, @AdminId, @IP, @Action, @sqlCommand 
	END
END
GO 
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_Corner_Push] TO [vnteam]
GO 
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_Corner_Push] TO [bodbAdminNet]
GO 
