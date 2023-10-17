/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Bet_ExecRep_05] 
	 @IgnoreList VARCHAR(200)
	,@updatetype 	TINYINT = 1  -- 1, 2, 3, 4
	,@_sXML 		VARCHAR(MAX)
	,@Action		VARCHAR(20) = NULL
	,@matchid		INT		= 0

AS
/*
	Created by:[Viet]
	Date:[26 Nov 2012]
	Task: for calculate tickets using replication for bet
	DB: all servers
	
	Revisions:
		- 20130131@Dan:		add virtual racing
		- 20131208@Viet:	add refund NG
		- 20140910@Kathy:	Include range of NG bettypes ( 81-> 120)
		- 20170607@Kent:	Integrate Betradar Virtual Sports [Redmine:#77177]
		- 20170829@Kathy: 	Change datatype of bettransm.TransId [Redmine:#73545]
		- 20180702@Helen:	Using Bet Publication for outright settlement [Redmine:#97670]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20191129@Helen: Not settle on db054 [Redmine:#123963]
        - 20200114@Sol: Server replacement - DB042 to DB055 [Redmine:#127173]
		- 20210118@Louisa: Change Instant Name of DB054 - DB054C2\DB054 [Redmine:#148785]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20221019@Kathy: allow settlement action by using NAP_Set_ServerAction [Redmine:#179274]
		- 20221109@Louisa: log more inf into [SiteDB_SettlementService_CalculationLog] for virtual sport [Redmine:#178694]
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]
		- 20230908@Louisa: Apply Company Max Payout for Non-sports [Redmine:#193259]
		
	Param: 
		+ @updatetype: 
			+ 1: update bettrans: transid, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, statusid, moddds
			+ 2: update bettransm for virtual racing
			+ 3: update bettrans for virtual racing
			+ 4: refund number game
			+ 5: cal/refund VS BetRadar parlay
			+ 6: update bettrans for recover single + main parlay VS Betradar in special delete		
			+ 7: Outright settlement
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @_xml				XML
			,@TransInfoJson		NVARCHAR(MAX)
			,@IsSiteDB			BIT = 0
			,@AllowCalculation	BIT
			,@AllowRefund 		BIT
			,@AllowUndo 		BIT
			,@ServerName		SYSNAME
			,@TicketType 		VARCHAR(1)
			
	SET @ServerName = @@SERVERNAME
	
	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT
			,@AllowRefund		= @AllowRefund OUTPUT
			,@AllowUndo			= @AllowUndo OUTPUT
			
		IF @AllowCalculation = 0 AND @Action = 'CAL'
			RETURN
			
		IF @AllowRefund = 0 AND @Action = 'REFUND' 
			RETURN
			
		IF @AllowUndo = 0 AND @Action = 'UNDO' 
			RETURN

	END

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog_3rd','U') IS NOT NULL 
		SET @IsSiteDB = 1
	
	DECLARE @tmpTransInfo TABLE (transId BIGINT
			,modds MONEY
			,statuswinlost TINYINT
			,winlostdate DATETIME
			,SettlementTime DATETIME
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,statusID TINYINT, status NVARCHAR(20), ruben TINYINT
			,hdp1 SMALLMONEY ,hdp2 SMALLMONEY
			,livehomescore INT,liveawayscore INT
			,creator INT
			,bef_winlost MONEY ,bef_statusid TINYINT
			,actualPO MONEY, IsApplyMaxPO BIT, extrainfo VARCHAR(1000)
			)

	SELECT @_xml = CONVERT(XML, @_sXML)

	IF @updatetype = 1 --Virtual Sports
	BEGIN
		;WITH sourceData AS (
			SELECT	
				T.C.value('./@q', 'bigint') as transid
				,ISNULL(T.C.value('./@a', 'money'), 0) as WinLost
				,ISNULL(T.C.value('./@z', 'money'), 0) as aWinLost
				,ISNULL(T.C.value('./@w', 'money'), 0) as mWinLost				
				,ISNULL(T.C.value('./@s', 'money'), 0) as sWinLost
				,ISNULL(T.C.value('./@x', 'money'), 0) as PlayerComm
				,ISNULL(T.C.value('./@e', 'money'), 0) as comm
				,ISNULL(T.C.value('./@d', 'money'), 0) as acomm
				,ISNULL(T.C.value('./@c', 'money'), 0) as scomm
				,T.C.value('./@r', 'tinyint') as StatusID
				,ISNULL(T.C.value('./@f', 'money'), 0) as modds
				,ISNULL(T.C.value('./@apo', 'money'), 0) as actualPO
				,ISNULL(T.C.value('./@iMPO', 'bit'), 0) as IsApplyMaxPO
			FROM @_xml.nodes('/root/r') as [T](C) --T: table, C: column
		)	
		UPDATE dbo.bettrans WITH(ROWLOCK, UPDLOCK)
		SET winlost = s.winlost
			,awinlost = s.awinlost
			,mwinlost = s.mwinlost
			,swinlost = s.swinlost
			,playercomm = s.playercomm
			,comm = s.comm
			,acomm = s.acomm
			,scomm = s.scomm
			,statusID = s.statusid
			,modds = s.modds
			,status = CASE s.statusid
				WHEN 112 THEN 'WON'
				WHEN 111 THEN 'DRAW'
				WHEN 113 THEN 'LOSE'
				WHEN 103 THEN 'Refund'
				WHEN 0 THEN 'Running'
				END 			
			,ruben = CASE 
				WHEN s.statusid IN (111,112,113,103) THEN 1
				ELSE 0 END	
			,ExtraInfo = CASE WHEN s.IsApplyMaxPO = 1 THEN ISNULL(bettrans.ExtraInfo,'') + '<l255 apo="'+ CAST(s.actualPO AS VARCHAR(100)) +'" />' ELSE  bettrans.ExtraInfo END
		OUTPUT	inserted.transid
			,inserted.modds
			,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
			,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
			,inserted.Status,inserted.StatusID,inserted.ruben,deleted.winlost ,deleted.statusid		
			,inserted.extrainfo
		INTO @tmpTransInfo ( transid,modds
			,WinLost,aWinLost,mWinLost,sWinLost
			,PlayerComm,Comm,aComm,sComm
			,Status,StatusID,ruben,bef_winlost ,bef_statusid 
			,extrainfo
			)			
		FROM sourceData s
		WHERE bettrans.transid = s.transid

		IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			SET @TransInfoJson = (
				SELECT	transId AS 't'
						,modds AS 'm'
						,WinLost AS 'w' 
						,aWinLost AS 'aw' 
						,mWinLost AS 'mw' 
						,sWinLost AS 'sw' 
						,PlayerComm AS 'pc' 
						,Comm AS 'c' 
						,aComm AS 'ac' 
						,sComm AS 'sc' 
						,Status AS 's' 
						,StatusID AS 'sid' 
						,ruben AS 'r'	
						,bef_winlost AS 'bef_w' 
						,bef_statusid AS 'bef_sid' 		
						,extrainfo AS 'ex'
				FROM	@tmpTransInfo
				FOR JSON AUTO
			)

			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLog_3rdIns 
				@SystemName = 'Settlement' 
				,@FunctionName = 'CalculateNonSport'
				,@TableName = 'bettrans'
				,@MatchId = @MatchId
				,@TransInfoJson = @TransInfoJson
				,@SettlementAction = 'CAL'
				,@TicketType = 's'
				,@EventTable = 1
		END
	END
	
	ELSE IF @updatetype = 2 --bettransm (for virtual racing) 
	BEGIN
		;WITH sourceData AS (
			SELECT	
				T.C.value('./@q', 'bigint') as transid
				,ISNULL(T.C.value('./@a', 'money'), 0) as WinLost
				,ISNULL(T.C.value('./@z', 'money'), 0) as aWinLost
				,ISNULL(T.C.value('./@w', 'money'), 0) as mWinLost				
				,ISNULL(T.C.value('./@s', 'money'), 0) as sWinLost
				,ISNULL(T.C.value('./@x', 'money'), 0) as PlayerComm
				,ISNULL(T.C.value('./@e', 'money'), 0) as comm
				,ISNULL(T.C.value('./@d', 'money'), 0) as acomm
				,ISNULL(T.C.value('./@c', 'money'), 0) as scomm
				,T.C.value('./@r', 'tinyint') as StatusID
				,ISNULL(T.C.value('./@h1', 'money'), 0) as hdp1
				,ISNULL(T.C.value('./@h2', 'money'), 0) as hdp2
				,ISNULL(T.C.value('./@l1', 'smallint'), 0) as livehomescore
				,ISNULL(T.C.value('./@l2', 'smallint'), 0) as liveawayscore
			FROM @_xml.nodes('/root/r') as [T](C) --T: table, C: column
		)	
		UPDATE dbo.bettransm WITH(ROWLOCK, UPDLOCK)
		SET winlost = s.winlost
			,awinlost = s.awinlost
			,mwinlost = s.mwinlost
			,swinlost = s.swinlost
			,playercomm = s.playercomm
			,comm = s.comm
			,acomm = s.acomm
			,scomm = s.scomm
			,statusID = s.statusid			
			,hdp1 = s.hdp1
			,hdp2 = s.hdp2
			,livehomescore = s.livehomescore
			,liveawayscore = s.liveawayscore
			,status = CASE s.statusid
				WHEN 112 THEN 'WON'
				WHEN 111 THEN 'DRAW'
				WHEN 113 THEN 'LOSE'
				WHEN 103 THEN 'Refund'
				WHEN 0 THEN 'Running'
				END 			
			,ruben = CASE 
				WHEN s.statusid IN (111,112,113,103) THEN 1
				ELSE 0 END	
		OUTPUT	inserted.transid
			,inserted.winlost ,inserted.awinlost ,inserted.mwinlost ,inserted.swinlost  
			,inserted.playercomm  ,inserted.comm  ,inserted.acomm ,inserted.scomm 
			,inserted.statusID  
			,inserted.hdp1 ,inserted.hdp2  
			,inserted.livehomescore ,inserted.liveawayscore 
			,inserted.status  
			,inserted.ruben
			,deleted.winlost ,deleted.statusid
		INTO @tmpTransInfo (transid,
			winlost,awinlost ,mwinlost ,swinlost  
			,playercomm  ,comm  ,acomm ,scomm 
			,statusID  ,hdp1  ,hdp2  
			,livehomescore,liveawayscore
			,status  
			,ruben
			,bef_winlost ,bef_statusid 
		)				
		FROM sourceData s
		WHERE bettransm.transid = s.transid

		IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			SET @TransInfoJson = (
				SELECT	transId AS 't'	
						,WinLost AS 'w' 
						,aWinLost AS 'aw' 
						,mWinLost AS 'mw' 
						,sWinLost AS 'sw' 
						,PlayerComm AS 'pc' 
						,Comm AS 'c' 
						,aComm AS 'ac' 
						,sComm AS 'sc' 
						,Status AS 's' 
						,StatusID AS 'sid' 
						,hdp1 AS 'hdp1' 
						,hdp2  AS 'hdp2'
						,livehomescore AS 'lh'
						,liveawayscore AS 'la'
						,ruben AS 'r'	
						,bef_winlost AS 'bef_w' 
						,bef_statusid AS 'bef_sid' 
				FROM	@tmpTransInfo
				FOR JSON AUTO
			)

			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLog_3rdIns 
				@SystemName = 'Settlement' 
				,@FunctionName = 'CalculateNonSport'
				,@TableName = 'bettransm'
				,@MatchId = @MatchId
				,@TransInfoJson = @TransInfoJson
				,@SettlementAction = @Action
				,@TicketType = 'p'
				,@EventTable = 1
		END
	END		
	ELSE IF @updatetype = 3 --bettrans (for virtual racing) 
	BEGIN
		;WITH sourceData AS (
			SELECT	
				T.C.value('./@q', 'bigint') as transid
				,ISNULL(T.C.value('./@a', 'money'), 0) as WinLost
				,ISNULL(T.C.value('./@z', 'money'), 0) as aWinLost
				,ISNULL(T.C.value('./@w', 'money'), 0) as mWinLost				
				,ISNULL(T.C.value('./@s', 'money'), 0) as sWinLost
				,ISNULL(T.C.value('./@x', 'money'), 0) as PlayerComm
				,ISNULL(T.C.value('./@e', 'money'), 0) as comm
				,ISNULL(T.C.value('./@d', 'money'), 0) as acomm
				,ISNULL(T.C.value('./@c', 'money'), 0) as scomm
				,T.C.value('./@r', 'tinyint') as StatusID
				,ISNULL(T.C.value('./@f', 'money'), 0) as modds				
				,ISNULL(T.C.value('./@h1', 'money'), 0) as hdp1
				,ISNULL(T.C.value('./@h2', 'money'), 0) as hdp2
				,ISNULL(T.C.value('./@l1', 'smallint'), 0) as livehomescore
				,ISNULL(T.C.value('./@l2', 'smallint'), 0) as liveawayscore
			FROM @_xml.nodes('/root/r') as [T](C) --T: table, C: column
		)	
		UPDATE dbo.bettrans WITH(ROWLOCK, UPDLOCK)
		SET winlost = s.winlost
			,awinlost = s.awinlost
			,mwinlost = s.mwinlost
			,swinlost = s.swinlost
			,playercomm = s.playercomm
			,comm = s.comm
			,acomm = s.acomm
			,scomm = s.scomm
			,statusID = s.statusid
			,modds = s.modds			
			,hdp1 = s.hdp1
			,hdp2 = s.hdp2
			,livehomescore = s.livehomescore
			,liveawayscore = s.liveawayscore
			,status = CASE s.statusid
				WHEN 112 THEN 'WON'
				WHEN 111 THEN 'DRAW'
				WHEN 113 THEN 'LOSE'
				WHEN 103 THEN 'Refund'
				WHEN 0 THEN 'Running'
				END 			
			,ruben = CASE 
				WHEN s.statusid in (111,112,113,103) THEN 1
				ELSE 0 END			
		FROM sourceData s
		WHERE bettrans.transid = s.transid
	END		
	ELSE IF @updatetype = 4 --refund number game
	BEGIN		
		DECLARE @mode varchar(10)

		SELECT @matchid = T.C.value('./@matchid', 'int')-- as matchid
			,@action = ISNULL(T.C.value('./@action', 'varchar(10)'), 0)-- as [action]
		from @_xml.nodes('/root/r') as [T](C) --T: table, C: column

		IF @mode = 'Refund-FT'
		BEGIN
			UPDATE dbo.bettrans WITH (ROWLOCK,UPDLOCK)
			SET WinLost = actual_stake
				,aWinLost = 0
				,mWinLost = 0
				,sWinLost = 0
				,PlayerComm = 0
				,Comm = 0
				,aComm = 0
				,sComm = 0
				,[Status] = N'Refund'
				,StatusID = 103
				,ruben = 1
			OUTPUT	inserted.transid
				,inserted.modds
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID,inserted.ruben
				,deleted.winlost ,deleted.statusid
			INTO @tmpTransInfo ( transid,modds
				,WinLost,aWinLost,mWinLost,sWinLost
				,PlayerComm,Comm,aComm,sComm
				,Status,StatusID,ruben
				,bef_winlost ,bef_statusid 
				)	
			WHERE matchid = @matchid 
				AND statusID IN (0, 1) -- only refund all running/waiting's tickets
				AND bettype BETWEEN 81 AND 120
				AND SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN SiteDBGroupID ELSE 0 END

			IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
			BEGIN
				SET @TransInfoJson = (
					SELECT	transId AS 't'
							,modds AS 'm'
							,WinLost AS 'w' 
							,aWinLost AS 'aw' 
							,mWinLost AS 'mw' 
							,sWinLost AS 'sw' 
							,PlayerComm AS 'pc' 
							,Comm AS 'c' 
							,aComm AS 'ac' 
							,sComm AS 'sc' 
							,Status AS 's' 
							,StatusID AS 'sid' 
							,ruben AS 'r'	
							,bef_winlost AS 'bef_w' 
							,bef_statusid AS 'bef_sid' 
					FROM	@tmpTransInfo
					FOR JSON AUTO
				)

				EXEC dbo.SiteDB_NAP_SettlementService_CalculationLog_3rdIns 
					@SystemName = 'Settlement' 
					,@FunctionName = 'CalculateNonSport'
					,@TableName = 'bettrans'
					,@MatchId = @MatchId
					,@TransInfoJson = @TransInfoJson
					,@SettlementAction = 'REFUND'
					,@TicketType = 's'
					,@EventTable = 1
					
			END
		END
		ELSE
		BEGIN
			UPDATE dbo.bettrans WITH (ROWLOCK,UPDLOCK)
			SET WinLost = actual_stake
				,aWinLost = 0
				,mWinLost = 0
				,sWinLost = 0
				,PlayerComm = 0
				,Comm = 0
				,aComm = 0
				,sComm = 0
				,[Status] = N'Refund'
				,StatusID = 103
				,ruben = 1
			OUTPUT	inserted.transid
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID,inserted.ruben
				,deleted.winlost ,deleted.statusid
			INTO @tmpTransInfo ( transid
				,WinLost,aWinLost,mWinLost,sWinLost
				,PlayerComm,Comm,aComm,sComm
				,Status,StatusID,ruben
				,bef_winlost ,bef_statusid 
				)
			WHERE matchid = @matchid 
				AND statusID NOT IN (101,102) -- refund all, except void/reject
				AND bettype BETWEEN 81 AND 120
				AND SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN SiteDBGroupID ELSE 0 END

			IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
			BEGIN
				SET @TransInfoJson = (
					SELECT	transId AS 't'
							,WinLost AS 'w' 
							,aWinLost AS 'aw' 
							,mWinLost AS 'mw' 
							,sWinLost AS 'sw' 
							,PlayerComm AS 'pc' 
							,Comm AS 'c' 
							,aComm AS 'ac' 
							,sComm AS 'sc' 
							,Status AS 's' 
							,StatusID AS 'sid' 
							,ruben AS 'r'	
							,bef_winlost AS 'bef_w' 
							,bef_statusid AS 'bef_sid' 
					FROM	@tmpTransInfo
					FOR JSON AUTO
				)
				
				EXEC dbo.SiteDB_NAP_SettlementService_CalculationLog_3rdIns 
					@SystemName = 'Settlement' 
					,@FunctionName = 'CalculateNonSport'
					,@TableName = 'bettrans'
					,@MatchId = @MatchId
					,@TransInfoJson = @TransInfoJson
					,@SettlementAction = 'REFUND'
					,@TicketType = 's'
					,@EventTable = 1
				
			END
		END		
	END
	ELSE IF @updatetype = 5 --CAL/REFUND/VOID VS BetRadar parlay
	BEGIN
		;WITH sourceData AS (
			SELECT	
				T.C.value('./@t', 'bigint') as transid
				,T.C.value('./@d', 'DATE') as winlostdate
				,T.C.value('./@w', 'TINYINT') as statuswinlost
				,T.C.value('./@s', 'TINYINT') as statusId				
				,T.C.value('./@cr', 'INT') as creator  
			FROM @_xml.nodes('/root/r') as [T](C) --T: table, C: column
		)	
		UPDATE dbo.bettransm WITH(ROWLOCK, UPDLOCK)
		SET winlostdate		= s.winlostdate
			,statuswinlost	= s.statuswinlost
			,statusId		= s.statusId
			,status			= CASE s.statusid
				WHEN 112 THEN 'WON'
				WHEN 111 THEN 'DRAW'
				WHEN 113 THEN 'LOSE'
				WHEN 103 THEN 'Refund'
				WHEN 0 THEN 'Running'
				WHEN 102 THEN 'VOID'
				END 			
			,ruben = CASE 
				WHEN s.statusid IN (111,112,113,103,102) THEN 1
				ELSE 0 END
			,creator = ISNULL(s.creator, bettransm.creator)  
		OUTPUT inserted.transid
			,inserted.winlostdate ,inserted.statuswinlost 
			,inserted.statusId ,inserted.status ,inserted.ruben ,inserted.creator
			,deleted.winlost ,deleted.statusid
		INTO @tmpTransInfo (
			transid
			, winlostdate ,statuswinlost 
			,statusId ,status ,ruben ,creator 
			,bef_winlost ,bef_statusid 
			)
		FROM sourceData s
		WHERE bettransm.transid = s.transid

		IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			SET @TransInfoJson = (
				SELECT	transId AS 't'
						,CASE WHEN winlostdate IS NULL THEN '' ELSE winlostdate END AS 'wld'
						,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1) ) END AS 'statuswl'
						,Status AS 's' 
						,StatusID AS 'sid' 
						,ruben AS 'r'	
						,creator AS 'cr'
						,bef_winlost AS 'bef_w' 
						,bef_statusid AS 'bef_sid' 
				FROM	@tmpTransInfo
				FOR JSON AUTO
			)

			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLog_3rdIns 
				@SystemName = 'Settlement' 
				,@FunctionName = 'CalculateVSBetRadar'
				,@TableName = 'bettransm'
				,@MatchId = @MatchId
				,@TransInfoJson = @TransInfoJson
				,@SettlementAction = @Action
				,@TicketType = 'p'
				,@EventTable = 1
		END

	END
	ELSE IF @updatetype = 6 --update bettrans for recover single + main parlay VS Betradar in special delete
	BEGIN
		;WITH sourceData AS (
			SELECT	
				T.C.value('./@q', 'bigint') as transid
				,T.C.value('./@cr', 'INT') as creator
			FROM @_xml.nodes('/root/r') as [T](C) --T: table, C: column
		)	
		UPDATE dbo.bettrans WITH(ROWLOCK, UPDLOCK)
		SET winlost = 0			
			,statusID = 0				
			,statuswinlost = NULL
			,creator = s.creator
			,status = 'Running' 			
			,ruben = 0
		OUTPUT inserted.transid
			,inserted.statuswinlost
			,inserted.winlost
			,inserted.statusId ,inserted.status ,inserted.ruben ,inserted.creator
			,deleted.winlost ,deleted.statusid
		INTO @tmpTransInfo (
			transid 
			,statuswinlost ,winlost, statusId ,status ,ruben ,creator
			,bef_winlost ,bef_statusid 
			)
		FROM sourceData s
		WHERE bettrans.transid = s.transid

		IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			SET @TransInfoJson = (
				SELECT	transId AS 't'
						,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1) ) END AS 'statuswl'
						,WinLost AS 'w'
						,Status AS 's' 
						,StatusID AS 'sid' 
						,ruben AS 'r'	
						,creator AS 'cr'
				FROM	@tmpTransInfo
				FOR JSON AUTO
			)

			SET @TicketType = CASE WHEN @MatchId = 2799 THEN 'p' ELSE 's' END
			
			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLog_3rdIns 
				@SystemName = 'Settlement' 
				,@FunctionName = 'RecoverVSBetRadar'
				,@TableName = 'bettrans'
				,@MatchId = @MatchId
				,@TransInfoJson = @TransInfoJson
				,@EventTable = 1
				,@TicketType = @TicketType
			
		END
	END
	ELSE IF @updatetype = 7 -- outright settlement
	BEGIN
		DECLARE @settlementTime DATETIME
		SET @settlementTime = GETDATE(); 

		;WITH sourceData AS (
			SELECT	
				T.C.value('./@t', 'BIGINT') as transid
				,ISNULL(T.C.value('./@w', 'MONEY'), 0) as WinLost
				,ISNULL(T.C.value('./@aw', 'MONEY'), 0) as aWinLost
				,ISNULL(T.C.value('./@mw', 'MONEY'), 0) as mWinLost				
				,ISNULL(T.C.value('./@sw', 'MONEY'), 0) as sWinLost
				,ISNULL(T.C.value('./@p', 'MONEY'), 0) as PlayerComm
				,ISNULL(T.C.value('./@c', 'MONEY'), 0) as comm
				,ISNULL(T.C.value('./@ac', 'MONEY'), 0) as acomm
				,ISNULL(T.C.value('./@sc', 'MONEY'), 0) as scomm
				,T.C.value('./@sid', 'TINYINT') as StatusID
				,T.C.value('./@s', 'NVARCHAR(10)') as status				
				,T.C.value('./@wld', 'SMALLDATETIME') as winlostdate
				,T.C.value('./@swd', 'TINYINT') as statuswinlost
				,T.C.value('./@r', 'TINYINT') as ruben
			FROM @_xml.nodes('/root/r') as [T](C) --T: table, C: column
		)	
		UPDATE dbo.bettrans WITH(ROWLOCK, UPDLOCK)
			SET SettlementTime = CASE WHEN s.StatusID <> 0 AND (bettrans.winlost <> s.WinLost OR bettrans.statusID <> s.StatusID) THEN @settlementTime ELSE SettlementTime END
				,winlost = s.winlost
				,awinlost = s.awinlost
				,mwinlost = s.mwinlost
				,swinlost = s.swinlost
				,playercomm = s.playercomm
				,comm = s.comm
				,acomm = s.acomm
				,scomm = s.scomm
				,statusID = s.statusid
				,status =s.status	
				,winlostdate=s.winlostdate
				,statuswinlost=s.statuswinlost
				,ruben = s.ruben
		OUTPUT inserted.transid
			,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
			,inserted.winlost ,inserted.awinlost,inserted.mwinlost,inserted.swinlost
			,inserted.playercomm ,inserted.comm ,inserted.acomm  ,inserted.scomm  
			,inserted.statusID,inserted.status  
			,inserted.winlostdate ,inserted.statuswinlost
			,inserted.ruben  
			,deleted.winlost ,deleted.statusid
		INTO @tmpTransInfo (
			 transid
			,SettlementTime
			,winlost,awinlost,mwinlost,swinlost
			,playercomm ,comm ,acomm  ,scomm  
			,statusID,status  
			,winlostdate ,statuswinlost
			,ruben  
			,bef_winlost ,bef_statusid 
		)
		FROM sourceData s
		WHERE bettrans.transid = s.transid
		
		IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			SET @TransInfoJson = (
				SELECT	 transid AS 't'
						,@matchid AS 'mid'
						,SettlementTime AS 'st'
						,winlost AS 'w' 
						,awinlost AS 'aw' 
						,mwinlost AS 'mw' 
						,swinlost AS 'sw' 
						,playercomm AS 'pc' 
						,comm AS 'c' 
						,acomm  AS 'ac' 
						,scomm  AS 'sc' 
						,statusID AS 'sid' 
						,status   AS 's' 
						,winlostdate AS 'wld' 
						,statuswinlost AS 'statuswl' 
						,ruben  AS 'r' 
				FROM	@tmpTransInfo
				FOR JSON AUTO
			)
			
			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLog_3rdIns 
				@SystemName = 'Settlement' 
				,@FunctionName = 'CalculateNonSport'
				,@TableName = 'bettrans'
				,@MatchId = @MatchId
				,@TransInfoJson = @TransInfoJson
				,@SettlementAction = @Action
				,@TicketType = 's'
				,@EventTable = 2				
		END

	END
END
GO