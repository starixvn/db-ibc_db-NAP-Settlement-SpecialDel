/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_RefundHT_Push] 
    @MatchId                        INT
    ,@AdminId                       INT
    ,@IsExcludeBetdaq               BIT             = 0
    ,@IsSettleAbandonedMatch        BIT             = 0
    ,@IsExcludeBetfair              BIT             = 0
    ,@IsSettleAbandonedMatchBetFair BIT             = 0
    ,@HalfTimeHome                	INT             = NULL
    ,@HalfTimeAway                	INT             = NULL
    ,@ResourceResult				VARCHAR(MAX)	= NULL
    ,@IP                            VARCHAR(15)   	= ''
    ,@ErrCode                       INT           	= 0     OUTPUT
    ,@ErrMsg                        NVARCHAR(200)   = ''    OUTPUT
AS
/*
    Created: 20130213@Kathy
    Task : Refund Half-time in case there are HT tickets bet on special matches that have 3 sets
    DB: DBTXN/BODB02

    Revisions:
        - 20140506@Kathy: Don't allow to calculate exists matches in queue
        - 20140825@Kathy: Support 1H FGLG (127) for Apollo [Redmine:#16276]
        - 20150401@Kathy: Add checking ticket status before performing settlement [Redmine:#33493
        - 20150422@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212] 
        - 20151005@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
		- 20160905@Bobby: #63553 - Include FGLG (14,127) bet types
		- 20170321@Bobby: #73407 - CashOut integration
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20170425@Bobby: 72789 - Implement bonus system into NAP Settlement
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20190813@Helen: Remove vnteam in metadata
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
		- 20220228@Louisa: Allow insert command into Single_Calculate_Queue by group Action [Redmine:#168497]

    Param's Explanation:
    • @matchid: matchid of match to Refund HT
    • @IsExcludeBetdaq: Is Exclude betdaq tickets or not
    • @IsSettleAbandonedMatch: Is Settlement for Betdaq ticket of Abandoned/postponed match or not
    • @IsExcludeBetfair: Is Exclude betfair tickets or not
    • @IsSettleAbandonedMatchBetFair: Is Settlement for Betfair ticket of Abandoned/postponed match or not
	• @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>

*/
BEGIN
    SET NOCOUNT ON

    DECLARE @matchcode    NVARCHAR(50)
        ,@sporttype        INT
        ,@leagueid        INT
        ,@sqlCommand    NVARCHAR(MAX)
        ,@procName        NVARCHAR(50)
        ,@Action        VARCHAR(10)

    SELECT @matchcode    = m.matchcode
        ,@sporttype        = m.sporttype
        ,@leagueid        = m.leagueid
        ,@Action        = 'REFUND-HT'
    FROM DBPRO.bodb02.dbo.match m WITH (NOLOCK)
    WHERE m.matchid = @MatchId

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT @ErrCode = 1000001
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
				,@ErrMsg    = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

			RETURN
		END
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


    SELECT @ErrCode        = 0
        ,@ErrMsg        = ''
        ,@procName        = OBJECT_NAME(@@procid)
        ,@sqlCommand    = 'EXEC [dbo].[NAP_Admin_Settlement_RefundHT] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
                                                                 + ', @adminid = ' + CONVERT(NVARCHAR(50), @AdminId) 
                                                                 + ', @IsExcludeBetdaq = ' + CONVERT(NVARCHAR(1), @IsExcludeBetdaq) 
                                                                 + ', @IsSettleAbandonedMatch = ' + CONVERT(NVARCHAR(1), @IsSettleAbandonedMatch) 
                                                                 + ', @IsExcludeBetfair = ' + CONVERT(NVARCHAR(1), @IsExcludeBetfair) 
                                                                 + ', @IsSettleAbandonedMatchBetFair = ' + CONVERT(NVARCHAR(1), @IsSettleAbandonedMatchBetFair) 
                                                                 + ', @hth = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeHome), 'NULL') 
                                                                 + ', @hta = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeAway), 'NULL') 
                                                                 + ', @ResourceResult = ' + CASE WHEN @ResourceResult IS NULL THEN 'NULL'
                                                                                     ELSE '''' + @ResourceResult + '''' END 
                                                                 + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
                                                                 + ', @ErrCode = @ErrCode OUTPUT' 
                                                                 + ', @ErrMsg = @ErrMsg OUTPUT'

    
    IF LEN(@sqlCommand)> 1000 --Max Field 
    BEGIN
        SELECT   @ErrCode = 1001010
                ,@ErrMsg  = 'There are too many inputted results to proceed at one time. Please select each one to execute separately.'    
        RETURN 
    END

    IF (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- UAT1 -->UAT9
    BEGIN
        DECLARE @fth        SMALLINT
            ,@fta            SMALLINT
            ,@hth            SMALLINT
            ,@hta            SMALLINT
            ,@GoalRecord    VARCHAR(50)
            ,@BetStatus        NVARCHAR(50)

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
            )
        SELECT @MatchId
            ,@matchcode
            ,0
            ,@leagueid
            ,@sporttype
            ,@AdminId
            ,@IP
            ,@Action
            ,@sqlCommand
    END
END
GO
