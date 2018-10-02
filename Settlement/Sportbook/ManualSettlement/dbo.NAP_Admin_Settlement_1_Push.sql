/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_1_Push] 
     @AdminId               INT
    ,@Matchid               INT
    ,@FullTimeHome          SMALLINT        = NULL
    ,@FullTimeAway          SMALLINT        = NULL
    ,@HalfTimeHome          SMALLINT        = NULL
    ,@HalfTimeAway          SMALLINT        = NULL 
    ,@GoalRecord			VARCHAR(50)     = NULL
    ,@BetStatus             NVARCHAR(50)    
    ,@SetResult             VARCHAR(50)     = NULL 
    ,@GameResult1           VARCHAR(MAX)    = NULL
    ,@GameResult2           VARCHAR(MAX)    = NULL
    ,@GameResult3           VARCHAR(MAX)    = NULL
    ,@GameResult4           VARCHAR(MAX)    = NULL
    ,@GameResult5           VARCHAR(MAX)    = NULL
    ,@SelectedSet           VARCHAR(50)     = NULL 
    ,@SelectedSet1Game      VARCHAR(MAX)    = NULL 
    ,@SelectedSet2Game      VARCHAR(MAX)    = NULL 
    ,@SelectedSet3Game      VARCHAR(MAX)    = NULL 
    ,@SelectedSet4Game      VARCHAR(MAX)    = NULL 
    ,@SelectedSet5Game      VARCHAR(MAX)    = NULL 
    ,@fthCorners            SMALLINT        = NULL
    ,@ftaCorners            SMALLINT        = NULL
    ,@hthCorners            SMALLINT        = NULL
    ,@htaCorners            SMALLINT        = NULL 
    ,@FTFCorner             VARCHAR(1)      = NULL
    ,@FTLCorner             VARCHAR(1)      = NULL
    ,@HTFCorner             VARCHAR(1)      = NULL
    ,@HTLCorner             VARCHAR(1)      = NULL     
    ,@isExcludeCorner       BIT             = 0 
    ,@SelectedQuarter		VARCHAR(50)		= NULL
    ,@QuarterResult			VARCHAR(MAX)	= NULL
    ,@ResourceResult		VARCHAR(MAX)	= NULL
    ,@Action                VARCHAR(10)     = 'CAL'
    ,@IP                    VARCHAR(15)     = ''
    
    ,@ErrCode               INT             = 0     OUTPUT
    ,@ErrMsg                NVARCHAR(200)   = ''    OUTPUT
	,@ServiceCommand		NVARCHAR(MAX)	= ''	OUTPUT
AS
/*    Creator: Kathy
    Date: 20140213
    Task: SP for settlement
    DB: DBTXN/BODB02

    Revisions:        
        - 20140506@Kathy: Don't allow to calculate exists matches in queue
        - 20140825@Kathy: Support 1H FGLG (127) for Apollo [Redmine:#16276]
        - 20141013@Jamie: Sporting Solution for Tennis [Redmine:#23034]
        - 20150401@Kathy: Add checking ticket status before performing settlement [Redmine:#33493]
        - 20150406@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212]
        - 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
        - 20151005@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
        - 20160106@Kathy: Integrate Cricket [Redmine:#49727]
		- 20160317@Patrick: Auto payout [Redmine: #53262]
		- 20161028@Kathy: Extend sqlCommand column to varchar(max) [Redmine:#56367]
        - 20160824@Bobby: #62921 - Include FGLG (14,127) bet types
        - 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
        - 20170522@Kathy: Correct checking waiting tickets for tennis [Redmine:#76931]
        - 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171115@Kathy: Change datatype of @ServiceCommand to NVARCHAR(MAX) [Redmine:#86735]
		- 20170421@Bobby: 72789 - Implement bonus system into NAP Settlement
		- 20180926@Kathy: Add New Status "Result Pending" and "Under Settlement"  [Redmine:#102028]

    Param's Explanation:
		* @sqlCommand: just use this output for Cricket - Match Winner
		
		* @SelectedQuarter: the list of selected quarter for settlement basketball
			'801,802,1H,803,804,2H,FT'
		* @QuarterResult: the result of each quarter bettype of basketball
			Sample:	'<Results>
					   <Resource Id="603" HomeValue="H"/> 
					   <Resource Id="604" HomeValue="H"/> 
					   <Resource Id="Q1" HomeValue="30" AwayValue="40"/> 
					 </Results>
		* @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>
        
*/
BEGIN
    SET NOCOUNT ON

    DECLARE	@matchcode          	NVARCHAR(50)
			,@sporttype         	INT
			,@leagueid          	INT
			,@procName          	NVARCHAR(50)
			,@sqlCommand			NVARCHAR(MAX)
			,@IsExistNetPosition	BIT = 0		
			,@IsUnderSettlement		BIT

    SELECT	@matchcode = m.matchcode
			,@sporttype   = m.sporttype
			,@leagueid    = m.leagueid
    FROM	dbo.match m WITH (NOLOCK)
    WHERE	m.matchid = @MatchId

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT	@ErrCode = 1001001
				,@ErrMsg    = 'Match does not exist!'

        RETURN
    END

    IF @action = 'CAL' AND @sporttype = 154 AND (@FullTimeHome = 0 OR @FullTimeHome IS NULL OR @FullTimeAway = 0 OR @FullTimeAway IS NULL)
    BEGIN
        SELECT	@ErrCode = 1001002
				,@ErrMsg    = 'Score is not valid.'

        RETURN
    END

    IF EXISTS (
            SELECT	1
            FROM	Single_Calculate_Queue WITH (NOLOCK)
            WHERE	matchid = @matchid
					AND IsCalculating IN (0, 1)
            )
        OR EXISTS (
            SELECT	1
            FROM	Parlay_Calculate_Queue WITH (NOLOCK)
            WHERE	matchid = @matchid
					AND IsCalculating IN (0, 1)
            )
    BEGIN
        SELECT	@ErrCode = 1001003
				,@ErrMsg    = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

        RETURN
    END
    
    -- check waiting ticket		
	EXEC dbo.NAP_Admin_Settlement_Checking @MatchId	= @MatchId
    , @Action = @Action
    , @Mode = 'CAL'
	, @IsExcludeCorner = @isExcludeCorner
	, @SelectedQuarter = @SelectedQuarter
	, @SelectedSet = @SelectedSet
    , @ErrCode = @ErrCode OUTPUT
    , @ErrMsg = @ErrMsg OUTPUT
        
    IF @ErrCode <> 0
    BEGIN
        SELECT	@ErrCode
				,@ErrMsg
        
        RETURN
    END

    SELECT	@ErrCode        = 0
			,@ErrMsg        = ''
			,@procName      = OBJECT_NAME(@@procid)
			,@sqlCommand    = 'EXEC [dbo].[NAP_Admin_Settlement_1] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
                                                          + ', @creator = ' + CONVERT(NVARCHAR(50), @AdminId) 
                                                          + ', @fth = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeHome), 'NULL') 
                                                          + ', @fta = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeAway), 'NULL') 
                                                          + ', @hth = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeHome), 'NULL') 
                                                          + ', @hta = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeAway), 'NULL') 
                                                          + ', @goalrecord = ' + CASE WHEN @GoalRecord IS NULL THEN 'NULL'
                                                                                      ELSE '''' + CONVERT(NVARCHAR(50), @GoalRecord) + '''' END 
                                                          + ', @betstatus = ' + CASE WHEN @BetStatus IS NULL THEN 'NULL' 
                                                                                     ELSE 'N''' + CONVERT(NVARCHAR(50), @BetStatus) + '''' END 
                                                          + ', @SetResult = ' + CASE WHEN @SetResult IS NULL THEN 'NULL'
                                                                                     ELSE '''' + @SetResult + '''' END 
                                                          + ', @GameResult1 = ' + CASE WHEN @GameResult1 IS NULL THEN 'NULL'
                                                                                       ELSE '''' + @GameResult1 + '''' END 
                                                          + ', @GameResult2 = ' + CASE WHEN @GameResult2 IS NULL THEN 'NULL'    
                                                                                       ELSE '''' + @GameResult2+ '''' END 
                                                          + ', @GameResult3 = ' + CASE WHEN @GameResult3 IS NULL THEN 'NULL'    
                                                                                       ELSE '''' + @GameResult3+ '''' END  
                                                          + ', @GameResult4 = ' + CASE WHEN @GameResult4 IS NULL THEN 'NULL'    
                                                                                       ELSE '''' + @GameResult4+ '''' END 
                                                          + ', @GameResult5 = ' + CASE WHEN @GameResult5 IS NULL THEN 'NULL'    
                                                                                       ELSE '''' + @GameResult5+ '''' END 
                                                          + ', @SelectedSet = ' + CASE WHEN @SelectedSet IS NULL THEN 'NULL'    
                                                                                       ELSE '''' + @SelectedSet+ '''' END 
                                                          + ', @SelectedSet1Game = ' + CASE WHEN @SelectedSet1Game IS NULL THEN 'NULL'    
                                                                                       ELSE '''' + @SelectedSet1Game+ '''' END 
                                                          + ', @SelectedSet2Game = ' + CASE WHEN @SelectedSet2Game IS NULL THEN 'NULL'    
                                                                                       ELSE '''' + @SelectedSet2Game+ '''' END
                                                          + ', @SelectedSet3Game = ' + CASE WHEN @SelectedSet3Game IS NULL THEN 'NULL'    
                                                                                       ELSE '''' + @SelectedSet3Game+ '''' END 
                                                          + ', @SelectedSet4Game = ' + CASE WHEN @SelectedSet4Game IS NULL THEN 'NULL'    
                                                                                       ELSE '''' + @SelectedSet4Game+ '''' END 
                                                          + ', @SelectedSet5Game = ' + CASE WHEN @SelectedSet5Game IS NULL THEN 'NULL'    
                                                                                       ELSE '''' + @SelectedSet5Game+ '''' END  

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
                                                          + ', @isExcludeCorner = ' + ISNULL(CONVERT(NVARCHAR(50), @isExcludeCorner), '0') 
                                                          + ', @action = ''' + CONVERT(NVARCHAR(50), @Action) + '''' 
                                                          + ', @SelectedQuarter = ' + CASE WHEN @SelectedQuarter IS NULL THEN 'NULL'
                                                                                     ELSE '''' + @SelectedQuarter + '''' END 
														  + ', @QuarterResult = ' + CASE WHEN @QuarterResult IS NULL THEN 'NULL'
                                                                                     ELSE '''' + @QuarterResult + '''' END 
														  + ', @ResourceResult = ' + CASE WHEN @ResourceResult IS NULL THEN 'NULL'
                                                                                     ELSE '''' + @ResourceResult + '''' END 
                                                          + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
                                                          + ', @ErrCode = @ErrCode OUTPUT' 
                                                          + ', @ErrMsg = @ErrMsg OUTPUT'
                                                          
				,@IsUnderSettlement = CASE
										WHEN @Action = 'UNDO' 
											THEN CASE 
													WHEN @sporttype NOT IN (2,5) THEN 0
													WHEN @sporttype = 2 AND @SelectedQuarter LIKE '%FT%' THEN 0
													WHEN @sporttype = 5 AND @SelectedSet LIKE '%6%' THEN 0
													ELSE NULL
												END
										WHEN @Action IN ('CAL', 'CAL-FT') 
											THEN CASE
													WHEN @sporttype NOT IN (2,5) THEN 1
													WHEN @sporttype = 2 AND @SelectedQuarter LIKE '%FT%' THEN 1
													WHEN @sporttype = 5 AND @SelectedSet LIKE '%6%'	THEN 1
													ELSE NULL
												END
										ELSE NULL
									END


    IF (@SelectedSet IS NOT NULL AND @SelectedSet NOT LIKE '%6%')   -- Tennis 
    BEGIN
        SELECT	@Action='CAL-SET'    -- CAL per SET of Tennis         
    END 

	IF @sporttype = 50 AND EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype = 501)
		SET	@IsExistNetPosition = 1 
		
	-- add new status "Under Settlement" for a match
	IF @IsUnderSettlement IS NOT NULL 
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusUpd 
			@Matchid		= @Matchid
			,@Type			= 3
			,@IsEnabled		= @IsUnderSettlement 
			,@AdminId		= @AdminId
	END

    IF @IsExistNetPosition = 0 AND (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- UAT1 -->UAT9
    BEGIN
        BEGIN TRY
            EXEC sys.sp_executesql @sqlCommand
                ,N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
                ,@ErrMsg		= @ErrMsg OUTPUT
                ,@ErrCode		= @ErrCode OUTPUT
        END TRY

        BEGIN CATCH
            SELECT	@ErrMsg   = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
					,@ErrCode = @@error

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
				,execTime
            )
        SELECT	@MatchId
				,@matchcode
				,CASE WHEN @IsExistNetPosition = 1 THEN 1 ELSE 0 END
				,@leagueid
				,@sporttype
				,@AdminId
				,@IP
				,@Action
				,CASE WHEN @IsExistNetPosition = 1 THEN '' ELSE @sqlCommand END
				,CASE WHEN @IsExistNetPosition = 1 THEN GETDATE() END
				
		IF @IsExistNetPosition = 1
			SET @ServiceCommand = @sqlCommand -- just use this output for Cricket - Match Winner
    END
END
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_1_Push] TO [bodbAdminNet]
GO
