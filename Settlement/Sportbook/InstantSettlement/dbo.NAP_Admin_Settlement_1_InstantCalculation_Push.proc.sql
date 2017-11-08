/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE bodb02
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_1_InstantCalculation_Push] 
	@AdminId 			INT
    , @MatchId			INT
	, @InstantKey		INT
    , @HomeScore		VARCHAR(50)
	, @AwayScore		VARCHAR(50)
    , @Action			VARCHAR(10)
	, @Mode				VARCHAR(10)
	, @ResourceResult	VARCHAR(MAX)	= NULL
    , @IP				VARCHAR(15)     = ''
    , @ErrCode			INT             = 0     OUTPUT
    , @ErrMsg			NVARCHAR(200)   = ''    OUTPUT
AS
/*    
	Creator: 20161004@Bobby
    Task: Implement Instant Calculation
    DB: DBTXN/BODB02
	Original:

    Revisions:
		- 20161128@Bobby: #67760 - Implement IS for FGLG bet types
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		
    Param's Explanation:
		- @Action: ['CAL', 'UNDO']
		- @Mode: ['INST-HT', 'INST-FT']
		- @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>
        
*/
BEGIN
    SET NOCOUNT ON
	
    DECLARE	@matchcode 		NVARCHAR(50)
		, @sporttype 		INT
		, @leagueid 		INT
		, @procName 		NVARCHAR(128)
		, @sqlCommand 		NVARCHAR(1000)
		, @CalculationType	TINYINT
		, @InstantCompleted	BIT
	
	SELECT @CalculationType	= CASE 
								WHEN @Mode = 'INST-HT' THEN 101
								WHEN @Mode = 'INST-FT' THEN 102
								ELSE 0
							END
	SELECT @sporttype 	= m.sporttype
		, @leagueid 	= m.leagueid
		, @matchcode	= m.matchcode
	FROM DBPRO.BODB02.dbo.match m WITH(NOLOCK)
	WHERE m.matchid = @matchid
	
	-- checking for instant match validation
	IF(@Action = 'CAL')
	BEGIN
		EXEC dbo.NAP_Settlement_InstantCalculation_Checking 
		@MatchId 			= @MatchId
		, @InstantKey		= @InstantKey
		, @Action 			= @Action
		, @Mode				= @Mode
        , @ErrCode 			= @ErrCode OUTPUT
        , @ErrMsg 			= @ErrMsg OUTPUT
	END
	ELSE IF (@Action = 'UNDO')
	BEGIN
		--DOUBLE CHECK match status
		EXEC DBPRO.bodb02.dbo.NAP_Settlement_InstantCalculation_UndoChecking
		@MatchId			= @MatchId
		, @InstantCheck		= @InstantKey
		, @ErrCode 			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT
	END
        
    IF (@ErrCode <> 0)
    BEGIN
        RETURN
    END
	
    IF EXISTS (SELECT TOP 1 1
				FROM dbo.Single_Calculate_Queue WITH (NOLOCK)
				WHERE matchid = @matchid
					AND IsCalculating IN (0, 1))
        OR EXISTS (SELECT TOP 1 1
					FROM dbo.Parlay_Calculate_Queue WITH (NOLOCK)
					WHERE matchid = @matchid
						AND IsCalculating IN (0, 1))
    BEGIN
        SELECT @ErrCode = 1001003
			, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

        RETURN
    END
    
    SELECT @ErrCode = 0, @ErrMsg = '', @procName = OBJECT_NAME(@@PROCID)
	
	IF(@Action = 'CAL')
	BEGIN
		SELECT @sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_1_InstantCalculation] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
                            + ', @Creator = ' + CONVERT(NVARCHAR(50), @AdminId) 
                            + ', @Mode = ''' + ISNULL(CONVERT(NVARCHAR(50), @Mode), 'NULL') + ''''
							+ ', @InstantKey = ' + ISNULL(CONVERT(NVARCHAR(50), @InstantKey), 'NULL') + ''
							+ ', @HomeScore = ''' + ISNULL(CONVERT(NVARCHAR(50), @HomeScore), 'NULL') + ''''
							+ ', @AwayScore = ''' + ISNULL(CONVERT(NVARCHAR(50), @AwayScore), 'NULL') + ''''
							+ ', @ResourceResult = ' + CASE 
															WHEN @ResourceResult IS NULL THEN 'NULL'
                                                            ELSE '''' + @ResourceResult + '''' 
														END 
                            + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
                            + ', @ErrCode = @ErrCode OUTPUT' 
                            + ', @ErrMsg = @ErrMsg OUTPUT'
                                                         
	
		--insert into table AutoPayoutResult
		EXEC DBPRO.bodb02.dbo.NAP_Set_AutoPayoutResultIns 
			@MatchId 		= @matchid
			, @SourceId 	= 100
			, @TypeId 		= @CalculationType
			, @InstantKey	= @InstantKey
			, @HomeValue 	= @HomeScore
			, @AwayValue 	= @AwayScore
			, @StatusId 	= 1 --waiting
			, @ErrCode 		= @ErrCode OUTPUT
			, @ErrMsg		= @ErrMsg OUTPUT
		
		IF @ErrCode <> 0
		BEGIN
			RETURN
		END
	END
	ELSE IF(@Action = 'UNDO')
	BEGIN
		SELECT @sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_1_InstantCalculation_Undo] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
                            + ', @Creator = ' + CONVERT(NVARCHAR(50), @AdminId) 
                            + ', @Mode = ''' + ISNULL(CONVERT(NVARCHAR(50), @Mode), 'NULL') + ''''
							+ ', @InstantKey = ' + ISNULL(CONVERT(NVARCHAR(50), @InstantKey), 'NULL') + ''
							+ ', @HomeScore = ''' + ISNULL(CONVERT(NVARCHAR(50), @HomeScore), 'NULL') + ''''
							+ ', @AwayScore = ''' + ISNULL(CONVERT(NVARCHAR(50), @AwayScore), 'NULL') + ''''
							+ ', @ResourceResult = ' + CASE 
															WHEN @ResourceResult IS NULL THEN 'NULL'
                                                            ELSE '''' + @ResourceResult + '''' 
														END 
                            + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
                            + ', @ErrCode = @ErrCode OUTPUT' 
                            + ', @ErrMsg = @ErrMsg OUTPUT'
			, @mode = 'INST-UNDO'
	END
	
	IF LEN(@sqlCommand) > 1000 --Max Field 
    BEGIN
        SELECT @ErrCode = 1001010
			, @ErrMsg  = 'There are too many inputted results to proceed at one time. Please select each one to execute separately.'    
        RETURN 
    END
	
	--SELECT @sqlCommand
	
    IF @procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_' -- UAT1 -->UAT9
    BEGIN
        DECLARE	@ActionId INT

        BEGIN TRY
            EXEC sys.sp_executesql @sqlCommand, N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
                , @ErrMsg	= @ErrMsg OUTPUT
                , @ErrCode	= @ErrCode OUTPUT
        END TRY

        BEGIN CATCH
            SELECT @ErrMsg = @ErrMsg + ISNULL(ERROR_MESSAGE(), ''), @ErrCode = @@ERROR

            RETURN
        END CATCH
    END
    ELSE
    BEGIN
        INSERT INTO dbo.Single_Calculate_Queue (matchid, matchcode, IsCalculating, LeagueID, SportType
			, AdminId, IP, Action, sqlCommand, execTime)
        SELECT @MatchId, @matchcode, 0 AS IsCalculating, @leagueid, @sporttype
			, @AdminId, @IP, @Mode, @sqlCommand, NULL
    END
END

GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_1_InstantCalculation_Push] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_1_InstantCalculation_Push] TO [vnteam] AS [dbo]
GO