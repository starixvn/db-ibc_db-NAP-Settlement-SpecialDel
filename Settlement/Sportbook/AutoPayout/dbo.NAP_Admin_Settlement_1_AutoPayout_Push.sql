/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_1_AutoPayout_Push] 
	@AdminId 		INT
    , @MatchId		INT
    , @FullTimeHome	SMALLINT        = NULL
    , @FullTimeAway	SMALLINT        = NULL
    , @HalfTimeHome SMALLINT        = NULL
    , @HalfTimeAway SMALLINT        = NULL 
    , @Action		VARCHAR(10)     = 'CAL-FT'
    , @IP			VARCHAR(15)     = ''
	, @IsReSettledTickets	BIT		= 1
	, @GoalRecord	VARCHAR(50)		= ''
	, @BetStatus	NVARCHAR(50)	= ''
	, @ResourceResult VARCHAR(MAX)	= NULL
	, @SourceId		TINYINT			= 5 -- default SoccerWay
	, @RefResult	VARCHAR(500)	= NULL
	, @SessionId	BIGINT			= 0
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
		- 20170316@Bobby: Integrate CashOut bettypes [Redmine:#73404]
		- 20170424@Bobby: 72789 - Implement bonus system into NAP Settlement
		- 20180926@Kathy: Add New Status "Result Pending" and "Under Settlement"  [Redmine:#102028]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190425@Sol: Auto Payout Phase 3 [Redmine:#116073]
		- 20190919@Sol: Incorporate PHAIO 4b - 27 Corners Bet Types - Removed @IsExcludeCorner [Redmine:#115232]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20201216@Louisa: Auto refund ET & PEN match [Redmine:#145597]
		- 20210311@Max: Auto Payout for Table Tennis [Redmine: #143442]
		- 20210809@Kathy: Settle by custid [Redmine:159486]
		- 20220228@Louisa: Allow insert command into Single_Calculate_Queue by group Action [Redmine:#168497]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220520@Louisa: Direct Settlement for HT & FT on Some Saba Virtual Soccer Leagues [Redmine:#172907]
		- 20220613@Louisa: Auto Payout for matches TOTAL CORNER & TOTAL GOAL [Redmine:#171261]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
        
*/
BEGIN
    SET NOCOUNT ON

    DECLARE	@matchcode				NVARCHAR(50)
			,@sporttype				INT
			,@leagueid				INT
			,@procName				NVARCHAR(50)
			,@sqlCommand			NVARCHAR(MAX)
			,@IsSystemSettlement	BIT
			,@HomeValue				VARCHAR(50)
			,@AwayValue				VARCHAR(50)
			,@LeagueGroupID			SMALLINT
			,@KeyId					INT
			,@xmlResourceResult		XML
	
	SET @xmlResourceResult = CAST(@ResourceResult AS XML)

	SELECT  @HomeValue = CASE WHEN @Action = 'CAL-HT' THEN @HalfTimeHome 
								WHEN @Action = 'CAL-FT' THEN @FullTimeHome
								WHEN @Action = 'CAL' THEN @FullTimeHome
								ELSE 0 
							END,
			@AwayValue = CASE WHEN @Action = 'CAL-HT' THEN @HalfTimeAway 
								WHEN @Action = 'CAL-FT' THEN @FullTimeAway
								WHEN @Action = 'CAL' THEN @FullTimeAway
								ELSE 0 
							END

    SELECT @matchcode = m.matchcode
		, @sporttype  = m.sporttype
		, @leagueid   = m.leagueid
		, @HalfTimeHome = CASE WHEN @Action = 'CAL-FT' THEN m.hthomescore ELSE @HalfTimeHome END --orveride this value when CAL-FT
		, @HalfTimeAway = CASE WHEN @Action = 'CAL-FT' THEN m.htawayscore ELSE @HalfTimeAway END --orveride this value when CAL-FT
		, @FullTimeHome = CASE WHEN @Action = 'CAL-HT' THEN NULL ELSE @FullTimeHome END--orveride this value
		, @FullTimeAway = CASE WHEN @Action = 'CAL-HT' THEN NULL ELSE @FullTimeAway END--orveride this value
		, @LeagueGroupID = ISNULL(l.LeagueGroupID, 0)
    FROM DBPRO.bodb02.dbo.match m WITH (NOLOCK)
		INNER JOIN DBPRO.bodb02.dbo.League l WITH (NOLOCK)
			ON m.leagueid = l.leagueid
    WHERE m.matchid = @MatchId
 
    SELECT @ErrCode = 0, @ErrMsg = '', @procName = OBJECT_NAME(@@PROCID)
		, @sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_1_AutoPayout] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
                            + ', @creator = ' + CONVERT(NVARCHAR(50), @AdminId) 
                            + ', @fth = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeHome), 'NULL') 
                            + ', @fta = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeAway), 'NULL') 
                            + ', @hth = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeHome), 'NULL') 
                            + ', @hta = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeAway), 'NULL') 
                            + ', @action = ''' + CONVERT(NVARCHAR(50), @Action) + '''' 
                            + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
							+ ', @IsReSettledTickets = ' + CONVERT(NVARCHAR(1), @IsReSettledTickets) 
							+ ', @goalrecord = '+ CASE WHEN @GoalRecord IS NULL THEN 'NULL' ELSE '''' + CONVERT(NVARCHAR(50),@GoalRecord)+ '''' END 
							+ ', @betstatus = ' + CASE WHEN @BetStatus IS NULL THEN 'NULL' ELSE 'N''' + CONVERT(NVARCHAR(50),@BetStatus)+ '''' END 
							+ ', @ResourceResult = ' + CASE WHEN @ResourceResult IS NULL THEN 'NULL'
											ELSE '''' + @ResourceResult + '''' END 
							+ ', @SourceId = ' + CONVERT(NVARCHAR(3), @SourceId)
							+ CASE WHEN @RefResult IS NOT NULL THEN ',@RefResult = ''' + CONVERT(NVARCHAR(500),@RefResult) +  ''''
											ELSE '' END
                            + ', @ErrCode = @ErrCode OUTPUT' 
                            + ', @ErrMsg = @ErrMsg OUTPUT'
		,@IsSystemSettlement = CASE
								WHEN @Action IN ('CAL-FT', 'CAL') THEN 1
								ELSE NULL
							END
							
	-- add new status "Under Settlement" for a match
	IF @IsSystemSettlement IS NOT NULL
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusUpd 
			@Matchid		= @Matchid
			,@Type			= 4
			,@IsEnabled		= @IsSystemSettlement 
			,@AdminId		= @AdminId
	END

	IF @sporttype = 1 AND @Action = 'CAL-FT' AND @LeagueGroupID IN (42,74,108) AND ISNULL(@FullTimeHome,0) <> ISNULL(@FullTimeAway,0)
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_AutoRefund_ResultIns  @ParentId = @MatchId
	END

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
        INSERT INTO dbo.Single_Calculate_Queue (matchid, matchcode
			, IsCalculating
			, LeagueID, SportType
			, AdminId, IP, Action, sqlCommand, execTime)
        SELECT @MatchId, @matchcode
			, CASE WHEN @sporttype = 1 THEN 99 ELSE 0 END
			, @leagueid, @sporttype
			, @AdminId, @IP, @Action, @sqlCommand, NULL

		SET @KeyId = SCOPE_IDENTITY()

		IF @sporttype = 1
			UPDATE Single_Calculate_Queue 
				SET sqlCommand = @sqlCommand + ', @KeyId = ' + CAST(@KeyId AS VARCHAR)
					,IsCalculating = 0
			WHERE	keyid = @KeyId
    END

END

GO

