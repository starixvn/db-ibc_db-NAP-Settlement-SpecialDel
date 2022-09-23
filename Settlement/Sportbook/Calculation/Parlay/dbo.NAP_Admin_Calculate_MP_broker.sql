/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_broker] 
    @matchid INT = NULL
    ,@mode VARCHAR(30) = NULL
    ,@priorAction VARCHAR(20) = NULL
    ,@action VARCHAR(20) = 'CAL'
    ,@IsRefundHT BIT = 0
    ,@fth INT = NULL
    ,@fta INT = NULL
    ,@hth INT = NULL
    ,@hta INT = NULL
    ,@matchdate DATETIME = NULL
    ,@statusID TINYINT = NULL
    ,@winlostdate SMALLDATETIME = NULL
    ,@VoidTransID VARCHAR(2000) = NULL
    ,@UserId INT = NULL
    ,@strXML VARCHAR(MAX) = NULL
    ,@TennisTotal       INT = NULL
    ,@GoalSequence          VARCHAR(50) = NULL
    ,@resultDetail_bb VARCHAR(MAX) = NULL -- for basketball
    ,@resultDetail VARCHAR(MAX) = NULL -- for all result
    ,@strBettypes   VARCHAR(MAX) = NULL
    ,@strTransIds   VARCHAR(MAX) = NULL
    ,@betstatus     NVARCHAR(50) = NULL
	,@Sporttype		SMALLINT = NULL
    ,@CalledByBrokerService BIT = 0
	,@RunOnServer	VARCHAR(100) = NULL
AS
/*
    Created: Kathy
    Task : Covered SP for settlement (Parlay)
    Original SP:
    DB: EXECREP SP (DBTrans_Bet)

    Revisions:
        - 20140424@Lukas: add DBTP server
        - 20140716@Kathy: Apply BetRadar [Redmine:#17142]
        - 20140720@Kathy: Apply BetRadar - PenaltyShootout(135) [Redmine:#17142]
        - 20140815@Kathy: add more mode for Special Delete function
        - 20150206@Jamie: Auto Settlement Betradar phase 2 [Redmine: #27212]
        - 20150608@Kathy: Add more mode Recover for recover parlay tickets [Redmine:#35539]
        - 20161108@Kathy: Settlement for new server [Redmine:#66849]
        - 20161205@Bobby: #61352 - Apply settle determined for parlay bet types
        - 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
        - 20170614@Kathy: Setup settlement on new DB Servers DBLicAPI2 [Redmine:#77991]
        - 20170613@Kathy: Early Settlement [Redmine:#77835]
        - 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
        - 20180622@Kathy: Do not settle on server DB042, correct server name DBLicAPI2 to DBLicAPI02 [Redmine#97076]
        - 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190315@Kathy: Add 2 new servers DB061, DB062 [Redmine:#110276]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20191119@Helen: Do not settle ticket on DB054 [Redmine:#123963]
        - 20200114@Sol: Server replacement - DB042 to DB055 [Redmine:#127173]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20200825@Kathy: Check server is using service broker by new SP instead of servername [Redmine:#140045]
		- 20200901@Kathy: Change Calculate Formula for HDP Bet Types of Football [Redmine:#140769]
		- 20210118@Louisa: Change Instant Name of DB054 - DB054C2\DB054 [Redmine:#148785]
		- 20210218@Kathy: Move Tickets of Settled Results Functions [Redmine:#148870]
		- 20210416@Kathy: Do not run replicated commands on servers which setup service broker [Redmine:#145127]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20220110@Kathy: Update winlostdate = eventdate if these values are different [Redmine:#167246]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
        @action         @mode

*/
BEGIN
    SET NOCOUNT ON
	
	DECLARE @IsEnableServiceBroker BIT 
	
    IF @@SERVERNAME IN ('DB054','DB054C2\DB054','DB042', 'SITDB042', 'DB055', 'SITDB055')
        RETURN

    IF ((@mode IS NULL) OR (@matchid IS NULL AND @mode NOT IN ('9', '29'))) RETURN -- not sure what's going on :P
	
	SET @IsEnableServiceBroker = 0
	
	SET @RunOnServer = ISNULL(@RunOnServer,@@SERVERNAME)
	
	IF @RunOnServer <> @@SERVERNAME
	BEGIN
		PRINT 'This command was skipped because run wrong server'
		RETURN
	END
	
	EXEC dbo.NAP_Set_ServerInfo 
		@IsEnableServiceBroker = @IsEnableServiceBroker OUTPUT
		
	IF (@@SERVERNAME IN ('DB052', 'DB053', 'DBTP','DB061', 'DB062') OR @IsEnableServiceBroker = 1) AND @CalledByBrokerService = 0 
    BEGIN
        -- DB052/DB053/DB054/DB06: got servicebroker, then just send a message to service broker and then let it to handle the rest.
        DECLARE @sMessage NVARCHAR(MAX)

        SET @sMessage = 'EXEC dbo.NAP_Admin_Calculate_MP_broker '
                + '@matchid = ' + CASE WHEN @matchid IS NULL THEN 'NULL' ELSE CONVERT(NVARCHAR(50),@matchid) END + ','
                + '@mode = ' + CASE WHEN @mode IS NULL THEN 'NULL' ELSE '''' + @mode + '''' END + ','
                + '@priorAction = ' + CASE WHEN @priorAction IS NULL THEN 'NULL' ELSE '''' + @priorAction + '''' END + ','
                + '@action = ' + CASE WHEN @action IS NULL THEN 'NULL' ELSE '''' + @action + '''' END

                + CASE WHEN @IsRefundHT IS NULL THEN '' ELSE ',@IsRefundHT = ' + CONVERT(NVARCHAR(50), @IsRefundHT) END
                + CASE WHEN @fth IS NULL THEN '' ELSE ',@fth = ' + CONVERT(NVARCHAR(50), @fth) END
                + CASE WHEN @fta IS NULL THEN '' ELSE ',@fta = ' + CONVERT(NVARCHAR(50), @fta) END
                + CASE WHEN @hth IS NULL THEN '' ELSE ',@hth = ' + CONVERT(NVARCHAR(50), @hth) END
                + CASE WHEN @hta IS NULL THEN '' ELSE ',@hta = ' + CONVERT(NVARCHAR(50), @hta) END
                + CASE WHEN @matchdate IS NULL THEN '' ELSE ',@matchdate = ''' + CONVERT(NVARCHAR(50), @matchdate) + '''' END
                + CASE WHEN @statusID IS NULL THEN '' ELSE ',@statusID = ' + CONVERT(NVARCHAR(50), @statusID) END
                + CASE WHEN @winlostdate IS NULL THEN '' ELSE ',@winlostdate = ''' + CONVERT(NVARCHAR(50), @winlostdate) + '''' END
                + CASE WHEN @VoidTransID IS NULL THEN '' ELSE ',@VoidTransID = ''' + @VoidTransId + '''' END
                + CASE WHEN @UserId IS NULL THEN '' ELSE ',@UserId = ' + CONVERT(NVARCHAR(50), @UserId) END
                + CASE WHEN @strXML IS NULL THEN '' ELSE ',@strXML = ''' + @strXML + '''' END
                + CASE WHEN @TennisTotal IS NULL THEN '' ELSE ',@TennisTotal = ' + CONVERT(NVARCHAR(50), @TennisTotal) END
                + CASE WHEN @GoalSequence IS NULL THEN '' ELSE ',@GoalSequence = ''' + @GoalSequence + '''' END
                + CASE WHEN @resultDetail_bb IS NULL THEN '' ELSE ',@resultDetail_bb = ''' + @resultDetail_bb + '''' END
                + CASE WHEN @resultDetail IS NULL THEN '' ELSE ',@resultDetail = ''' + @resultDetail + '''' END              
                + CASE WHEN @strBettypes IS NULL THEN '' ELSE ',@strBettypes = ''' + @strBettypes + '''' END
                + CASE WHEN @strTransIds IS NULL THEN '' ELSE ',@strTransIds = ''' + @strTransIds + '''' END
                + CASE WHEN @betstatus IS NULL THEN '' ELSE ',@betstatus = ''' + @betstatus + '''' END
				+ CASE WHEN @sporttype IS NULL THEN '' ELSE ',@sporttype = ' + CONVERT(NVARCHAR(50), @sporttype) END
				+ CASE WHEN @RunOnServer IS NULL THEN '' ELSE ',@RunOnServer = ' + '''' + CONVERT(NVARCHAR(100), @RunOnServer) + '''' END
                + ',@CalledByBrokerService = 1'
		
		EXEC [sb].[SBInputMessage] @fromService = N'//Service/Calculation_send'
			,@toService = N'//Service/Calculation_receive'
			,@onContract = N'//Contract/Calculation'
			,@messageType = N'//Message/Calculation'
			,@messageBody = @sMessage

        RETURN
    END

    IF @mode = 'basketball_m'
    BEGIN
        EXEC dbo.NAP_Admin_Calculate_MP_m
            @matchid = @matchid,
            @fth = @fth,
            @fta = @fta,
            @hth = @hth,
            @hta = @hta,
            @matchdate = @matchdate,
            @action = 'CAL',
            @priorAction = 'REFUND',           
            @resultDetail_bb = @resultDetail_bb,
            @strBettypes = @strBettypes
    END
	
    IF @mode = 'm'
    BEGIN
        EXEC dbo.NAP_Admin_Calculate_MP_m @matchid = @matchid
            , @fth = @fth
            , @fta = @fta
            , @hth = @hth
            , @hta = @hta
            , @matchdate = @matchdate
            , @action = @action
            , @priorAction = @priorAction
            , @IsRefundHT = @IsRefundHT
            , @TennisTotal = @TennisTotal
            , @GoalSequence = @GoalSequence
            , @resultDetail = @resultDetail
            , @strBettypes = @strBettypes
            , @betstatus = @betstatus          
			, @Sporttype = @Sporttype
    END

    IF @mode = 'PRECAL-29'
    BEGIN
        EXEC dbo.NAP_Admin_Calculate_MP_PreCal_29 @matchid = @matchid
            , @matchdate = @matchdate
            , @strXML = @strXML
    END

    IF @mode = '29'
    BEGIN
        EXEC dbo.NAP_Admin_Calculate_MP_29 @matchdate = @matchdate
            , @strXML = @strXML
    END

    IF @mode = '9'
    BEGIN
        EXEC dbo.NAP_Admin_Calculate_MP_9 @statusID = @statusID
            , @winlostdate = @winlostdate
            , @strXML = @strXML
    END

    IF @mode = 'VOID'
    BEGIN
        EXEC dbo.NAP_Admin_Calculate_MP_m @matchid = @MatchID
            , @fth = 0
            , @fta = 0
            , @hth = 0
            , @hta = 0
            , @matchdate = @matchdate
            , @action = 'VOID'
            , @VoidTransID = @VoidTransID
            , @UserId = @UserId
    END

    IF @Mode = 'RECOVER'
    BEGIN
        EXEC dbo.NAP_Admin_Calculate_MP_m @matchid = @MatchID
            , @matchdate = @matchdate
            , @action = 'RECOVER'
            , @VoidTransID = @VoidTransID
    END

    IF (@Mode IN ('REFUND', 'ABANDONED', 'CAL', 'UNDO'))
    BEGIN
        EXEC dbo.NAP_Admin_Parlay_Calculate_3 @matchid = @matchid
            , @matchdate = @matchdate
            , @action = @mode
            , @strTransIds = @strTransIds
    END

	IF (@Mode IN ('profile'))
    BEGIN
        EXEC dbo.NAP_Admin_Parlay_Calculate_3 @matchid = @matchid
            , @matchdate = @matchdate
            , @action = @action
            , @strTransIds = @strTransIds
    END
	
	IF @Mode = 'subParlay' AND @Action = 'MoveTicket'
	BEGIN
		EXEC dbo.ExecRep_NAP_Admin_02 @matchid = @matchid
			,@Mode = @Mode 
			,@strTransIds = @strTransIds
			,@EventDate = @matchdate
			
		RETURN
	END

END -- end SP
GO