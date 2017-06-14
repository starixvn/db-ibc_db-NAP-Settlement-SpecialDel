/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_2b_Push]
	 @AdminId			INT				
	,@MatchId			INT
	,@QuarterResult		VARCHAR(MAX)	 
	,@Action			VARCHAR(10)		= 'CAL'
	
	,@IP				VARCHAR(15)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: 20170609@Kathy
	Task: Early Settlement for BAIO [Redmine:#77835]
	DB: DBTXN/BODB02
	
	Revisions:
		- 20170613@Kathy: Early Settlement [Redmine:#77835] 
		
	Param's Explanation:
		* @QuarterResult: the result of each quarter bettype of basketball
			Sample:	'<Results>
					   <Resource Id="604" HomeValue="H"/> 
					   <Resource Id="606" HomeValue="H"/> 
					 </Results>
*/		
BEGIN
	SET NOCOUNT ON 

	DECLARE	 @matchcode		NVARCHAR(50)
			,@sporttype		INT
			,@leagueid		INT
			,@sqlCommand	NVARCHAR(MAX)
			,@procName		NVARCHAR(50)

	SELECT	 @matchcode		= m.matchcode
			,@sporttype		= m.sporttype
			,@leagueid		= m.leagueid
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT	 @ErrCode	= 1001001
				,@ErrMsg	= 'Match does not exist!'

		RETURN
	END

	IF EXISTS (
			SELECT 1
			FROM Single_Calculate_Queue s WITH (NOLOCK)
			WHERE s.matchid = @matchid 
			AND s.IsCalculating IN (0, 1)
			) OR EXISTS (
			SELECT 1
			FROM Parlay_Calculate_Queue p WITH (NOLOCK)
			WHERE p.matchid = @matchid 
			AND p.IsCalculating IN (0, 1)
			)
	BEGIN
		SELECT	 @ErrCode = 1001003
				,@ErrMsg	= 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

		RETURN
	END

	-- check waiting ticket
	EXEC NAP_Admin_Settlement_Checking
		@MatchId = @MatchId
		,@Action = @Action
		,@Mode = 'CAL-EARLY'
		,@xmlData = @QuarterResult
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrCode
			,@ErrMsg
		
		RETURN
	END

	SELECT	 @ErrCode		= 0
			,@ErrMsg		= ''
			,@procName		= OBJECT_NAME(@@procid)
			,@sqlCommand	= 'EXEC [dbo].[NAP_Admin_Settlement_2b] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
															+ ', @AdminId = ' + CONVERT(NVARCHAR(50), @AdminId) 														
															+ ', @QuarterResult = ''' + CONVERT(VARCHAR(MAX), @QuarterResult) + ''''
															+ ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + '''' 								
															+ ', @IP = ''' + CONVERT(VARCHAR(15), @IP) + '''' 
															+ ', @ErrCode = @ErrCode OUTPUT' 
															+ ', @ErrMsg = @ErrMsg OUTPUT'
														
	IF (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- UAT1 -->UAT9
	BEGIN
		BEGIN TRY
			EXEC sys.sp_executesql @sqlCommand
				,N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
				,@ErrMsg	= @ErrMsg OUTPUT
				,@ErrCode	= @ErrCode OUTPUT
		END TRY

		BEGIN CATCH
			SELECT  @ErrMsg	= @ErrMsg + ISNULL(ERROR_MESSAGE(),'')
				   ,@ErrCode= @ErrCode
			RETURN
		END CATCH
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
			,'CAL-EARLY'
			,@sqlCommand
	END

END
GO 
