/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_04] 	
	@TransInfo XML
	,@TableName VARCHAR(128)
	,@Action VARCHAR(1) = 'U'
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
	
	DECLARE @tmpTransId TABLE (transId BIGINT, refno BIGINT
		,matchid INT, winlostdate DATETIME, betdaqid BIGINT
		,modds MONEY, odds SMALLMONEY, oddsid INT, oddsspread MONEY, statuswinlost VARCHAR(1),SettlementTime DATETIME
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT,RepUpdateTime DATETIME2, creator INT
		,hdp1 SMALLMONEY, hdp2 SMALLMONEY, livehomescore SMALLINT, liveawayscore SMALLINT
		,custid INT, bettype SMALLINT, userid INT , CreatedDate DATETIME, MarkType TINYINT
	)
	
	IF @tablename = 'bettrans' 
	BEGIN
		INSERT INTO @tmpTransId (TransID
			,matchid, winlostdate, betdaqid
			,modds, odds, oddsid, oddsspread, statuswinlost,SettlementTime,WinLost,aWinLost
			,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben,RepUpdateTime
			, hdp1 , hdp2 , livehomescore , liveawayscore , creator
		)
		SELECT	T.C.value('./@t', 'bigint') AS transid
				,T.C.value('./@mid', 'INT') AS matchid
				,T.C.value('./@wld', 'SMALLDATETIME') AS winlostdate
				,T.C.value('./@bdaq', 'BIGINT') AS betdaqid
				,T.C.value('./@m', 'MONEY') AS modds
				,T.C.value('./@o', 'SMALLMONEY') AS odds
				,T.C.value('./@oid', 'INT') AS oddsid
				,T.C.value('./@os', 'MONEY') AS oddsspread
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
				,T.C.value('./@s', 'NVARCHAR(10)') AS Status
				,T.C.value('./@sid', 'TINYINT') AS StatusID
				,T.C.value('./@r', 'TINYINT') AS ruben
				,T.C.value('./@rut', 'DATETIME2') AS RepUpdateTime	
				,T.C.value('./@hdp1', 'SMALLMONEY') AS hdp1
				,T.C.value('./@hdp2', 'SMALLMONEY') AS hdp2
				,T.C.value('./@lh', 'SMALLINT') AS livehomescore
				,T.C.value('./@la', 'SMALLINT') AS liveawayscore
				,T.C.value('./@cr', 'INT') AS creator
		FROM	@transInfo.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@transInfo = NULL ))
	
		SET @batchNo = @@ROWCOUNT

		UPDATE TOP (@batchNo) b
			SET
				matchid = CASE WHEN t.matchid IS NULL THEN b.matchid ELSE t.matchid END
				,winlostdate = CASE WHEN t.winlostdate IS NULL THEN b.winlostdate ELSE t.winlostdate END
				,betdaqid = CASE WHEN t.betdaqid IS NULL THEN b.betdaqid ELSE t.betdaqid END
				,modds = CASE WHEN t.modds IS NULL THEN b.modds ELSE t.modds END
				,odds = CASE WHEN t.odds IS NULL THEN b.odds ELSE t.odds END
				,oddsid = CASE WHEN t.oddsid IS NULL THEN b.oddsid ELSE t.oddsid END
				,oddsspread = CASE WHEN t.oddsspread IS NULL THEN b.oddsspread ELSE t.oddsspread END  	
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
				,RepUpdateTime = CASE WHEN t.RepUpdateTime IS NULL THEN b.RepUpdateTime ELSE SYSDATETIME() END
				,hdp1 = CASE WHEN t.hdp1 IS NULL THEN b.hdp1 ELSE t.hdp1 END					
				,hdp2 = CASE WHEN t.hdp2 IS NULL THEN b.hdp2  ELSE t.hdp2 END					
				,livehomescore = CASE WHEN t.livehomescore IS NULL THEN b.livehomescore ELSE t.livehomescore END					
				,liveawayscore = CASE WHEN t.liveawayscore IS NULL THEN b.liveawayscore ELSE t.liveawayscore END									
				,creator = CASE WHEN t.creator IS NULL THEN b.creator ELSE t.creator END
		FROM @tmpTransId t
			INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) 
				ON  t.transid = b.transid 
		OPTION (OPTIMIZE FOR (@batchNo = 1), FORCE ORDER)
	END
	ELSE IF @TableName = 'bettransm'
	BEGIN
		INSERT INTO @tmpTransId (TransID
			,winlostdate, statuswinlost, refno, WinLost
			, Status, StatusID, ruben, hdp1, hdp2, livehomescore, liveawayscore, Creator
		)
		SELECT	T.C.value('./@t', 'bigint') AS transid
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
			SET ruben = CASE WHEN t.ruben IS NULL THEN bm.ruben ELSE t.ruben END								
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
		OPTION (OPTIMIZE FOR (@batchNo = 1), FORCE ORDER)
	END
	ELSE IF @TableName = 'BetParlayDetail'
	BEGIN
		INSERT INTO @tmpTransId (TransID
			,winlostdate, statuswinlost, StatusID
		)
		SELECT	T.C.value('./@t', 'bigint') AS transid
				,CASE 
					WHEN T.C.value('./@wld', 'SMALLDATETIME') = '' THEN NULL 
					ELSE T.C.value('./@wld', 'SMALLDATETIME') 
				END AS winlostdate
				,CASE
					WHEN T.C.value('./@statuswl', 'TINYINT') = '' THEN NULL
					ELSE T.C.value('./@statuswl', 'TINYINT')
				END AS statuswinlost				
				,T.C.value('./@sid', 'TINYINT') AS StatusID									
		FROM	@transInfo.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@transInfo = NULL ))
	
		SET @batchNo = @@ROWCOUNT

		UPDATE TOP (@batchNo) pd 
			SET winlostdate = CASE	
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
		OPTION (OPTIMIZE FOR (@batchNo = 1), FORCE ORDER)
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
END
GO