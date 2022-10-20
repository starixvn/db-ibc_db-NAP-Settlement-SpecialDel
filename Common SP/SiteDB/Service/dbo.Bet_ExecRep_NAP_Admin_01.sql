/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Bet_ExecRep_NAP_Admin_01] 	
	@TransInfo	XML
	,@TableName VARCHAR(128)
	,@Action	VARCHAR(1)	= 'U'
	,@MatchId	INT			= 0
	,@TicketType VARCHAR(1) = NULL
	,@SettlementAction VARCHAR(20) = NULL
	,@RunOnServer VARCHAR(100)= NULL
	,@CalledByBrokerService	BIT = 0
AS
/*
	Created by: 20220728@Kathy
	Task: Settlement  

	Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20220926@Louisa: Fix issue cannot syn modds NULL from SiteDB to CentralDB [Redmine:178189]
		- 20220928@July: Fix issue update column winlost dbo.bettransm [Redmine:178332]
		- 20221003@Kathy: Retry if deadlock occurs [Redmine:#178542]
		- 20221008@Patrick: Check transId before insert markedtransaction
		- 20221019@Kathy: Set @ServerName [Redmine:#179274]

	Param's Explanation:  
		   
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @batchNo		INT			
			,@matchdate		SMALLDATETIME
			,@strTransIds	VARCHAR(MAX)
			,@sMessage		NVARCHAR(MAX)
			,@IsEnableServiceBroker BIT

			,@AllowUndo		BIT
			,@AllowRefund	BIT
			,@AllowCalculation		BIT
			,@ServerName	SYSNAME

			,@maxTryCount TINYINT
			,@TryCount	TINYINT
			,@errcode INT
			,@errmsg VARCHAR(1024)
		
	DECLARE @tmpTransId TABLE (transId BIGINT, refno BIGINT
		,matchid INT, winlostdate DATETIME, betdaqid VARCHAR(50)
		,modds VARCHAR(11), odds SMALLMONEY, oddsid INT, oddsspread VARCHAR(20), statuswinlost VARCHAR(1),SettlementTime DATETIME
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT,FcUpdateTime DATETIME2, creator INT
		,hdp1 SMALLMONEY, hdp2 SMALLMONEY, livehomescore SMALLINT, liveawayscore SMALLINT
		,custid INT, bettype SMALLINT, userid INT , CreatedDate DATETIME, MarkType TINYINT, betid VARCHAR(50), ExtraInfo VARCHAR(1000)
		
		,transdate	 DATETIME 
		,comstatus NVARCHAR(40),checktime	DATETIME	
		,actualrate	FLOAT,recommend	INT	,mrecommend	INT	,srecommend	INT, stake MONEY,actual_stake MONEY	
		,currency	TINYINT	
		,Username	NVARCHAR(100),CurrencyName	NVARCHAR(100),virtualrate	FLOAT	
	)

	SET @RunOnServer = ISNULL(@RunOnServer,@@SERVERNAME)
	SET @ServerName = @@SERVERNAME

	IF @RunOnServer <> @@SERVERNAME
	BEGIN
		PRINT 'This command was skipped because run wrong server'
		RETURN
	END

	IF @TicketType = 'p' 
			AND @@SERVERNAME IN ('DB054','DB054C2\DB054','DB042', 'SITDB042', 'DB055', 'SITDB055')
        RETURN

	IF @TicketType = 's' 
			AND @@SERVERNAME IN ('DB054','DB054C2\DB054','DB042', 'SITDB042','DB232\SQLSERVER2008R2', 'DB233\SQLSERVER2008R2', 'TESTDB055', 'SITDB055', 'DB055', 'DB-61\DEVDB055' ) 
			AND @SettlementAction IN ('CAL', 'REFUND')
		RETURN

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		IF @SettlementAction = 'UNDO'
		BEGIN
			EXEC [dbo].[NAP_Set_ServerAction]
				@ServerName			= @ServerName
				,@AllowUndo			= @AllowUndo		OUTPUT

			IF @AllowUndo = 0
				RETURN
		END
		ELSE IF @SettlementAction = 'REFUND'
		BEGIN
			EXEC [dbo].[NAP_Set_ServerAction]
				@ServerName			= @ServerName
				,@AllowRefund		= @AllowRefund		OUTPUT

			IF @AllowRefund = 0
				RETURN
		END
		ELSE IF @SettlementAction = 'CAL'
		BEGIN
			EXEC [dbo].[NAP_Set_ServerAction]
				@ServerName			= @ServerName
				,@AllowCalculation	= @AllowCalculation	OUTPUT

			IF @AllowCalculation = 0
				RETURN
		END
	END

	EXEC dbo.NAP_Set_ServerInfo 
		@IsEnableServiceBroker = @IsEnableServiceBroker OUTPUT

	IF @IsEnableServiceBroker = 1 AND @CalledByBrokerService = 0
    BEGIN
		SET @sMessage = 'EXEC dbo.Bet_ExecRep_NAP_Admin_01 @matchid = ' + CONVERT(NVARCHAR(50), ISNULL(@matchid,0)) 
							+ ',@TransInfo = ' +  '''' + CONVERT(NVARCHAR(MAX), @TransInfo) + ''''
							+ ',@TableName = ' + CASE
													WHEN @TableName IS NULL THEN 'NULL'
													ELSE '''' + @TableName + ''''
													END 
							+ ',@Action = ' + CASE
													WHEN @Action IS NULL THEN 'NULL'
													ELSE '''' + @Action + ''''
													END 
							+ ',@TicketType = ' + CASE
													WHEN @TicketType IS NULL THEN 'NULL'
													ELSE '''' + @TicketType + ''''
													END 														
							+ ',@SettlementAction = ' + CASE
													WHEN @SettlementAction IS NULL THEN 'NULL'
													ELSE '''' + @SettlementAction + ''''
													END 
							+ ',@RunOnServer = ' + CASE
													WHEN @RunOnServer IS NULL THEN 'NULL'
													ELSE '''' + @RunOnServer + ''''
													END 
							+ ',@CalledByBrokerService = 1'
		
		EXEC dbo.SSB_Send_Message 
			@MessageContent = @sMessage
			,@FunctionName = 'settlement'
			,@MessageType = 'bet_SiteDB_msg_type_01'
	END
	ELSE
	BEGIN
		SET @maxTryCount = 5	
		SET @TryCount = 0

		WHILE (1=1)
		BEGIN
			BEGIN TRY	
				SET @errcode = 0
				SET @errmsg = NULL

				DELETE @tmpTransId

				IF @tablename = 'bettrans'
				BEGIN
					INSERT INTO @tmpTransId (TransID
						,matchid, winlostdate, betdaqid
						,modds, odds, oddsid, oddsspread, statuswinlost,SettlementTime,WinLost,aWinLost
						,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben,FcUpdateTime
						, hdp1 , hdp2 , livehomescore , liveawayscore , creator, betid, ExtraInfo		
						,virtualrate	 
					)
					SELECT	T.C.value('./@t', 'bigint') AS transid
							,T.C.value('./@mid', 'INT') AS matchid
							,T.C.value('./@wld', 'SMALLDATETIME') AS winlostdate
							,T.C.value('./@bdaq', 'VARCHAR(50)') AS betdaqid
							,T.C.value('./@m', 'VARCHAR(11)') AS modds
							,T.C.value('./@o', 'SMALLMONEY') AS odds
							,T.C.value('./@oid', 'INT') AS oddsid
							,T.C.value('./@os', 'VARCHAR(20)') AS oddsspread
							,T.C.value('./@statuswl', 'VARCHAR(1)') AS statuswinlost
							,T.C.value('./@st', 'DATETIME') AS SettlementTime
							,T.C.value('./@w', 'MONEY') AS WinLost
							,T.C.value('./@aw', 'MONEY') AS aWinLost
							,T.C.value('./@mw', 'MONEY') AS mWinLost
							,T.C.value('./@sw', 'MONEY') AS sWinLost
							,T.C.value('./@pc', 'MONEY') AS PlayerComm
							,T.C.value('./@c', 'MONEY') AS Comm 
							,T.C.value('./@ac', 'MONEY') AS aComm
							,T.C.value('./@sc', 'MONEY') AS sComm
							,T.C.value('./@s', 'NVARCHAR(10)')	AS [Status]
							,T.C.value('./@sid', 'TINYINT')		AS StatusID
							,T.C.value('./@r', 'TINYINT')		AS ruben
							,T.C.value('./@rut', 'DATETIME2')	AS FcUpdateTime	
							,T.C.value('./@hdp1', 'SMALLMONEY') AS hdp1
							,T.C.value('./@hdp2', 'SMALLMONEY') AS hdp2
							,T.C.value('./@lh', 'SMALLINT') AS livehomescore
							,T.C.value('./@la', 'SMALLINT') AS liveawayscore
							,T.C.value('./@cr', 'INT') AS creator
							,T.C.value('./@bid', 'VARCHAR(50)') AS betid
							,T.C.value('./@ex', 'VARCHAR(1000)') AS ExtraInfo	  
							,T.C.value('./@v', 'FLOAT') AS virtualrate
					FROM	@transInfo.nodes('/root/r') AS T(C)
					OPTION (OPTIMIZE FOR (@transInfo = NULL ))

					SET @batchNo = @@ROWCOUNT

					IF @Action = 'U'
					BEGIN
						UPDATE TOP (@batchNo) b
							SET
								matchid = CASE WHEN t.matchid IS NULL THEN b.matchid ELSE t.matchid END
								,winlostdate = CASE WHEN t.winlostdate IS NULL THEN b.winlostdate ELSE t.winlostdate END
								,betdaqid = CASE WHEN t.betdaqid IS NULL THEN b.betdaqid ELSE CAST(t.betdaqid AS BIGINT) END
								,modds = CASE WHEN t.modds IS NULL THEN b.modds 
												WHEN t.modds = '' THEN NULL
												ELSE CAST(t.modds AS SMALLMONEY ) 
										 END
								,odds = CASE WHEN t.odds IS NULL THEN b.odds ELSE t.odds END
								,oddsid = CASE WHEN t.oddsid IS NULL THEN b.oddsid ELSE t.oddsid END
								,oddsspread = CASE WHEN t.oddsspread IS NULL THEN b.oddsspread ELSE CAST(t.oddsspread AS MONEY) END  	
								,statuswinlost = CASE 
													WHEN t.statuswinlost IS NULL THEN b.statuswinlost
													WHEN t.statuswinlost = '' THEN NULL
													ELSE CAST(t.statuswinlost AS TINYINT)
												END
								,SettlementTime = CASE WHEN t.SettlementTime IS NULL THEN b.SettlementTime ELSE GETDATE() END						
								,WinLost = CASE WHEN t.WinLost IS NULL THEN b.winlost ELSE t.WinLost END
								,aWinLost = CASE WHEN t.aWinLost IS NULL THEN b.awinlost ELSE t.aWinLost END			
								,mWinLost = CASE WHEN t.mWinLost IS NULL THEN b.mwinlost ELSE t.mWinLost END
								,sWinLost = CASE WHEN t.sWinLost IS NULL THEN b.swinlost ELSE t.sWinLost END
								,PlayerComm = CASE WHEN t.PlayerComm IS NULL THEN b.playercomm ELSE t.PlayerComm END
								,Comm = CASE WHEN t.Comm IS NULL THEN b.comm ELSE t.Comm END					
								,aComm = CASE WHEN t.aComm IS NULL THEN b.acomm  ELSE t.aComm END					
								,sComm = CASE WHEN t.sComm IS NULL THEN b.scomm ELSE t.sComm END					
								,Status = CASE WHEN t.Status IS NULL THEN b.status ELSE t.Status END
								,StatusID = CASE WHEN t.StatusID IS NULL THEN b.statusID ELSE t.StatusID END
								,ruben= CASE WHEN t.ruben IS NULL THEN b.ruben ELSE t.ruben END
								,FcUpdateTime = CASE WHEN t.FcUpdateTime IS NULL THEN b.FcUpdateTime ELSE SYSDATETIME() END
								,hdp1 = CASE WHEN t.hdp1 IS NULL THEN b.hdp1 ELSE t.hdp1 END					
								,hdp2 = CASE WHEN t.hdp2 IS NULL THEN b.hdp2  ELSE t.hdp2 END					
								,livehomescore = CASE WHEN t.livehomescore IS NULL THEN b.livehomescore ELSE t.livehomescore END					
								,liveawayscore = CASE WHEN t.liveawayscore IS NULL THEN b.liveawayscore ELSE t.liveawayscore END									
								,creator = CASE WHEN t.creator IS NULL THEN b.creator ELSE t.creator END
								,betid = CASE WHEN t.betid IS NULL THEN b.betid ELSE CAST(t.betid AS BIGINT) END
								,ExtraInfo = CASE WHEN t.ExtraInfo IS NULL THEN b.ExtraInfo ELSE t.ExtraInfo END
								,virtualrate = CASE WHEN t.virtualrate IS NULL THEN b.virtualrate ELSE t.virtualrate END
						FROM @tmpTransId t
							INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) 
								ON  t.transid = b.transid 
						OPTION (OPTIMIZE FOR (@batchNo = 1), FORCE ORDER)
					END			
				END
				ELSE IF @TableName = 'bettransm'
				BEGIN
					INSERT INTO @tmpTransId (TransID, matchid
						,winlostdate, statuswinlost, refno, WinLost
						, Status, StatusID, ruben, hdp1, hdp2, livehomescore, liveawayscore, Creator
					)
					SELECT	T.C.value('./@t', 'bigint') AS transid
						,T.C.value('./@mid', 'INT') AS matchid
							,T.C.value('./@wld', 'SMALLDATETIME') AS Winlostdate
							,T.C.value('./@statuswl', 'VARCHAR(1)') AS statuswinlost
							,T.C.value('./@ref', 'BIGINT') AS refno
							,T.C.value('./@w', 'MONEY') AS WinLost	
							,T.C.value('./@s', 'NVARCHAR(10)') AS Status
							,T.C.value('./@sid', 'TINYINT') AS StatusID
							,T.C.value('./@r', 'TINYINT') AS ruben	
							,T.C.value('./@hdp1', 'SMALLMONEY') AS hdp1
							,T.C.value('./@hdp2', 'SMALLMONEY') AS hdp2
							,T.C.value('./@lh', 'SMALLINT') AS livehomescore
							,T.C.value('./@la', 'SMALLINT') AS liveawayscore	
							,T.C.value('./@cr', 'INT') AS Creator
					FROM	@transInfo.nodes('/root/r') AS T(C)
					OPTION (OPTIMIZE FOR (@transInfo = NULL ))

					SET @batchNo = @@ROWCOUNT

					UPDATE TOP (@batchNo)  bm
					SET matchid = CASE WHEN t.matchid IS NULL THEN bm.matchid ELSE t.matchid END
						,ruben = CASE WHEN t.ruben IS NULL THEN bm.ruben ELSE t.ruben END								
							,winlostdate = CASE 
												WHEN t.winlostdate IS NULL THEN bm.winlostdate	
												WHEN t.winlostdate = '' THEN NULL
												ELSE t.winlostdate
											END
							,WinLost = CASE WHEN t.WinLost IS NULL THEN bm.winlost ELSE t.WinLost END
							,[status] = CASE WHEN t.Status IS NULL THEN bm.status ELSE t.Status END
							,statusID = CASE WHEN t.StatusID IS NULL THEN bm.statusID ELSE t.StatusID END								
							,statuswinlost = CASE 
												WHEN t.statuswinlost IS NULL THEN bm.statuswinlost
												WHEN t.statuswinlost = '' THEN NULL
												ELSE CAST(t.statuswinlost AS TINYINT)
											END
							,hdp1 = CASE WHEN t.hdp1 IS NULL THEN bm.hdp1 ELSE t.hdp1 END					
							,hdp2 = CASE WHEN t.hdp2 IS NULL THEN bm.hdp2  ELSE t.hdp2 END					
							,livehomescore = CASE WHEN t.livehomescore IS NULL THEN bm.livehomescore ELSE t.livehomescore END					
							,liveawayscore = CASE WHEN t.liveawayscore IS NULL THEN bm.liveawayscore ELSE t.liveawayscore END									
							,creator = CASE WHEN t.creator IS NULL THEN bm.creator ELSE t.creator END
					FROM	@tmptransid t
						INNER JOIN dbo.bettransm bm WITH (ROWLOCK, UPDLOCK)
							ON	bm.transid = t.transid
					--OPTION (OPTIMIZE FOR (@batchNo = 1), FORCE ORDER)
				END
				ELSE IF @TableName = 'BetParlayDetail'
				BEGIN
					INSERT INTO @tmpTransId (TransID, matchid
						,winlostdate, statuswinlost, StatusID
					)
					SELECT	T.C.value('./@t', 'bigint') AS transid
						,T.C.value('./@mid', 'INT') AS matchid
							,CASE 
								WHEN T.C.value('./@wld', 'SMALLDATETIME') = '' THEN NULL 
								ELSE T.C.value('./@wld', 'SMALLDATETIME') 
							END AS winlostdate
							,T.C.value('./@statuswl', 'VARCHAR(1)')				
							,T.C.value('./@sid', 'TINYINT') AS StatusID									
					FROM	@transInfo.nodes('/root/r') AS T(C)
					OPTION (OPTIMIZE FOR (@transInfo = NULL ))

					UPDATE pd 
					SET matchid = CASE WHEN t.matchid IS NULL THEN pd.matchid ELSE t.matchid END
						,winlostdate = CASE	
											WHEN t.winlostdate IS NULL THEN pd.winlostdate
											WHEN t.winlostdate = '' THEN NULL
											ELSE t.winlostdate
										END
							,statusID = CASE WHEN t.StatusID IS NULL THEN pd.statusid ELSE t.StatusID END			
							,statuswinlost = CASE 
												WHEN t.statuswinlost IS NULL THEN pd.statuswinlost
												WHEN t.statuswinlost = '' THEN NULL
												ELSE CAST(t.statuswinlost AS TINYINT)
											END		
					FROM   @tmpTransId t
						INNER JOIN dbo.BetParlayDetail pd WITH(ROWLOCK, UPDLOCK)
							ON  pd.transid = t.transid
					--OPTION (OPTIMIZE FOR (@batchNo = 1), FORCE ORDER)
				END
				ELSE IF @TableName = 'MarkedTransaction'
				BEGIN
					IF @Action = 'I'
					BEGIN
						INSERT INTO @tmpTransId (TransID ,matchid, custid, bettype, userid, CreatedDate, MarkType)
						SELECT	T.C.value('./@t', 'BIGINT') AS transid
								,T.C.value('./@mid', 'INT') AS matchid
								,T.C.value('./@cust', 'INT') AS custid
								,T.C.value('./@btype', 'SMALLINT') AS bettype			
								,T.C.value('./@us', 'INT') AS userid	
								,T.C.value('./@crdate', 'DATETIME') AS CreatedDate
								,T.C.value('./@mt', 'TINYINT') AS MarkType		
						FROM	@transInfo.nodes('/root/r') AS T(C)
						OPTION (OPTIMIZE FOR (@transInfo = NULL ))

						INSERT INTO dbo.MarkedTransaction (TransID ,matchid, custid, bettype, userid, CreatedDate, MarkType)
						SELECT 	TransID ,matchid, custid, bettype, userid, CreatedDate, MarkType
						FROM 	@tmpTransId t 
						WHERE 	NOT EXISTS (SELECT 	TOP 1 1 
											FROM 	dbo.MarkedTransaction m WITH(NOLOCK) 
											WHERE 	m.TransId = t.transId 
													AND m.MatchId = t.matchid
									)
					END
					ELSE IF @Action = 'D'
					BEGIN
						INSERT INTO @tmpTransId (TransID ,matchid)
						SELECT	T.C.value('./@t', 'bigint') AS transid
							   ,T.C.value('./@mid', 'INT') AS matchid
						FROM	@transInfo.nodes('/root/r') AS T(C)
						OPTION (OPTIMIZE FOR (@transInfo = NULL ))

						DELETE m 
						FROM dbo.MarkedTransaction m WITH (ROWLOCK, UPDLOCK)
							INNER JOIN @tmpTransId t ON t.TransId = m.TransId AND t.MatchId = m.MatchId
					END
				END
				ELSE IF @TableName = 'zzzbettrans' AND OBJECT_ID('zzzbettrans','U') IS NOT NULL
				BEGIN
					IF @Action = 'U'
					BEGIN
						INSERT INTO @tmpTransId (TransID ,matchid, Status, WinLost)
						SELECT	T.C.value('./@t', 'bigint') AS transid	
							,T.C.value('./@mid', 'INT') AS matchid	
							,T.C.value('./@s', 'NVARCHAR(10)') AS Status	
							,T.C.value('./@w', 'MONEY') AS WinLost	
						FROM	@transInfo.nodes('/root/r') AS T(C)	
						OPTION (OPTIMIZE FOR (@transInfo = NULL ))		

						SET @batchNo = @@ROWCOUNT

						UPDATE TOP (@batchNo)  b
							SET [status] = CASE WHEN t.Status IS NULL THEN b.status ELSE t.Status END
								,WinLost = CASE WHEN t.WinLost IS NULL THEN b.winlost ELSE t.WinLost END
						FROM	@tmptransid t
							INNER JOIN dbo.zzzbettrans b WITH (ROWLOCK, UPDLOCK)
								ON	b.transid = t.transid
					END
					ELSE IF @Action = 'D'
					BEGIN
						INSERT INTO @tmpTransId (TransID ,matchid, transdate, comstatus)
						SELECT	T.C.value('./@t', 'bigint') AS transid
							   ,T.C.value('./@mid', 'INT') AS matchid
							   ,T.C.value('./@td', 'datetime') AS transdate
								,T.C.value('./@cst', 'nvarchar(40)') AS comstatus
						FROM	@transInfo.nodes('/root/r') AS T(C)
						OPTION (OPTIMIZE FOR (@transInfo = NULL ))

						DELETE m 
						FROM dbo.zzzbettrans m WITH (ROWLOCK, UPDLOCK)
							INNER JOIN @tmpTransId t ON t.TransId = m.TransId AND t.MatchId = m.MatchId 
												AND ISNULL(m.comstatus, '') = ISNULL(t.comstatus, '')
												AND m.transdate = t.transdate
					END
				END
				ELSE IF @TableName = 'zzzbettransm' AND OBJECT_ID('zzzbettransm','U') IS NOT NULL
				BEGIN
					IF @Action = 'U'
					BEGIN
						INSERT INTO @tmpTransId (TransID ,matchid)
						SELECT	T.C.value('./@t', 'bigint') AS transid	
							,T.C.value('./@mid', 'INT') AS matchid
						FROM	@transInfo.nodes('/root/r') AS T(C)	
						OPTION (OPTIMIZE FOR (@transInfo = NULL ))		

						SET @batchNo = @@ROWCOUNT

						UPDATE TOP (@batchNo)  b
							SET matchid = CASE WHEN t.matchid IS NULL THEN b.matchid ELSE t.matchid END
						FROM	@tmptransid t
							INNER JOIN dbo.zzzbettransm b WITH (ROWLOCK, UPDLOCK)
								ON	b.transid = t.transid
					END
					ELSE IF @Action = 'D' --TVS subparlay
					BEGIN
						INSERT INTO @tmpTransId (TransID ,matchid)
						SELECT	T.C.value('./@t', 'BIGINT') AS transid	
							   ,T.C.value('./@mid', 'INT') AS matchid
						FROM	@transInfo.nodes('/root/r') AS T(C)	
						OPTION (OPTIMIZE FOR (@transInfo = NULL ))		

						DELETE bm 
						FROM dbo.zzzbettransm bm WITH (ROWLOCK, UPDLOCK)
							INNER JOIN @tmpTransId t ON t.TransId = bm.TransId AND t.MatchId = bm.MatchId
					END
				END
				ELSE IF @TableName = 'BetParlayResult'
				BEGIN
					SET @matchdate = NULL
					SET @strTransIds = NULL

					SELECT  @matchdate = T.C.value('@wld', 'SMALLDATETIME') 
							,@strTransIds = T.C.value('@strTransId', 'VARCHAR(MAX)') 
					FROM    @TransInfo.nodes('/root/r') AS T(C)

					EXEC dbo.NAP_Admin_Calculate_MP_PreCal_29 
						@matchid = @matchid
						,@matchdate = @matchdate
						,@strXML = @strTransIds
				END
				ELSE IF @TableName = 'TicketVoiding_VoidedTransaction' AND OBJECT_ID('TicketVoiding_VoidedTransaction','U') IS NOT NULL
				BEGIN
					IF @Action = 'U'
					BEGIN
						INSERT INTO @tmpTransId (TransID ,matchid)
						SELECT	T.C.value('./@t', 'bigint') AS transid	
							,T.C.value('./@mid', 'INT') AS matchid
						FROM	@transInfo.nodes('/root/r') AS T(C)	
						OPTION (OPTIMIZE FOR (@transInfo = NULL ))		

						SET @batchNo = @@ROWCOUNT

						UPDATE TOP (@batchNo)  v
							SET matchid = CASE WHEN t.matchid IS NULL THEN v.matchid ELSE t.matchid END
						FROM	@tmptransid t
							INNER JOIN dbo.TicketVoiding_VoidedTransaction v WITH (ROWLOCK, UPDLOCK)
								ON	v.transid = t.transid
					END
				END
			END TRY
			BEGIN CATCH
				SET @errcode = ERROR_NUMBER()
				SET @errmsg = ERROR_MESSAGE()
					
				IF @errcode = 1205 -- deadlock
				BEGIN
					SET @TryCount = @TryCount + 1

					WAITFOR DELAY '00:00:00.100' -- Wait for 100 ms
				END

				IF @errcode = 1205 AND @TryCount < @maxTryCount
					CONTINUE

				RAISERROR (@errmsg, -- Message text.
					16, -- Severity.
					1 -- State.
					);
			END CATCH

			BREAK
		END
	END
END
GO