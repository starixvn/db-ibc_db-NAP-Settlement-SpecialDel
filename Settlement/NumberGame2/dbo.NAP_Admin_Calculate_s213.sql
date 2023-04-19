/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_s213] 
	@strXML VARCHAR(MAX),
	@CalledByBrokerService BIT = 0,
	@RunOnServer VARCHAR(100) = NULL
AS
/*
	Created by:[Johnson]
	Date:[20160824]
	Task: Settlement for NG2
	DB: DBTXN/BODB02
	
	Revisions:
		- 20161214@Johnson: correct comm value [redmine:#68766]
		- 20190319@Johnson: migrate server DB061,062 [redmine: #110514]
		- 20200826@Johnson: add more servers DB055, DB06C2\DB06 [redmine:#140315]
		- 20210125@Johnson: Migrate DB054 to cluster, instance DB054C2\DB054 [redmine:#149341]
		- 20210419@Johnson: Do not run replicated commands on servers which setup service broker [Redmine:#145127]
		- 20230419@Kathy: Scale Out for Number Game 2 [Redmine:#186722]
	Parameter's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @IsEnableServiceBroker BIT 
		
	EXEC dbo.NAP_Set_ServerInfo 
		@IsEnableServiceBroker = @IsEnableServiceBroker OUTPUT
	
	SET @RunOnServer = ISNULL(@RunOnServer,@@SERVERNAME)
	
	IF @RunOnServer <> @@SERVERNAME
	BEGIN
		PRINT 'This command was skipped because run wrong server'
		RETURN
	END
	
	IF (@@SERVERNAME IN ('DB231\DBSPU2','DB232\DBSPU2','DBLicAPI','SITDBLicAPI','DBLicAPI02') OR @IsEnableServiceBroker = 1)
		AND @CalledByBrokerService = 0
	BEGIN
		-- DB052/DB053/DB054/DB06: got servicebroker, then just send a message to service broker and then let it to handle the rest.
		DECLARE @sMessage NVARCHAR(MAX)

		SET @sMessage = 'EXEC dbo.NAP_Admin_Calculate_s213 '
		+'@strXML =' + '''' + @strXML + '''' + ','
		+'@CalledByBrokerService = 1'
		+CASE WHEN @RunOnServer IS NULL THEN '' ELSE ',@RunOnServer = ' + '''' + CONVERT(NVARCHAR(100), @RunOnServer) + '''' END
		
		EXEC [sb].[SBInputMessage] @fromService = N'//Service/Calculation_send'
			,@toService = N'//Service/Calculation_receive'
			,@onContract = N'//Contract/Calculation'
			,@messageType = N'//Message/Calculation'
			,@messageBody = @sMessage

		RETURN
	END
	ELSE
	BEGIN		
		CREATE TABLE #tmpTrans (transid BIGINT, payout MONEY)
		
		DECLARE @xml XML,
			@statusid TINYINT
		
		SET @xml = CONVERT(XML, N'<root><r t="' + REPLACE(REPLACE(@strXML, '|', '" p="'), ',', '"/><r t="') + '"/></root>')
		
		INSERT INTO #tmpTrans (transid, payout)
		SELECT T.C.value('./@t', 'bigint')
				,T.C.value('./@p', 'money')
		FROM @xml.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@xml = NULL ))
		
		UPDATE b
		SET @statusid = statusid = CASE WHEN payout = stake THEN 111 --DRAW
										WHEN payout > stake THEN 112 --WON
										WHEN payout < stake THEN 113 --LOSE
										ELSE b.statusid	END,
			status = CASE WHEN @statusid = 111 THEN 'DRAW'
							WHEN @statusid = 112 THEN 'WON'
							WHEN @statusid = 113 THEN 'LOSE'
							ELSE status END,
			ruben = CASE WHEN @statusid IN (111,112,113) THEN 1 ELSE ruben END,
			WinLost = payout,
			aWinlost = (payout - stake)*-apositiontaking,
			mWinlost = (payout - stake)*-mpositiontaking,
			sWinlost = (payout - stake)*-spositiontaking,
			PlayerComm = CASE WHEN @statusid IN (112,113) THEN playerdiscount * stake ELSE 0 END,
			comm = CASE WHEN @statusid IN (112,113) THEN discount * stake * (1-apositiontaking) ELSE 0 END,
			acomm = CASE WHEN @statusid IN (112,113) THEN adiscount * stake * (1-(mpositiontaking+apositiontaking)) ELSE 0 END,
			scomm = CASE WHEN @statusid IN (112,113) THEN sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) ELSE 0 END,
			RepUpdateTime = SYSDATETIME()
		FROM bettrans b WITH(ROWLOCK)
			INNER JOIN #tmpTrans t ON b.transid = t.transid
		
		DROP TABLE #tmpTrans
	END	
	
	
END
GO