/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Bet_ExecRep_BettransUpd] 
	@BetTickets	VARCHAR(MAX)
AS
/*
	Created: 20160606@Bobby
	Task :  77720 - Implement BetRadar VS League & Nation
	DB: DBTXN/BODB02
	Revisions:
		- 20160606@Bobby: Initialize
		

	Param's Explanation:
		- ExecRep SP: DBTrans_Bet
					
*/
BEGIN
	SET NOCOUNT ON
	
	IF @@SERVERNAME IN ('DB04', 'DB042', 'DB043', 'DB044') RETURN

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

	--UPDATE on replicas DB servers
	IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054','DB231','DB215')
    BEGIN
		UPDATE dbo.bettrans WITH(ROWLOCK, UPDLOCK)
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
			,winlostdate 	= ISNULL(s.winlostdate, bettrans.winlostdate)
			,statuswinlost	= CASE 
								WHEN s.statusid IN (103) THEN 0 --REFUND
								ELSE bettrans.statuswinlost 
							END
		FROM @sourceTicket s
		WHERE bettrans.recommend 	= s.recommend
			AND bettrans.matchid 	= s.matchid
			AND bettrans.bettype 	= s.bettype
			AND bettrans.transid 	= s.transid
	END
	ELSE --UPDATE on DBTXN
    BEGIN
		UPDATE dbo.bettrans WITH(ROWLOCK, UPDLOCK)
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
			,winlostdate 	= ISNULL(s.winlostdate, bettrans.winlostdate)
			,statuswinlost	= CASE 
								WHEN s.statusid IN (103) THEN 0 --REFUND
								ELSE bettrans.statuswinlost 
							END
		FROM @sourceTicket s
		WHERE bettrans.matchid 		= s.matchid
			AND bettrans.custid 	= s.custid
			AND bettrans.bettype 	= s.bettype
			AND bettrans.transid 	= s.transid
		
	END
	
END
GO

