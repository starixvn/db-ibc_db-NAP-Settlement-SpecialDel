/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_RefundHT_Push] 
    @MatchId                        INT
    ,@AdminId                       INT
    ,@HalfTimeHome                	INT             = NULL
    ,@HalfTimeAway                	INT             = NULL
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
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:

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

    SELECT @ErrCode        = 0
        ,@ErrMsg        = ''
        ,@procName        = OBJECT_NAME(@@procid)
        ,@sqlCommand    = 'EXEC [dbo].[NAP_Admin_Settlement_RefundHT] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
                                                                 + ', @adminid = ' + CONVERT(NVARCHAR(50), @AdminId) 
                                                                 + ', @hth = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeHome), 'NULL') 
                                                                 + ', @hta = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeAway), 'NULL') 
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
