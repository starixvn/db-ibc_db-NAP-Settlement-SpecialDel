
----*******************************************
---- 
----*******************************************
---STEP 1. CHECK DATA ON SiteDB
--- run on Sitedb /bodb02
	----tickets
	use bodb02

  	select matchid, transid, transdate, settlementtime, custid, creator, status, repupdatetime, repdstupdatetime, fcupdatetime
			, status, sitedbgroupid, @@servername as ServerName
	from bettrans b with(nolock) 
	where transid in
	(
	167012741070979110
	)
	order by matchid, transid

	---table sync service
	SELECT l.LogId	,l.matchid, tmp.transid	,l.TableName,l.LogDate,l.SessionId,l.IsParallel ,l.FunctionName, l.Action, l.SettlementAction, l.TicketType ,l.TransInfoJson																					
	FROM SiteDB_SettlementService_CalculationLog l WITH (NOLOCK)
		CROSS APPLY (	SELECT t TransID, m modds,o odds,os oddsspread,statuswl  statuswinlost,st SettlementTime
							,w WinLost, aw aWinLost, mw mWinLost, sw sWinLost, pc PlayerComm, c Comm, ac aComm, sc sComm, s Status, sid StatusID, r ruben
						FROM OPENJSON(DECOMPRESS(l.TransinfoJson) )
							WITH (
							t   BIGINT
							,m  VARCHAR(11)
							,o  SMALLMONEY	
							,os  VARCHAR(20)
							,statuswl  VARCHAR(1)
							,st  DATETIME
							,w  MONEY
							,aw  MONEY
							,mw  MONEY
							,sw  MONEY
							,pc  MONEY
							,c  MONEY
							,ac  MONEY
							,sc  MONEY
							,s  NVARCHAR(10)
							,sid  TINYINT
							,r  TINYINT
						)
					 ) as tmp
	where matchid = 72775374
		AND tmp.transid IN 
		(
		167012741070979110
		)
	order by matchid, transid,logdate

  select top 10 Logid, StatusId 
  from SiteDB_SettlementService_LastLog with (nolock)
  where logid = xxxx

----STEP 2. Check sync service at DBTRANS/bodb02
	use bodb02
	go

	select top 10 * from SiteDB_SettlementService_CalculationLog_History with (nolock)
	where logid in (21186645,21220417)

	SELECT top 10 
			REPLACE( SUBSTRING (MessageBody, charindex('@TransInfoJson=',MessageBody)+15, len(MessageBody)) , '''', '')     as TransInfoJson
			, *
	FROM SSB_SettlementLogs l WITH(NOLOCK) 
	WHERE MessageType like '%sitedb3_bet_settle_msg_type_0_%'
		AND SessionId = xxxx -- sessionid from step 1
	 
	DECLARE @TransInfoJson	VARBINARY(MAX) =0x1F8B0800000000000400ED92CB0AC2301045EFB7646D4B9A56FBF808DD082E4444AB8260516CC585F8EF4E2663B58F857B4B9836B96732775A668907142A8A0C01C63048290C12C4087967DF319D27140946945970B6A27C1F5A96627266E2D1D9A7DC9489D34B26FAEB86D54B7156E4A32942BE9BD03320BF39FB67CC5C77B66A48CBB9DDA56BE7D4ACBC11EA2162AD498B9A863DB4ACA9E9A51555AF70E3BC53DDBFEBE9829C15D3B997D7FFB8DDA92369C7C7E95147778E0BCC3015D71247ECA47E40DE56BBCAD9EEB7D8E380B57C57BBB337FD54D17812F97D3252F1192663988CF664986132FE6632567801C64C514650060000
	
	SELECT *  
	FROM OPENJSON(DECOMPRESS(@TransInfoJson)) 
	WITH (  
		t   BIGINT  
		,m  VARCHAR(11)  
		,o  SMALLMONEY   
		,os  VARCHAR(20)  
		,statuswl  VARCHAR(1)  
		,st  DATETIME  
		,w  MONEY  
		,aw  MONEY  
		,mw  MONEY  
		,sw  MONEY  
		,pc  MONEY  
		,c  MONEY  
		,ac  MONEY  
		,sc  MONEY  
		,s  NVARCHAR(10)  
		,sid  TINYINT  
		,r  TINYINT  
	)  
	where t IN 
		(
			167012741070979110
		)

----STEP 3: check ticket history on DBTP/bodb02
	---- single tickets
	use bodb02
	go
	select sys.fn_cdc_map_lsn_to_time(__$start_lsn) actiontime, status, transid
			,* 
	from cdc.dbo_bettrans_CT with(nolock)
	where transid IN 
		(
		167012741070979110
		)
	and __$start_lsn >= sys.fn_cdc_map_time_to_lsn('largest less than or equal', '2023-09-24 00:04:20.720')
		and __$start_lsn < sys.fn_cdc_map_time_to_lsn('largest less than or equal', '2023-09-24 00:04:40.720')
		and sys.fn_cdc_map_lsn_to_time(__$start_lsn) = '2023-09-24 00:04:28.720'
	order by __$start_lsn, 3

	---- sub parlay tickets
	select sys.fn_cdc_map_lsn_to_time(__$start_lsn) actiontime, status, transid
			, * 
	from cdc.dbo_bettransm_CT with(nolock)
	where transid IN 
		(
		167012741070979110
		)
	and __$start_lsn >= sys.fn_cdc_map_time_to_lsn('largest less than or equal', '2023-09-24 00:04:20.720')
		and __$start_lsn < sys.fn_cdc_map_time_to_lsn('largest less than or equal', '2023-09-24 00:04:40.720')
		and sys.fn_cdc_map_lsn_to_time(__$start_lsn) = '2023-09-24 00:04:28.720'
	order by __$start_lsn, 3


	








 







