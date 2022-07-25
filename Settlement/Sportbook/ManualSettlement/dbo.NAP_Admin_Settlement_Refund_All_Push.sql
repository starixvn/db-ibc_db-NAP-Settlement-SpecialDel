/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_All_Push] 
    @Matchid							INT
    ,@AdminId                        	INT
    ,@IsExcludeBetdaq                	BIT            	= 0
    ,@IsSettleAbandonedMatch			BIT            	= 0
    ,@IsExcludeBetfair					BIT            	= 0
    ,@IsSettleAbandonedMatchBetFair		BIT             = 0
    ,@IsSettleAbandonedMatchIBC			BIT             = 0
    ,@HalfTimeHome                    	INT             = NULL
    ,@HalfTimeAway                    	INT             = NULL
    ,@FullTimeHome                    	INT             = NULL
    ,@FullTimeAway                    	INT             = NULL
    ,@GoalSequence                    	VARCHAR(50)     = NULL 
    ,@BetStatus                        	NVARCHAR(50)    = NULL
    ,@IP								VARCHAR(15)    	= ''
    ,@SelectedQuarter					VARCHAR(50)		= NULL
    ,@ResourceResult					VARCHAR(MAX)	= NULL
    ,@IsAutoRefund						BIT				= 0
    ,@ErrCode							INT            	= 0     OUTPUT
    ,@ErrMsg							NVARCHAR(200)   = ''    OUTPUT
    ,@ServiceCommand					NVARCHAR(MAX)	= ''	OUTPUT
AS
/*
    Created: Kathy
    Date: 20140213
    Task : refund tickets 
    Original: 
    DB: DBTXN/BODB02

    Revisions: 
        - 20140304@Kathy: Execute settlement for abandoned/postponed matches- Clean Sheet, Both/One/Neither team to score, To Win To Nil 
        - 20140506@Kathy: Don't allow to calculate exists matches in queue
        - 20140825@Kathy: Support 1H FGLG (127) for Apollo [Redmine:#16276]
        - 20141024@Jamie: Sportting Solution Tennis Settlement [Redmine:#23034]
        - 20150401@Kathy: Add checking ticket status before performing settlement [Redmine:#33493]
        - 20150414@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212]
        - 20151005@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
        - 20160106@Kathy: Integrate Cricket [Redmine:#49727]
        - 20161028@Kathy: Extend sqlCommand column to varchar(max) [Redmine:#56367]
		- 20160824@Bobby: #62921 - Include FGLG (14,127) bet types
        - 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
        - 20170522@Kathy: Correct checking waiting tickets for tennis [Redmine:#76931]
		- 20170321@Bobby: #73407 - CashOut integration
		- 20170704@Kathy: change datatype of betstatus to NVARCHAR(50) [Redmine:#79296]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171115@Kathy: Change datatype of @ServiceCommand to NVARCHAR(MAX) [Redmine:#86735]
		- 20171202@Kathy: Verify whether Instant Settlement has been executed with larger value than suspended score [Redmine:#86890]
		- 20170425@Bobby: 72789 - Implement bonus system into 
		- 20180926@Kathy: Add New Status "Result Pending" and "Under Settlement"  [Redmine:#102028]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20200727@Kathy: Prevent refund wrong match [Redmine:#136390]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20201216@Louisa: Auto refund ET & PEN match [Redmine:#145597]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
		- 20220228@Louisa: Allow insert command into Single_Calculate_Queue by group Action [Redmine:#168497]
		- 20220415@July: Sporttype = 1 return message [Redmine:#171579]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
    • @matchid: matchid need to refund
    • @IsExcludeBetdaq: Is Exclude betdaq tickets or not
    • @IsSettleAbandonedMatch: Is Settlement for Abandoned/postponed match or not
    • @IsExcludeBetfair: Is Exclude betfair tickets or not
    • @IsSettleAbandonedMatchBetFair: Is Settlement for Betfair ticket of Abandoned/postponed match or not
    * List of BetDaq Customers 
                custid    --- username    -    roleid
                50057    ---    BQUS888        -    1
                879241    ---    BQUSMLB        -    1
                103873    ---    BQUSNBA        -    1
                78761    ---    ITibc101    -    1
                1688156    ---    MTEST0101    -    2
                851668  --- BDUS01      -   1
                878902  --- BDUS016     -   1
    * List of Betfair Customers 
                custid    --- username    -    roleid
                2331    ---    BF            -    1
                1077687    ---    BFOS        -    1
    * @isExistTotalCorner: = 1 When existing tickets or result details of corners bettypes 
    * @sqlCommand: just use this output for Cricket - Match Winner
    * @SelectedQuarter: the list of selected quarter for settlement basketball
			'801,802,1H,803,804,2H,FT'
	
	* @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>

	* @IsAutoRefund	= 1 : Auto  Refund Service call SP to refund ET & PEN match
*/
BEGIN
    SET NOCOUNT ON

    DECLARE @matchcode				NVARCHAR(50)
			,@sporttype     		INT
			,@leagueid      		INT		
			,@IsNested      		BIT
			,@Action        		VARCHAR(20)
			,@procName      		NVARCHAR(50)
			,@sqlCommand			NVARCHAR(MAX)
			,@IsExistNetPosition	BIT = 0

			,@Inst_HomeScore		INT
			,@Inst_AwayScore		INT
			,@IsSystemSettlement	BIT

    SELECT	@matchcode    = m.matchcode
			,@sporttype   = m.sporttype
			,@leagueid    = m.leagueid
			,@IsNested    = 0
			
    FROM	dbo.match m WITH (NOLOCK)
    WHERE	m.matchid = @MatchId
	
    IF @@ROWCOUNT = 0
    BEGIN
        SELECT	@ErrCode = 1001001
				,@ErrMsg    = 'Match does not exist!'

        RETURN
    END

	IF @sporttype = 1
	BEGIN
        SELECT	@ErrCode = 1001001
				,@ErrMsg = 'This URL does not support to REFUND for Soccer. PLEASE DO NOT use this URL anymore.'

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
				AND CalculationType = 101
				AND statusId IN (1,2) -- Waiting, Completed
	) s
	WHERE	rn = 1
			
	IF (@HalfTimeHome < @Inst_HomeScore  OR @HalfTimeAway < @Inst_AwayScore	)
	BEGIN
		SELECT @ErrCode = 1001029
            ,@ErrMsg    = 'This match has been executed Instant Settlement with score '+ CAST(@Inst_HomeScore AS VARCHAR) + '-' + CAST(@Inst_AwayScore AS VARCHAR) + '. Please uncalculate it first!'

        RETURN
	END
	
	IF @sporttype = 1
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
			@MatchId	= @matchid
			,@Action	= 'REFUND'
			,@IsAutoRefund = @IsAutoRefund
			,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
			,@ErrCode	= @ErrCode	OUTPUT
			,@ErrMsg	= @ErrMsg	OUTPUT

		IF @ErrCode > 0
		RETURN

		IF EXISTS (
            SELECT TOP 1 1
            FROM Single_Calculate_Queue s WITH (NOLOCK)		
				INNER JOIN dbo.f_Set_GetAction() f
					ON s.Action = f.Action
					AND f.GroupAction = 'MNL'
            WHERE s.matchid = @matchid
                AND s.IsCalculating IN (0, 1)
            )
        OR EXISTS (
            SELECT TOP 1 1
            FROM Parlay_Calculate_Queue WITH (NOLOCK)
            WHERE matchid = @matchid
                AND IsCalculating IN (0, 1)
            )
		BEGIN
			SELECT @ErrCode = 1000000
				,@ErrMsg    = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

			RETURN
		END
	END

	ELSE
	BEGIN
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
			SELECT @ErrCode = 1001003
				,@ErrMsg    = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

			RETURN
		END
	END

    -- check waiting ticket
	EXEC NAP_Admin_Settlement_Checking
        @MatchId = @MatchId
        ,@Action = 'REFUND'
        ,@Mode = 'REFUND'
        ,@SelectedQuarter = @SelectedQuarter
        ,@ErrCode = @ErrCode OUTPUT
        ,@ErrMsg = @ErrMsg OUTPUT
        
    IF @ErrCode <> 0
    BEGIN
        SELECT	@ErrCode
				,@ErrMsg
        
        RETURN
    END
    
    SELECT @ErrCode     = 0
        ,@ErrMsg        = ''
        ,@procName      = OBJECT_NAME(@@procid)
        ,@sqlCommand    = 'EXEC [dbo].[NAP_Admin_Settlement_Refund_All] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
                                                                  + ', @creator = ' + CONVERT(NVARCHAR(50), @AdminId) 
                                                                  + ', @IsExcludeBetdaq = ' + CONVERT(NVARCHAR(1), @IsExcludeBetdaq) 
                                                                  + ', @IsSettleAbandonedMatch = ' + CONVERT(NVARCHAR(1), @IsSettleAbandonedMatch) 
                                                                  + ', @IsExcludeBetfair = ' + CONVERT(NVARCHAR(1), @IsExcludeBetfair) 
                                                                  + ', @IsSettleAbandonedMatchBetFair = ' + CONVERT(NVARCHAR(1), @IsSettleAbandonedMatchBetFair) 
                                                                  + ', @IsSettleAbandonedMatchIBC = ' + CONVERT(NVARCHAR(1), @IsSettleAbandonedMatchIBC) 
                                                                 
                                                                  + ', @betstatus = ' + CASE WHEN @BetStatus IS NULL THEN 'NULL' ELSE '''' + @BetStatus + '''' END 
                                                                  + ', @fth = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeHome), 'NULL') 
                                                                  + ', @fta = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeAway), 'NULL') 
                                                                  + ', @hth = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeHome), 'NULL') 
                                                                  + ', @hta = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeAway), 'NULL')
                                                                  + ', @GoalSequence = ' + CASE WHEN @GoalSequence IS NULL THEN 'NULL' ELSE '''' + @GoalSequence + '''' END   
                                                                  + ', @Action = ''' + 'CAL' + '''' 
                                                                  + ', @SelectedQuarter = ' + CASE WHEN @SelectedQuarter IS NULL THEN 'NULL'
                                                                                     ELSE '''' + @SelectedQuarter + '''' END 
                                                                  + ', @ResourceResult = ' + CASE WHEN @ResourceResult IS NULL THEN 'NULL'
                                                                                     ELSE '''' + @ResourceResult + '''' END 
                                                                  + ', @IsNested = ''' + CONVERT(NVARCHAR(1), @IsNested) + '''' 
                                                                  + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
																  +  CASE WHEN @IsAutoRefund = 1 THEN + ', @IsAutoRefund =' + CONVERT(NVARCHAR(1), @IsAutoRefund ) +''  ELSE '' END
																  + ', @ErrCode = @ErrCode OUTPUT' 
                                                                  + ', @ErrMsg = @ErrMsg OUTPUT'
			,@IsSystemSettlement = CASE
									WHEN @sporttype NOT IN (2) THEN 1
									WHEN @sporttype = 2 AND @SelectedQuarter LIKE '%FT%' THEN 1
									ELSE NULL
								END

    SELECT @Action = 'REFUND'  -- ALL SPORTS

	IF @sporttype = 50 AND EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype = 501)
		SET	@IsExistNetPosition = 1

	-- add new status "Under Settlement" for a match
	IF @IsSystemSettlement IS NOT NULL
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusUpd 
			@Matchid		= @Matchid
			,@Type			= 4
			,@IsEnabled		= @IsSystemSettlement 
			,@AdminId		= @AdminId
			,@IP			= @Ip
	END

    IF @IsExistNetPosition = 0 AND (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- UAT1 -->UAT9
    BEGIN
        BEGIN TRY
            EXEC sys.sp_executesql @sqlCommand
                ,N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
                ,@ErrMsg    = @ErrMsg    OUTPUT
                ,@ErrCode    = @ErrCode    OUTPUT
        END TRY

        BEGIN CATCH
            SELECT @ErrMsg    = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
                ,@ErrCode    = @@error

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
				,@Action -- Refund
				,CASE WHEN @IsExistNetPosition = 1 THEN '' ELSE @sqlCommand END 
				,CASE WHEN @IsExistNetPosition = 1 THEN GETDATE() END
		
		IF @IsExistNetPosition = 1
			SET @ServiceCommand = @sqlCommand -- just use this output for Cricket - Match Winner
    END

END
GO
