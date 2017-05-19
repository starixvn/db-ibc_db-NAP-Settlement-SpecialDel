USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_1_AutoPayout_Push] @AdminId INT
    , @MatchId		INT
    , @FullTimeHome	SMALLINT        = NULL
    , @FullTimeAway	SMALLINT        = NULL
    , @HalfTimeHome SMALLINT        = NULL
    , @HalfTimeAway SMALLINT        = NULL 
    , @Action		VARCHAR(10)     = 'CAL-FT'
    , @IP			VARCHAR(15)     = ''
    , @ErrCode		INT             = 0     OUTPUT
    , @ErrMsg		NVARCHAR(200)   = ''    OUTPUT
AS
/*    
	Creator: 20160311@Patrick
    Task: Auto Payout settlement
    DB: DBTXN/BODB02
	Original:
		NAP_Admin_Settlement_1_AutoPayout

    Revisions:        
		- 20161028@Kathy: Extend sqlCommand column to varchar(max) [Redmine:#56367]
		- 20170313@Kathy: Remove @betstatus, @goalrecord [Redmine:#73218]
		- 20170314@Kathy: Not allow to process Auto Payout HT/FT if keyscore calculated HT/FT manually [Redmine:#73218]
		
    Param's Explanation:
        
*/
BEGIN
    SET NOCOUNT ON
    
	IF @Action = 'CAL'
	BEGIN
		RETURN --not supported
	END

    DECLARE	@matchcode NVARCHAR(50), @sporttype INT, @leagueid INT, @procName NVARCHAR(50), @sqlCommand NVARCHAR(MAX)
			
    SELECT @matchcode = m.matchcode
		, @sporttype  = m.sporttype
		, @leagueid   = m.leagueid
		, @HalfTimeHome = CASE WHEN @Action = 'CAL-FT' THEN m.hthomescore ELSE @HalfTimeHome END --orveride this value when CAL-FT
		, @HalfTimeAway = CASE WHEN @Action = 'CAL-FT' THEN m.htawayscore ELSE @HalfTimeAway END --orveride this value when CAL-FT
		, @FullTimeHome = CASE WHEN @Action = 'CAL-HT' THEN NULL ELSE @FullTimeHome END--orveride this value
		, @FullTimeAway = CASE WHEN @Action = 'CAL-HT' THEN NULL ELSE @FullTimeAway END--orveride this value
    FROM DBPRO.bodb02.dbo.match m WITH (NOLOCK)
    WHERE m.matchid = @MatchId
	
	IF @@ROWCOUNT = 0
    BEGIN
        SELECT @ErrCode = 1001001
			, @ErrMsg   = 'Match does not exist!'

        RETURN
    END

	IF EXISTS (SELECT TOP 1 1
				FROM DBPRO.bodb02.dbo.ResultDetail with(NOLOCK)
				WHERE matchid = @matchid
					AND 1 = CASE 
								WHEN resourceId = '00' AND @Action = 'CAL-FT' THEN 1
								WHEN resourceId = '01' AND @Action = 'CAL-HT' THEN 1
								ELSE 0
							END
					AND resultStatusId = 5 -- completed (manual)
			)
	BEGIN
		SELECT @ErrCode = 1001018
			, @ErrMsg   = 'Auto payout is cancelled because the match has been calculated manually.'

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
    
    -- check waiting ticket
	EXEC dbo.NAP_Admin_Settlement_Checking @MatchId = @MatchId
        , @Action = @Action
        , @Mode	= 'CAL'
		, @IsExcludeCorner = 1
		, @IsExcludeFGLG = 1
		, @IsAutoCalculatePage = 1
        , @ErrCode = @ErrCode OUTPUT
        , @ErrMsg = @ErrMsg OUTPUT
        
    IF @ErrCode <> 0
    BEGIN
        SELECT	@ErrCode, @ErrMsg
        RETURN
    END

    SELECT @ErrCode = 0, @ErrMsg = '', @procName = OBJECT_NAME(@@PROCID)
		, @sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_1_AutoPayout] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
                            + ', @creator = ' + CONVERT(NVARCHAR(50), @AdminId) 
                            + ', @fth = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeHome), 'NULL') 
                            + ', @fta = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeAway), 'NULL') 
                            + ', @hth = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeHome), 'NULL') 
                            + ', @hta = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeAway), 'NULL') 
                            + ', @action = ''' + CONVERT(NVARCHAR(50), @Action) + '''' 
                            + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
                            + ', @ErrCode = @ErrCode OUTPUT' 
                            + ', @ErrMsg = @ErrMsg OUTPUT'

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
			, @AdminId, @IP, @Action, @sqlCommand, NULL
    END
END

GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_1_AutoPayout_Push] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_1_AutoPayout_Push] TO [vnteam] AS [dbo]
