/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_04] 	
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

	DECLARE @tmpTransId TABLE (transId BIGINT, refno BIGINT
		,matchid INT, winlostdate DATETIME, betdaqid VARCHAR(50)
		,modds MONEY, odds SMALLMONEY, oddsid INT, oddsspread VARCHAR(20), statuswinlost VARCHAR(1),SettlementTime DATETIME
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT,FcUpdateTime DATETIME2, creator INT
		,hdp1 SMALLMONEY, hdp2 SMALLMONEY, livehomescore SMALLINT, liveawayscore SMALLINT
		,custid INT, bettype SMALLINT, userid INT , CreatedDate DATETIME, MarkType TINYINT, betid VARCHAR(50), ExtraInfo VARCHAR(1000)
		
		,transdate	 DATETIME ,apositiontaking SMALLMONEY ,mpositiontaking SMALLMONEY ,tpositiontaking SMALLMONEY 
		,spositiontaking SMALLMONEY,playerdiscount DECIMAL ,discount	DECIMAL	,adiscount	DECIMAL	,liveindicator	BIT	,betteam NVARCHAR(20) 
		,comstatus NVARCHAR(40)	,betfrom	NVARCHAR(3)	,betcheck	NVARCHAR(100)	,checktime	DATETIME	
		,actualrate	FLOAT,recommend	INT	,mrecommend	INT	,srecommend	INT, stake MONEY,actual_stake MONEY	
		,currency	TINYINT	,[ip] VARCHAR(45)	,transdesc NVARCHAR(2000) ,sdiscount DECIMAL		
		,Username	NVARCHAR(100),CurrencyName	NVARCHAR(100),virtualrate	FLOAT
		,oddstype	VARCHAR(3)	,currency2	VARCHAR(3)	,balance VARCHAR(20),SecAcceptFlag VARCHAR(1),transid2	VARCHAR(50)	
		,RecommDate	DATETIME ,SiteDBGroupID	SMALLINT
	)

	SET @RunOnServer = ISNULL(@RunOnServer,@@SERVERNAME)

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
		SET @sMessage = 'EXEC dbo.ExecRep_NAP_Admin_04 @matchid = ' + CONVERT(NVARCHAR(50), ISNULL(@matchid,0)) 
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
		IF @tablename = 'bettrans'
		BEGIN
			INSERT INTO @tmpTransId (TransID
				,matchid, winlostdate, betdaqid
				,modds, odds, oddsid, oddsspread, statuswinlost,SettlementTime,WinLost,aWinLost
				,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben,FcUpdateTime
				, hdp1 , hdp2 , livehomescore , liveawayscore , creator, betid, ExtraInfo
			
				,transdate,apositiontaking ,mpositiontaking ,tpositiontaking ,spositiontaking 
				,playerdiscount,discount,adiscount	,liveindicator,betteam,comstatus,betfrom,betcheck,checktime		 
				,actualrate	,recommend,mrecommend,srecommend, stake, actual_stake,currency,ip,transdesc		 
				,sdiscount,Username,CurrencyName,virtualrate,oddstype,currency2	,balance		 
				,SecAcceptFlag,transid2	,RecommDate	,SiteDBGroupID	 
			)
			SELECT	T.C.value('./@t', 'bigint') AS transid
					,T.C.value('./@mid', 'INT') AS matchid
					,T.C.value('./@wld', 'SMALLDATETIME') AS winlostdate
					,T.C.value('./@bdaq', 'VARCHAR(50)') AS betdaqid
					,T.C.value('./@m', 'MONEY') AS modds
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
					,T.C.value('./@td', 'DATETIME') AS transdate
					,T.C.value('./@apos', 'SMALLMONEY') AS apositiontaking
					,T.C.value('./@mpos', 'SMALLMONEY') AS mpositiontaking
					,T.C.value('./@tpos', 'SMALLMONEY') AS tpositiontaking
					,T.C.value('./@spos', 'SMALLMONEY') AS spositiontaking
					,T.C.value('./@pd', 'decimal') AS playerdiscount		
					,T.C.value('./@d' , 'DECIMAL')	AS discount	 
					,T.C.value('./@ad', 'DECIMAL')	AS adiscount	 
					,T.C.value('./@li', 'BIT')		AS liveindicator 
					,T.C.value('./@bteam', 'NVARCHAR(20)')	AS betteam	 
					,T.C.value('./@cst', 'NVARCHAR(40)')	AS comstatus	 
					,T.C.value('./@bf','NVARCHAR(3)')		AS betfrom	 
					,T.C.value('./@bc','NVARCHAR(100)')		AS betcheck	 
					,T.C.value('./@ct','DATETIME')	AS checktime	 
					,T.C.value('./@ar', 'FLOAT')	AS actualrate	 
					,T.C.value('./@rc' , 'INT')		AS recommend	 
					,T.C.value('./@mrc', 'INT')		AS mrecommend	 
					,T.C.value('./@src', 'INT')		AS srecommend	
					,T.C.value('./@stake', 'MONEY') AS stake 
					,T.C.value('./@astake', 'MONEY') AS actual_stake 
					,T.C.value('./@cur','TINYINT')		AS currency	 
					,T.C.value('./@ip', 'VARCHAR(45)')	AS [ip]			 
					,T.C.value('./@tdesc', 'NVARCHAR(2000)') AS transdesc 
					,T.C.value('./@sdis' , 'DECIMAL'	) AS sdiscount	 
					,T.C.value('./@uname', 'NVARCHAR(100)') AS Username	 
					,T.C.value('./@curname', 'NVARCHAR(100)') AS CurrencyName 
					,T.C.value('./@v', 'FLOAT') AS virtualrate 
					,T.C.value('./@otype', 'VARCHAR(3)')	AS oddstype	 
					,T.C.value('./@cur2', 'VARCHAR(3)')	AS currency2	 
					,T.C.value('./@b', 'VARCHAR(20)')		AS balance	 
					,T.C.value('./@sec', 'VARCHAR(1)')		AS SecAcceptFlag	 
					,T.C.value('./@t2', 'VARCHAR(50)')	AS transid2		 
					,T.C.value('./@rcd', 'DATETIME') AS RecommDate
					,T.C.value('./@sgid', 'SMALLINT') AS SiteDBGroupID
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
						,modds = CASE WHEN t.modds IS NULL THEN b.modds ELSE t.modds END
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
				FROM @tmpTransId t
					INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) 
						ON  t.transid = b.transid 
				OPTION (OPTIMIZE FOR (@batchNo = 1), FORCE ORDER)
			END

			ELSE IF @Action = 'I'
			BEGIN
				INSERT INTO dbo.bettrans (
					TransId
					,custid
					,transdate
					,oddsid
					,hdp1
					,hdp2
					,odds
					,stake
					,[STATUS]
					,winlost
					,awinlost
					,mwinlost
					,playercomm
					,comm
					,acomm
					,apositiontaking
					,mpositiontaking
					,tpositiontaking
					,playerdiscount
					,discount
					,adiscount
					,livehomescore
					,liveawayscore
					,liveindicator
					,betteam
					,creator
					,refno
					,comstatus
					,winlostdate
					,betfrom
					,betcheck
					,checktime
					,oddsspread
					,actualrate
					,matchid
					,recommend
					,mrecommend
					,ruben
					,betid
					,statuswinlost
					,modds
					,bettype
					,betdaqid						
					,actual_stake
					,currency
					,[ip]
					,transdesc
					,sdiscount
					,scomm
					,spositiontaking
					,swinlost
					,srecommend
					,Username
					,CurrencyName
					,virtualrate
					,oddstype
					,statusID
					,currency2
					,balance
					,SecAcceptFlag
					,transid2
					,RecommDate
					,SiteDBGroupID
					)
				SELECT 
					transid
					,custid
					,transdate
					,oddsid
					,hdp1
					,hdp2
					,odds
					,stake
					,[STATUS]
					,winlost
					,awinlost
					,mwinlost
					,playercomm
					,comm
					,acomm
					,apositiontaking
					,mpositiontaking
					,tpositiontaking
					,playerdiscount
					,discount
					,adiscount
					,livehomescore
					,liveawayscore
					,liveindicator
					,betteam
					,creator
					,refno
					,comstatus
					,winlostdate
					,betfrom
					,betcheck
					,CASE checktime WHEN '' THEN NULL 
						ELSE checktime
						END
					,CASE oddsspread WHEN '' THEN NULL
						 ELSE CAST(oddsspread AS MONEY)
						 END
					,actualrate
					,matchid
					,recommend
					,mrecommend
					,ruben
					,CASE betid WHEN '' THEN NULL
						ELSE CAST(betid AS BIGINT)
						END
					,CASE statuswinlost WHEN '' THEN NULL
						ELSE CAST(statuswinlost AS TINYINT)
						END
					,modds
					,bettype
					,CASE betdaqid	WHEN '' THEN NULL
						ELSE CAST(betdaqid AS BIGINT)
						END
					,actual_stake
					,currency
					,ip
					,transdesc
					,sdiscount
					,scomm
					,spositiontaking
					,swinlost
					,srecommend
					,Username
					,CurrencyName
					,virtualrate
					,CASE oddstype WHEN '' THEN NULL
						ELSE CAST(oddstype AS TINYINT)
						END
					,statusID
					,CASE currency2 WHEN '' THEN NULL
						ELSE CAST(currency2 AS TINYINT)
						END
					,CASE balance  WHEN '' THEN NULL
						ELSE CAST(balance AS MONEY)
						END
					,CASE SecAcceptFlag  WHEN '' THEN NULL
						ELSE CAST(SecAcceptFlag AS BIT)
						END
					,CASE transid2  WHEN '' THEN NULL
						ELSE CAST(transid2 AS BIGINT)
						END
					,CASE RecommDate  WHEN '' THEN NULL
						ELSE RecommDate
						END
					,SiteDBGroupID
				FROM @tmpTransId t

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
				SELECT TransID ,matchid, custid, bettype, userid, CreatedDate, MarkType
				FROM @tmpTransId
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
		ELSE IF @TableName = 'zzzbettrans'
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
				INSERT INTO @tmpTransId (TransID ,matchid)
				SELECT	T.C.value('./@t', 'bigint') AS transid
					   ,T.C.value('./@mid', 'INT') AS matchid
				FROM	@transInfo.nodes('/root/r') AS T(C)
				OPTION (OPTIMIZE FOR (@transInfo = NULL ))

				DELETE m 
				FROM dbo.zzzbettrans m WITH (ROWLOCK, UPDLOCK)
					INNER JOIN @tmpTransId t ON t.TransId = m.TransId AND t.MatchId = m.MatchId
			END
		END
		ELSE IF @TableName = 'zzzbettransm'
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
			SELECT  @matchdate = T.C.value('@wld', 'SMALLDATETIME') 
					,@strTransIds = T.C.value('@strTransId', 'VARCHAR(MAX)') 
			FROM    @TransInfo.nodes('/root/r') AS T(C)

			EXEC dbo.NAP_Admin_Calculate_MP_PreCal_29 
				@matchid = @matchid
				,@matchdate = @matchdate
				,@strXML = @strTransIds
		END
		ELSE IF @TableName = 'TicketVoiding_VoidedTransaction'
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
	END
END
GO