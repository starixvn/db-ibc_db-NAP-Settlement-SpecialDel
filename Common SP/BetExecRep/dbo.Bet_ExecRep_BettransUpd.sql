/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Bet_ExecRep_BettransUpd] 
	@BetTickets	VARCHAR(MAX)
	,@matchid	INT = 0
	,@Action VARCHAR(20) = NULL
	,@TicketType VARCHAR(1) = NULL
AS
/*
	Created: 20160606@Bobby
	Task :  77720 - Implement BetRadar VS League & Nation
	DB: DBTXN/BODB02
	Revisions:
		- 20160606@Bobby: Initialize
		- 20170821@Bobby: 81907-  correct recommend info to do settlement on replicas DB05XXX
		- 20181030@Kathy: Change CIX on DB052 [Redmine:#103985]
		- 20190221@Kathy: Do not settle ticket on DB04x [Redmine:#108362]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:
		- ExecRep SP: DBTrans_Bet
					
*/
BEGIN
	SET NOCOUNT ON

	-- CHECK SERVER BEFORE CALCULATING
	DECLARE @ServerName	SYSNAME 
			,@AllowExec	BIT
			,@transInfo	XML
			,@IsSiteDB	BIT = 0
			
	DECLARE @tmpTransInfo TABLE (transId BIGINT
			,modds MONEY, statuswinlost TINYINT, winlostdate SMALLDATETIME
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT
			,bef_winlost MONEY ,bef_statusid TINYINT
		)
		
	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL
		SET @IsSiteDB = 1

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName	= @ServerName
			,@AllowExec	= @AllowExec OUTPUT

		IF @AllowExec = 0
			RETURN
	END
	-- END CHECK

	--RECEIVE bet tickets
	DECLARE @xmlTicket XML
	
	DECLARE @sourceTicket TABLE (
		[recommend] 		[INT]
		, [matchid] 		[INT]
		, [custid] 			[INT]
		, [bettype] 		[SMALLINT]
		, [transid] 		[BIGINT]
		, [winlost] 		[MONEY]
		, [awinlost] 		[MONEY]
		, [mwinlost] 		[MONEY]
		, [swinlost] 		[MONEY]
		, [playercomm] 		[MONEY]
		, [comm] 			[MONEY]
		, [acomm] 			[MONEY]
		, [scomm] 			[MONEY]
		, [statusid] 		[TINYINT]
		, [modds] 			[SMALLMONEY]
		, [actual_stake] 	[MONEY]
		, [winlostdate] 	[SMALLDATETIME]

	)
	
	--PARSER xmlTicket
	SELECT @xmlTicket = CONVERT(XML, @BetTickets)
	
	--INSERT bet tickets
	INSERT INTO @sourceTicket (
		recommend
		,matchid
		, custid
		, bettype
		, transid
		, WinLost
		, aWinLost
		, mWinLost
		, sWinLost
		, PlayerComm
		, comm
		, acomm
		, scomm
		, StatusID
		, modds
		, winlostdate
	)
	SELECT
		T.C.value('./@rec', 'INT') AS recommend
		, T.C.value('./@mi', 'INT') AS matchid
		, T.C.value('./@ci', 'INT') AS custid
		, T.C.value('./@bt', 'SMALLINT') AS bettype
		, T.C.value('./@ti', 'BIGINT') AS transid
		, T.C.value('./@wl', 'MONEY') AS WinLost
		, T.C.value('./@awl', 'MONEY') AS aWinLost
		, T.C.value('./@mwl', 'MONEY') AS mWinLost
		, T.C.value('./@swl', 'MONEY') AS sWinLost
		, T.C.value('./@pcomm', 'MONEY') AS PlayerComm
		, T.C.value('./@comm', 'MONEY') AS comm
		, T.C.value('./@acomm', 'MONEY') AS acomm
		, T.C.value('./@scomm', 'MONEY') AS scomm
		, T.C.value('./@st', 'TINYINT') AS StatusID
		, T.C.value('./@mo', 'MONEY') AS modds
		, T.C.value('./@wd', 'DATE') AS winlostdate
	FROM @xmlTicket.nodes('/root/r') AS [T](C) --T: table, C: column
	OPTION (OPTIMIZE FOR (@xmlTicket = NULL))

	UPDATE b 
		SET winlost 		= s.winlost
			,awinlost 		= s.awinlost
			,mwinlost 		= s.mwinlost
			,swinlost 		= s.swinlost
			,playercomm 	= s.playercomm
			,comm 			= s.comm
			,acomm 			= s.acomm
			,scomm 			= s.scomm
			,statusID 		= s.statusid
			,modds 			= s.modds
			,status 		= CASE s.statusid
								WHEN 112 THEN 'WON'
								WHEN 111 THEN 'DRAW'
								WHEN 113 THEN 'LOSE'
								WHEN 103 THEN 'Refund'
								WHEN 0 THEN 'Running'
							END 			
			,ruben 			= CASE 
								WHEN s.statusid IN (111,112,113,103) THEN 1
								ELSE 0 
							END
			,winlostdate 	= ISNULL(s.winlostdate, b.winlostdate)
			,statuswinlost	= CASE 
								WHEN s.statusid IN (103) THEN 0 --REFUND
								ELSE b.statuswinlost 
							END
	OUTPUT inserted.transid		
			,inserted.modds ,inserted.statuswinlost	,inserted.winlostdate 
			,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
			,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm		
			,inserted.status 			
			,inserted.statusID 	
			,inserted.ruben 
			,deleted.winlost
			,deleted.statusid
	INTO @tmpTransInfo (transId 
			,modds, statuswinlost, winlostdate 
			,WinLost,aWinLost,mWinLost,sWinLost 
			,PlayerComm, Comm,aComm,sComm 
			,Status ,StatusID ,ruben 
			,bef_winlost  ,bef_statusid )
	FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
		INNER JOIN @sourceTicket s 
		ON b.matchid 		= s.matchid
			AND b.custid 	= s.custid
			AND b.bettype 	= s.bettype
			AND b.transid 	= s.transid
	
	IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
	BEGIN
		SET @transInfo = (
			SELECT	transId AS '@t'	
					,modds AS '@m'
					,statuswinlost AS '@statuswl' 
					,winlostdate AS '@wld'
					,WinLost AS '@w' 
					,aWinLost AS '@aw' 
					,mWinLost AS '@mw' 
					,sWinLost AS '@sw' 
					,PlayerComm AS '@pc' 
					,Comm AS '@c' 
					,aComm AS '@ac' 
					,sComm AS '@sc' 
					,Status AS '@s' 
					,StatusID AS '@sid' 
					,ruben AS '@r' 
					,bef_winlost AS '@bef_w' 
					,bef_statusid AS '@bef_sid' 				
			FROM	@tmpTransInfo
			FOR XML PATH('r'),ROOT('root'), TYPE
		)

		INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, TransInfo, MatchId, SettlementAction, TicketType)
		VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @transInfo, @matchid, @Action, @TicketType)		--cal or refund
	END
END
GO

