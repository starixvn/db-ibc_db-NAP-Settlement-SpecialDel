/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_OtherSports]
    @matchid INT = 0
    ,@action                        VARCHAR(20)     = 'CAL'
    ,@ActionID				        INT             = 0
    ,@strTransIds                   VARCHAR(MAX)    = NULL
    ,@CalledByBrokerService         BIT         = 0
    ,@RunOnServer                   VARCHAR(100) = NULL
	,@EventTable					TINYINT = 1 -- match
	,@Is3rd							BIT =  0
	,@IsCalculateBalance			BIT =  0
	,@BalanceType					TINYINT = 0
	,@CWLBettype					SMALLINT = 0
    ,@SettleByApp                   BIT = 0
    ,@TransJson                     VARCHAR(MAX)    = ''
    ,@BroadcastSessionId	        VARCHAR(50)		= ''
    ,@ErrMessage			        VARCHAR(300)	= ''	OUTPUT
	,@ErrCode				        INT				= 0		OUTPUT
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
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]
		- 20230704@Louisa:  Virtual Leap Gaming - VS3 [Redmine:#189854]
        - 20240520@Aries: Transfer the logic business from the DB layer to the Application layer for Happy5 [Redmine:#202389]

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
            + '@ActionID = ' + CONVERT(NVARCHAR(50), @ActionID) + ','
            + '@strTransIds = ' + '''' + @strTransIds + '''' +  ','
            + CASE WHEN @RunOnServer IS NULL THEN '' ELSE '@RunOnServer = ' + '''' + CONVERT(NVARCHAR(100), @RunOnServer) + '''' END + ','
			+ '@EventTable = ' + CAST(@EventTable AS VARCHAR(3)) +  ','
			+ '@Is3rd = ' + CAST(@Is3rd AS VARCHAR(3)) +  ','
            + '@CalledByBrokerService = 1 ' +  ','
            + '@SettleByApp = ' + CONVERT(NVARCHAR(1), @SettleByApp) +  ','
            + '@TransJson = ' + '''' + ISNULL(@TransJson,'') + '''' +  ','
            + '@BroadcastSessionId = ' + '''' + ISNULL(@BroadcastSessionId,'') + ''''
            
        EXEC [sb].[SBInputMessage] @fromService = N'Service_Settlement_OtherSports'
            ,@toService = N'Service_Settlement_OtherSports'
            ,@onContract = N'Contract_Settlement_OtherSports'
            ,@messageType = N'MessageType_Settlement_OtherSports'
            ,@messageBody = @sMessage

        RETURN
        
    END
    ELSE
    BEGIN
        IF @action LIKE 'CAL%' AND @SettleByApp = 0
        BEGIN
            EXEC dbo.NAP_Admin_Calculate_TransID
                @transIds		= @strTransIds
				,@MatchId		= @matchid
				,@EventTable	= @EventTable
				,@Is3rd			= @Is3rd
				,@IsCalculateBalance	=  @IsCalculateBalance
				,@CWLBettype	= @CWLBettype
				,@BalanceType	= @BalanceType
        END
        ELSE IF @action LIKE 'REFUND%' AND @SettleByApp = 0
        BEGIN
            EXEC dbo.NAP_Admin_Calculate_Refund_TransID
                @transIds		= @strTransIds
				,@MatchId		= @matchid				   
				,@EventTable	= @EventTable
				,@Is3rd			= @Is3rd
				,@IsCalculateBalance	=  @IsCalculateBalance
				,@CWLBettype	= @CWLBettype
				,@BalanceType	= @BalanceType
        END       
        ELSE IF @action LIKE 'UNDO%' AND @SettleByApp = 0
        BEGIN
            EXEC dbo.NAP_Admin_Calculate_Undo_TransID
                @transIds		= @strTransIds
				,@MatchId		= @matchid				   
				,@EventTable	= @EventTable
				,@Is3rd			= @Is3rd
        END    
        ELSE IF @SettleByApp = 1
        BEGIN
            EXEC Bet_ExecRep_NAP_Admin_03
                 @MatchId		        = @matchid
                ,@Action                = @action
                ,@ActionId              = @ActionID
                ,@TransJson		        = @TransJson
                ,@EventTable            = 1
				,@Is3rd			        = 1
				,@IsCalculateBalance	= 1
				,@CWLBettype	        = 81
				,@BalanceType	        = 4
                ,@BroadcastSessionId    = @BroadcastSessionId

                ,@ErrMessage			=   @ErrMessage			OUTPUT
				,@ErrCode				=   @ErrCode			OUTPUT
        END
    END                
END