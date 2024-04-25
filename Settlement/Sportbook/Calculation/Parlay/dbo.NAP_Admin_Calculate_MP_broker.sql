/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_broker] 
    @matchid INT = NULL
    ,@mode VARCHAR(30) = NULL
    ,@action VARCHAR(20) = 'CAL'
    ,@matchdate DATETIME = NULL
    ,@VoidTransID VARCHAR(2000) = NULL
    ,@UserId INT = NULL
    ,@strXML VARCHAR(MAX) = NULL
    ,@strTransIds   VARCHAR(MAX) = NULL
	,@strMainTransIds VARCHAR(MAX) = NULL
	,@strRefnoMainTransIds VARCHAR(MAX) = NULL
    ,@CalledByBrokerService BIT = 0
	,@RunOnServer	VARCHAR(100) = NULL
	,@IsReSettledTickets BIT = 0
	,@strSetting VARCHAR(MAX) = NULL
    ,@BroadcastSessionId	VARCHAR(50)	= NULL
	,@SessionId BIGINT = NULL
	,@ActionId INT = NULL
	,@IsCalculateBalance BIT = NULL
	,@ParlaySettlementProcessingId BIGINT = NULL
	,@StatusId TINYINT = NULL
	,@IsParallel BIT = NULL
	,@AffectedTicket INT = 0 OUTPUT
	,@AffectedTransIds VARCHAR(MAX) = NULL OUTPUT
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
		- 20230405@Louisa: Support resettle Parlay tickets [Redmine:#186276]
		- 20230816@Kathy: parlay boost [Redmine:#191873]
		- 20230810@Louisa: remove un-use code [Redmine:#188116]
        - 20231214@Aries: Result Amendment [Redmine: #196401]
		- 20240215@Kathy: support multiple threads to settle parlay [Redmine:#199518]
		- 20240425@Kathy: enhance MaxPayout [Redmine:#199518]

    Param's Explanation:
        @action         @mode

*/
BEGIN
    SET NOCOUNT ON
	
	DECLARE @IsEnableServiceBroker	BIT 
			,@ServerAlias			VARCHAR(50)
			,@TotalParlayQueue		INT
	
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
		,@ServerAlias = @ServerAlias OUTPUT	
		,@TotalParlayQueue = @TotalParlayQueue OUTPUT
		
	IF (@@SERVERNAME IN ('DB052', 'DB053', 'DBTP','DB061', 'DB062') OR @IsEnableServiceBroker = 1) AND @CalledByBrokerService = 0 
    BEGIN
        -- DB052/DB053/DB054/DB06: got servicebroker, then just send a message to service broker and then let it to handle the rest.
        DECLARE @sMessage NVARCHAR(MAX)

		IF OBJECT_ID('ParlaySettlementProcessing', 'U') IS NOT NULL AND ISNULL(@ParlaySettlementProcessingId,0) <> 0
		BEGIN
			IF @Mode = 'profile'
			BEGIN
				DECLARE @MessageTypeNew VARCHAR(200) 
					,@QueueNoNew INT 
			
				SET @QueueNoNew = @ParlaySettlementProcessingId%@TotalParlayQueue 
									+ CASE WHEN @ParlaySettlementProcessingId%@TotalParlayQueue = 0 THEN @TotalParlayQueue ELSE 0 END

				SET @MessageTypeNew = 'parlaybet_settle_msg_type_' 
										+ CASE WHEN @QueueNoNew < 10 THEN '0' ELSE '' END + CAST(@QueueNoNew AS VARCHAR)
			
				INSERT INTO dbo.ParlaySettlementProcessing (SessionId, MatchId, MessageType, Action, ActionId ,subTransIds, mainTransIds, RefnoMainTransIds, EventDate, strSetting, IsReSettledTickets)
				SELECT @SessionId, @matchid, @MessageTypeNew, @action, @ActionId
					,@strTransIds -- list subtransid
					,@strMainTransIds -- list maintransid
					,@strRefnoMainTransIds -- refno|transid,refno|transid
					,@matchdate, @strSetting, @IsReSettledTickets
			END
			ELSE
			BEGIN
				RETURN -- dont need to do anything for @mode = 'PRECAL-29' & '29'
			END
		END
		ELSE
		BEGIN
			SET @sMessage = 'EXEC dbo.NAP_Admin_Calculate_MP_broker '
					+ '@matchid = ' + CASE WHEN @matchid IS NULL THEN 'NULL' ELSE CONVERT(NVARCHAR(50),@matchid) END + ','
					+ '@mode = ' + CASE WHEN @mode IS NULL THEN 'NULL' ELSE '''' + @mode + '''' END + ','
					+ '@action = ' + CASE WHEN @action IS NULL THEN 'NULL' ELSE '''' + @action + '''' END
					+ CASE WHEN @ActionId IS NULL THEN '' ELSE ',@ActionId = ' + CONVERT(NVARCHAR(50), @ActionId) END
					+ CASE WHEN @SessionId IS NULL THEN '' ELSE ',@SessionId = ' + CONVERT(NVARCHAR(50), @SessionId) END
					+ CASE WHEN @matchdate IS NULL THEN '' ELSE ',@matchdate = ''' + CONVERT(NVARCHAR(50), @matchdate) + '''' END               
					+ CASE WHEN @VoidTransID IS NULL THEN '' ELSE ',@VoidTransID = ''' + @VoidTransId + '''' END
					+ CASE WHEN @UserId IS NULL THEN '' ELSE ',@UserId = ' + CONVERT(NVARCHAR(50), @UserId) END					             
					+ CASE WHEN @strTransIds IS NULL THEN '' ELSE ',@strTransIds = ''' + @strTransIds + '''' END
					+ CASE WHEN @strXML IS NULL THEN '' ELSE ',@strXML = ''' + @strXML + '''' END  
					+ CASE WHEN @RunOnServer IS NULL THEN '' ELSE ',@RunOnServer = ' + '''' + CONVERT(NVARCHAR(100), @RunOnServer) + '''' END
					+ ',@IsReSettledTickets = ' + CONVERT(NVARCHAR(1),ISNULL(@IsReSettledTickets,0))
					+ CASE WHEN @strSetting IS NULL THEN '' ELSE ',@strSetting = ''' + @strSetting + '''' END
					+ ',@CalledByBrokerService = 1'
		
			EXEC [sb].[SBInputMessage] @fromService = N'//Service/Calculation_send'
				,@toService = N'//Service/Calculation_receive'
				,@onContract = N'//Contract/Calculation'
				,@messageType = N'//Message/Calculation'
				,@messageBody = @sMessage
		END

        RETURN
    END

	IF @mode IN ('ParlayLockMatch', 'ParlayReleaseMatch') AND @ServerAlias <> 'DBTXN' AND @IsEnableServiceBroker = 1
	BEGIN
		EXEC dbo.ExecRep_NAP_Admin_01
			@MatchId = @MatchId
			,@Mode = @Mode
			,@SessionId = @SessionId
			,@TotalParlayQueue = @TotalParlayQueue
	END

	IF (@Mode IN ('profile'))
    BEGIN
        EXEC dbo.NAP_Admin_Parlay_Calculate_3 @matchid = @matchid
            , @matchdate = @matchdate
            , @action = @action
            , @strTransIds = @strTransIds
			, @BroadcastSessionId = @BroadcastSessionId
			, @SessionId = @SessionId
			, @IsParallel = @IsParallel
			, @ParlaySettlementProcessingId = @ParlaySettlementProcessingId
			, @AffectedTicket = @AffectedTicket OUTPUT
    END

    IF @mode = 'PRECAL-29'
    BEGIN
        EXEC dbo.NAP_Admin_Calculate_MP_PreCal_29 @matchid = @matchid
            , @matchdate = @matchdate
            , @strXML = @strXML
			, @IsReSettledTickets = @IsReSettledTickets
			, @strSetting = @strSetting
			, @SessionId = @SessionId
			, @IsParallel = @IsParallel
			, @ParlaySettlementProcessingId = @ParlaySettlementProcessingId
			, @AffectedTicket = @AffectedTicket OUTPUT
    END

    IF @mode = '29'
    BEGIN
        EXEC dbo.NAP_Admin_Calculate_MP_29 @MatchId = @MatchId
            , @strXML = @strXML
            , @BroadcastSessionId = @BroadcastSessionId
			, @ServerAlias = @ServerAlias
			, @matchdate = @matchdate
			, @ActionId = @ActionId
			, @IsCalculateBalance = @IsCalculateBalance
			, @SessionId = @SessionId
			, @IsParallel = @IsParallel		
			, @ParlaySettlementProcessingId = @ParlaySettlementProcessingId
			, @AffectedTicket = @AffectedTicket OUTPUT
			, @AffectedTransIds = @AffectedTransIds OUTPUT
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