/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_RefundFT_Push] 
    @MatchId                        INT
    ,@AdminId                       INT
    ,@IsExcludeBetdaq               BIT         	= 0
    ,@IsSettleAbandonedMatch        BIT         	= 0
    ,@IsExcludeBetfair              BIT         	= 0
    ,@IsSettleAbandonedMatchBetFair BIT         	= 0
    ,@IsSettleAbandonedMatchIBC     BIT         	= 0
    ,@FullTimeHome                  INT         	= NULL
    ,@FullTimeAway                  INT         	= NULL
    ,@GoalSequence                  VARCHAR(50)     = NULL 
    ,@BetStatus                     NVARCHAR(50)    = NULL
    ,@ResourceResult				VARCHAR(MAX)	= NULL
    ,@IP                            VARCHAR(15)    	= ''
    ,@ErrCode                       INT            	= 0			OUTPUT
    ,@ErrMsg                        NVARCHAR(200)   = ''		OUTPUT
    ,@ServiceCommand				NVARCHAR(MAX)	= ''		OUTPUT
AS
/*
    Created: 20140213@Kathy
    Task : Refund Full-time tickets
    DB: DBTXN/BODB02
    Original: 
    
    Revisions:
        - 20140304@Kathy: Execute settlement for abandoned/postponed matches- Clean Sheet, Both/One/Neither team to score, To Win To Nil 
        - 20140506@Kathy: Don't allow to calculate exists matches in queue
        - 20140825@Kathy: Support 1H FGLG (127) for Apollo [Redmine:#16276]
        - 20150401@Kathy: Add checking ticket status before performing settlement [Redmine:#33493]
        - 20150421@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
        - 20151005@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
        - 20160106@Kathy: Integrate Cricket [Redmine:#49727]
        - 20161028@Kathy: Extend sqlCommand column to varchar(max) [Redmine:#56367]
		- 20160824@Bobby: #62921 - Include FGLG (14,127) bet types
		- 20170321@Bobby: #73407 - CashOut integration
		- 20170704@Kathy: change datatype of betstatus to NVARCHAR(50) [Redmine:#79296]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171115@Kathy: Change datatype of @ServiceCommand to NVARCHAR(MAX) [Redmine:#86735]
		- 20171202@Kathy: Verify whether Instant Settlement has been executed with larger value than suspended score [Redmine:#86890]
		- 20170425@Bobby: 72789 - Implement bonus system into 
		- 20180806@Kathy: Verify instant score when refund with SDT [Redmine:#86964]
		- 20180926@Kathy: Add New Status "Result Pending" and "Under Settlement"  [Redmine:#102028]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20200427@Kathy: Check HT ticket before refund FT [Redmine:#131765]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]

    Param's Explanation:
    • @matchid: matchid of match to Refund HT
    • @IsSettleAbandonedMatch: Is Settlement for Abandoned/postponed match or not
    • @IsSettleAbandonedMatchBetFair: Is Settlement for Betfair ticket of Abandoned/postponed match or not
    • @sqlCommand: just use this output for Cricket - Match Winner
    • @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>

*/
BEGIN
    SET NOCOUNT ON

    DECLARE @matchcode				NVARCHAR(50)
			,@sporttype				INT
			,@leagueid				INT
			,@procName				NVARCHAR(50)
			,@Action				VARCHAR(10)
			,@sqlCommand			NVARCHAR(MAX)
			,@IsExistNetPosition	BIT = 0

			,@Inst_HomeScore		INT
			,@Inst_AwayScore		INT
			,@IsHTDone				BIT = 1

    SELECT	@matchcode		= m.matchcode
			,@sporttype     = m.sporttype
			,@leagueid      = m.leagueid
			,@Action        = 'REFUND-FT'
    FROM	dbo.match m WITH (NOLOCK)
    WHERE	m.matchid = @MatchId

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT @ErrCode = 1001001
            ,@ErrMsg    = 'Match does not exist!'

        RETURN
    END

	EXEC DBPRO.bodb02.dbo.NAP_Set_HoldSettingChecking
	@MatchId	= @Matchid
	,@ErrCode	= @ErrCode OUTPUT
	,@ErrMsg	= @ErrMsg OUTPUT

	IF ISNULL(@ErrCode,0) <> 0    
	RETURN

	IF @sporttype = 1
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
			@MatchId	= @matchid
			,@Action	= @Action
			,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
			,@ErrCode	= @ErrCode	OUTPUT
			,@ErrMsg	= @ErrMsg	OUTPUT

		IF @ErrCode > 0
			RETURN
	END

	-- Verify whether Instant Settlement has been executed with larger value than suspended score
	SELECT	@Inst_HomeScore = HomeValue
			,@Inst_AwayScore = AwayValue
	FROM	(
		SELECT	HomeValue
				,AwayValue
				,ROW_NUMBER() OVER (ORDER BY AutoPayoutResultId DESC) AS rn
		FROM	DBPRO.bodb02.dbo.AutoPayoutResult WITH (NOLOCK)
		WHERE	matchid = @Matchid
				AND CalculationType IN (101,102)
				AND StatusId IN (1, 2) -- Waiting, Completed
	) s
	WHERE	rn = 1
			
	IF (@FullTimeHome < @Inst_HomeScore  OR @FullTimeAway < @Inst_AwayScore	) AND @IsSettleAbandonedMatchIBC = 1
	BEGIN
		SELECT @ErrCode = 1001029
            ,@ErrMsg    = 'This match has been executed Instant Settlement with score '+ CAST(@Inst_HomeScore AS VARCHAR) + '-' + CAST(@Inst_AwayScore AS VARCHAR) + '. Please uncalculate it first!'

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
        SELECT @ErrCode = 1001003
            ,@ErrMsg    = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

        RETURN
    END
    
    -- check waiting ticket
    EXEC NAP_Admin_Settlement_Checking
        @MatchId = @MatchId
        ,@Action = @Action
        ,@Mode = 'REFUND'
        ,@ErrCode = @ErrCode OUTPUT
        ,@ErrMsg = @ErrMsg OUTPUT
        
    IF @ErrCode <> 0     
    RETURN

	-- check HT running 
	;WITH cteBettypes
	AS(
		SELECT	b.bettype
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @MatchId
				AND b.statusID = 0
	)
	SELECT	@IsHTDone = 0
	FROM	cteBettypes b
		INNER JOIN dbo.f_Set_GetGroupBettypes() f
			ON b.bettype = f.BetType
	WHERE	f.GroupId IN (1,3)

	IF @IsHTDone = 0
	BEGIN
		SELECT	@ErrCode = 1001031
				,@ErrMsg = 'Error! Cannot proceed due to running Half Time tickets. Please proceed with Half Time settlement and try again.'

		RETURN
	END

    SELECT @ErrCode    = 0
        ,@ErrMsg       = ''
        ,@procName     = OBJECT_NAME(@@procid)
        ,@sqlCommand   = 'EXEC [dbo].[NAP_Admin_Settlement_RefundFT] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
                                                                 + ', @adminid = ' + CONVERT(NVARCHAR(50), @AdminId) 
                                                                 + ', @IsExcludeBetdaq = ' + CONVERT(NVARCHAR(1), @IsExcludeBetdaq) 
                                                                 + ', @IsSettleAbandonedMatch = ' + CONVERT(NVARCHAR(1), @IsSettleAbandonedMatch) 
                                                                 + ', @IsExcludeBetfair = ' + CONVERT(NVARCHAR(1), @IsExcludeBetfair) 
                                                                 + ', @IsSettleAbandonedMatchBetFair = ' + CONVERT(NVARCHAR(1), @IsSettleAbandonedMatchBetFair) 
                                                                 + ', @IsSettleAbandonedMatchIBC = ' + CONVERT(NVARCHAR(1), @IsSettleAbandonedMatchIBC) 
                                                                 + ', @fth = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeHome), 'NULL') 
                                                                 + ', @fta = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeAway), 'NULL') 
                                                                 + ', @GoalSequence = ' + CASE WHEN @GoalSequence IS NULL THEN 'NULL' ELSE 'N''' + CONVERT(NVARCHAR(50), @GoalSequence) + '''' END                                                                 
                                                                 + ', @betstatus = ' + CASE 
                                                                                            WHEN @BetStatus IS NULL THEN 'NULL'
                                                                                            ELSE '''' + @BetStatus + ''''
                                                                                        END 
                                                                 + ', @ResourceResult = ' + CASE WHEN @ResourceResult IS NULL THEN 'NULL'
                                                                                     ELSE '''' + @ResourceResult + '''' END 
                                                                 + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
                                                                 + ', @ErrCode = @ErrCode OUTPUT' 
                                                                 + ', @ErrMsg = @ErrMsg OUTPUT'
    
    IF @sporttype = 50 AND EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype = 501)
		SET	@IsExistNetPosition = 1 

	--  add new status "Under Settlement" for a match
	EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusUpd 
			@Matchid		= @Matchid
			,@Type			= 4
			,@IsEnabled		= 1 
			,@AdminId		= @AdminId
			,@IP			= @Ip

    IF @IsExistNetPosition = 0 AND (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- UAT1 -->UAT9
    BEGIN
        BEGIN TRY
            EXEC sys.sp_executesql @sqlCommand
                ,N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
                ,@ErrMsg    = @ErrMsg    OUTPUT
                ,@ErrCode    = @ErrCode    OUTPUT
        END TRY

        BEGIN CATCH
            SELECT	@ErrMsg    = @ErrMsg + ERROR_MESSAGE()
					,@ErrCode  = @@error

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
        SELECT @MatchId
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