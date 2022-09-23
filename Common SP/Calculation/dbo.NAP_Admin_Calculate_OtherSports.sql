/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_OtherSports]
    @matchid INT = 0
    ,@action                        VARCHAR(20)     = 'CAL'
    ,@strTransIds                   VARCHAR(MAX)    = NULL
    ,@CalledByBrokerService         BIT         = 0
    ,@RunOnServer                   VARCHAR(100) = NULL
AS
/*
    Created: 20181016@Vicky
    Task : Covered SP for othersports settlement
    DB: EXECREP SP (DBTrans_Bet)

    Revisions:
        - 20181128@Helen:  Apply Service broker for Number Game [Redmine: 101611]
        - 20190315@Kathy: Add 2 new servers DB061, DB062 [Redmine:#110276]
        - 20191128@Helen: Not settle on db054 [Redmine:#110276]
        - 20200114@Sol: Server replacement - DB042 to DB055 [Redmine:#127173]
        - 20200825@Kathy: Check server is using service broker by new SP instead of servername [Redmine:#140045]
        - 20210118@Louisa: Change Instant Name of DB054 - DB054C2\DB054 [Redmine:#148785]
        - 20210416@Kathy: Do not run replicated commands on servers which setup service broker [Redmine:#145127]
		- 20220405@Louisa: Add New server alias ( new local test 2019) [Redmine:#171615]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON
    DECLARE @isUndo BIT
    DECLARE @sMessage NVARCHAR(MAX)
            ,@IsEnableServiceBroker BIT 
    
    SET @isUndo = CASE 
                    WHEN @action LIKE 'UNDO%' THEN 1
                    ELSE 0
                END
    SET @IsEnableServiceBroker = 0
    
    SET @RunOnServer = ISNULL(@RunOnServer,@@SERVERNAME)

    IF @RunOnServer <> @@SERVERNAME
    BEGIN
        PRINT 'This command was skipped because run wrong server'
        RETURN
    END

    IF @@SERVERNAME IN ('DB054','DB054C2\DB054','DB042', 'SITDB042', 'DB232\SQLSERVER2008R2', 'DB233\SQLSERVER2008R2', 'TESTDB055', 'DB055') AND @isUndo = 0
        RETURN
        
    EXEC dbo.NAP_Set_ServerInfo 
        @IsEnableServiceBroker = @IsEnableServiceBroker OUTPUT
        
    IF (@@SERVERNAME IN ('DB052', 'DB053', 'DB054', 'DBTP', 'DB061', 'DB062', 'DB055') OR @IsEnableServiceBroker = 1)
            AND @CalledByBrokerService = 0
            
    BEGIN
        -- Just send a message to service broker and then let it to handle the rest.
            
        SET @sMessage = 'EXEC dbo.NAP_Admin_Calculate_OtherSports @matchid = ' + CONVERT(NVARCHAR(50), @matchid) + ','
            + '@action = ' + '''' + @action + '''' +  ','
            + '@strTransIds = ' + '''' + @strTransIds + '''' +  ','
            + CASE WHEN @RunOnServer IS NULL THEN '' ELSE '@RunOnServer = ' + '''' + CONVERT(NVARCHAR(100), @RunOnServer) + '''' END + ','
            + '@CalledByBrokerService = 1 '
            
        EXEC [sb].[SBInputMessage] @fromService = N'Service_Settlement_OtherSports'
            ,@toService = N'Service_Settlement_OtherSports'
            ,@onContract = N'Contract_Settlement_OtherSports'
            ,@messageType = N'MessageType_Settlement_OtherSports'
            ,@messageBody = @sMessage

        RETURN
        
    END
    ELSE
    BEGIN
        IF @action LIKE 'CAL%'
        BEGIN
            EXEC dbo.NAP_Admin_Calculate_TransID
                  @transIds         = @strTransIds
				  ,@MatchId			= @matchid
        END
        ELSE IF @action LIKE 'REFUND%'
        BEGIN
            EXEC dbo.NAP_Admin_Calculate_Refund_TransID
                   @transIds        = @strTransIds
				   ,@MatchId		= @matchid
        END       
        ELSE IF @action LIKE 'UNDO%'
        BEGIN
            EXEC dbo.NAP_Admin_Calculate_Undo_TransID
                   @transIds        = @strTransIds
				   ,@MatchId		= @matchid
        END                
    END                
END