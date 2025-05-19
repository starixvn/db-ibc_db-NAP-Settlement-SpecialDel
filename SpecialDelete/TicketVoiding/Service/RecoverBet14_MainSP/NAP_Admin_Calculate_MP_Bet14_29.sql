/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_Bet14_29]
	@strXML	VARCHAR(MAX)
AS
/*
	Created by: 20190715@Helen
	Task: Settlement  
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions:
		- 20190715@Helen: Recover/Void tickets in Bet 14 - [Redmine:115377]
		- 20201126@Louisa: God Of Fortune for Parlay [Redmine:#145774]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20250516@July: Recover 14 - Insert changed data into BalanceTrigger table [Redmine: #227625]

	Param's Explanation:  
		
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #Refno (refno BIGINT  PRIMARY KEY, transid BIGINT)
	DECLARE @minRefno BIGINT	
			
	DECLARE @xml XML
			,@statusId TINYINT
			,@winlost MONEY
			,@winlostdate SMALLDATETIME
			,@currentDate SMALLDATETIME
			,@IsSiteDB			BIT = 0
			,@transInfoJson		NVARCHAR(MAX)
			,@IsInsertTrigger	BIT = 0

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
	SET @IsSiteDB = 1
			
	IF (OBJECT_ID('BalanceTrigger','U') IS NOT NULL AND @@SERVERNAME IN ('TESTDB053','SITDB05','SITDB05BK1','DB05','DB05BK1'))
		OR @IsSiteDB = 1
	BEGIN
		SET @IsInsertTrigger = 1
	END

	SET @currentDate =  CONVERT(VARCHAR(10),GETDATE(),102)

	DECLARE @tmpTransInfo TABLE (transId BIGINT			
		,SettlementTime DATETIME,Status NVARCHAR(10),StatusID TINYINT
		,WinLostDate SMALLDATETIME, betdaqid BIGINT,ruben TINYINT 
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,statuswinlost TINYINT
		,ExtraInfo VARCHAR(1000)
		,bef_winlost MONEY
		,bef_statusid TINYINT
	)
	
	CREATE TABLE #BeforeTransId14(
	   matchid INT ,transid BIGINT PRIMARY KEY,betdaqid BIGINT ,sitedbgroupid SMALLINT
      ,bettype SMALLINT ,statusID TINYINT ,Status NVARCHAR(10)
	  ,winlostdate SMALLDATETIME ,SettlementTime DATETIME ,actual_stake MONEY ,modds SMALLMONEY
	  ,srecommend INT ,mrecommend INT,recommend INT ,custid INT	
	  ,winlost MONEY ,awinLost MONEY ,mwinLost MONEY ,swinLost MONEY
	  ,playercomm MONEY ,comm MONEY ,acomm MONEY ,scomm MONEY
	)
			
	CREATE TABLE #AfterTransId14(
	    matchid INT ,transid BIGINT PRIMARY KEY,betdaqid BIGINT ,sitedbgroupid SMALLINT
      ,bettype SMALLINT ,statusID TINYINT ,Status NVARCHAR(10)
	  ,winlostdate SMALLDATETIME ,SettlementTime DATETIME ,actual_stake MONEY ,modds SMALLMONEY
	  ,srecommend INT ,mrecommend INT,recommend INT ,custid INT	
	  ,winlost MONEY ,awinLost MONEY ,mwinLost MONEY ,swinLost MONEY
	  ,playercomm MONEY ,comm MONEY ,acomm MONEY ,scomm MONEY, ruben TINYINT, creator INT, ExtraInfo VARCHAR(1000)
	)

	SET @xml = CONVERT(XML, N'<root><r rn="' + REPLACE(REPLACE(@strXML, '|', '" t="'), ',', '"/><r rn="') + '"/></root>')
	
	INSERT INTO #Refno (refno, transid)
	SELECT T.C.value('./@rn', 'bigint')
			,T.C.value('./@t', 'bigint')
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	SELECT @minRefno = MIN(refno)
	FROM #Refno
	
	DECLARE @settlementTime DATETIME
	SET @settlementTime = GETDATE();
	
	CREATE TABLE #temp_source (transid BIGINT,winlostdate SMALLDATETIME,totalStake MONEY, winlost MONEY,awinlost MONEY,mwinlost MONEY,swinlost MONEY
								,playercomm MONEY,comm MONEY,acomm MONEY,scomm MONEY,ruben TINYINT, BonusAmount MONEY DEFAULT(0), xmlExtraInfo XML)
	
	INSERT INTO #temp_source (transid,winlostdate, totalStake, winlost, awinlost,mwinlost,swinlost,playercomm, comm, acomm, scomm, ruben, BonusAmount)
	SELECT transid = b.transid
		,winlostdate = MAX(pr.winlostdate)
		,totalStake = SUM(pr.stake)
		,winlost = SUM(pr.winlost) 
		,awinlost = SUM(pr.awinlost) 
		,mwinlost = SUM(pr.mwinlost) 
		,swinlost = SUM(pr.swinlost) 
		,playercomm = SUM(pr.playercomm) 
		,comm = SUM(pr.comm) 
		,acomm = SUM(pr.acomm) 
		,scomm = SUM(pr.scomm) 			
		,ruben = CASE WHEN SUM(CASE pr.statusID WHEN 0 THEN pr.stake ELSE 0 END) > 0 THEN 0 ELSE 1 END -- in case got sub running, then ruben=0, otherwise set ruben=1
		,ISNULL(MAX(pr.stake * (pr.mOdds - 1)/(1 + pr.ExtraValue) * pr.ExtraValue),0)
	FROM #Refno b 
		INNER JOIN dbo.BetParlayResult pr WITH(NOLOCK) ON pr.refno = b.refno
	WHERE pr.RefNo >= @minRefno
	GROUP BY b.refno, b.transid

	UPDATE	s
		SET xmlExtraInfo = b2.xmlExtraInfo								
	FROM	#temp_source s
		CROSS APPLY (SELECT b1.xmlExtraInfo
							,ISNULL(b1.xmlExtraInfo.value('(/p1/@bba)[1]', 'MONEY'),0) AS currentBonusAmount
					 FROM ( SELECT	CAST(ISNULL(b.ExtraInfo,'') AS XML) AS xmlExtraInfo
							FROM	dbo.bettrans14 b WITH(NOLOCK)
							WHERE	b.TransId = s.TransId
									AND	b.oddsspread = 2
						) b1
			)b2
	WHERE	b2.currentBonusAmount <> s.BonusAmount

	IF @@ROWCOUNT > 0 -- has boost
	BEGIN
		UPDATE s
			SET xmlExtraInfo.modify('replace value of (/p1/@bba)[1] with sql:column("BonusAmount")')
		FROM	#temp_source s
		WHERE	xmlExtraInfo.exist('/p1/@bba') = 1 

		UPDATE s 
			SET xmlExtraInfo.modify('insert(attribute bba {sql:column("BonusAmount")}) into (/p1)[1]')
		FROM	#temp_source s
		WHERE	BonusAmount > 0
				AND xmlExtraInfo.exist('/p1/@bba') = 0 		
	END

	IF @IsInsertTrigger = 1 OR @IsSiteDB = 1
	BEGIN
		--capture before for balance trigger
		INSERT INTO #BeforeTransId14( 
			   matchid ,transid ,betdaqid ,sitedbgroupid
			  ,bettype ,statusID ,Status 
			  ,winlostdate ,SettlementTime ,actual_stake ,modds 
			  ,srecommend ,mrecommend ,recommend ,custid	
			  ,winlost ,awinLost ,mwinLost ,swinLost
			  ,playercomm ,comm ,acomm ,scomm
			)
		SELECT b.matchid, t.TransId, b.betdaqid, b.SiteDBGroupID
			,b.bettype, b.statusID, b.status, b.winlostdate, b.SettlementTime, b.actual_stake, b.modds
			,b.srecommend, b.mrecommend, b.recommend, b.custid
			,b.winlost, b.awinlost, b.mwinlost, b.swinlost
			,b.playercomm, b.comm, b.acomm, b.scomm
		FROM #temp_source t
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId
	END

	UPDATE b WITH(ROWLOCK, UPDLOCK)
		SET @statusId = CASE 
						WHEN s.ruben = 0 THEN 0
						WHEN ISNULL(b.oddsspread,0) = 1 THEN	CASE ---GoF
																WHEN s.winlost = b.actual_stake THEN 111
																WHEN s.winlost > b.actual_stake THEN 112
																WHEN s.winlost < b.actual_stake THEN 113 
															END
					ELSE	CASE
							WHEN s.winlost = s.totalStake THEN 111 -- winlost = stake, member DRAW
							WHEN s.winlost > s.totalStake THEN 112 -- winlost > stake, member WIN
							WHEN s.winlost < s.totalStake THEN 113 -- winlost < stake, member LOSE
							ELSE b.statusID -- uncontrollale situation, hope it's not happen in real life
							END
					END
		,@winlost = s.winlost * s.ruben
		,SettlementTime = CASE WHEN @statusId <> 0 AND (b.winlost <> @winlost OR statusID <> @statusId) THEN @settlementTime ELSE SettlementTime END
		,statusID = @statusId
		,[status] = CASE 
						WHEN @statusId = 0 THEN 'running' 
						WHEN @statusId = 111 THEN 'DRAW' -- winlost = stake, member DRAW
						WHEN @statusId = 112 THEN 'WON' -- winlost > stake, member WIN
						WHEN @statusId = 113 THEN 'LOSE' -- winlost < stake, member LOSE
						ELSE b.[status] -- uncontrollale situation, hope it's not happen in real life
					END
		--,actual_stake = s.totalStake 
		,betdaqid = s.totalStake							
		,ruben = s.ruben
		,winlost =   @winlost
		,awinlost = s.awinlost * s.ruben
		,mwinlost = s.mwinlost * s.ruben
		,swinlost = s.swinlost * s.ruben
		,playercomm = s.playercomm * s.ruben
		,comm = s.comm * s.ruben
		,acomm = s.acomm * s.ruben
		,scomm = s.scomm * s.ruben
		,statuswinlost = CASE 
							WHEN @statusId = 112 THEN 2							
							WHEN @statusId = 111 THEN 0 							
							WHEN @statusId = 113 THEN 4								
							WHEN @statusId = 0 THEN NULL
						END 
		,ExtraInfo = CASE WHEN s.xmlExtraInfo IS NOT NULL AND CAST(s.xmlExtraInfo AS VARCHAR(1000)) <> b.ExtraInfo THEN CAST(s.xmlExtraInfo AS VARCHAR(1000))  ELSE b.ExtraInfo END

		OUTPUT inserted.transid
			,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
			,inserted.Status,inserted.StatusID,inserted.winlostdate,inserted.betdaqid,inserted.ruben
			,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
			,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
			,Inserted.Statuswinlost
			,inserted.ExtraInfo
			,deleted.winlost
			,deleted.statusid	
		INTO @tmpTransInfo (transId
			,SettlementTime
			,Status, StatusID, WinLostDate, betdaqid, ruben
			,WinLost,aWinLost,mWinLost,sWinLost
			,PlayerComm,Comm,aComm,sComm
			,statuswinlost
			,ExtraInfo
			,bef_winlost
			,bef_statusid
		)
	FROM dbo.bettrans14 b
		INNER JOIN #temp_source s ON b.transid = s.transid

	IF @IsInsertTrigger = 1 OR @IsSiteDB = 1
	BEGIN
		--capture after for balance trigger
		INSERT INTO #AfterTransId14( 
			   matchid ,transid ,betdaqid ,sitedbgroupid
			  ,bettype ,statusID ,Status 
			  ,winlostdate ,SettlementTime ,actual_stake ,modds 
			  ,srecommend ,mrecommend ,recommend ,custid	
			  ,winlost ,awinLost ,mwinLost ,swinLost
			  ,playercomm ,comm ,acomm ,scomm, ruben, creator, ExtraInfo
			)
		SELECT b.matchid, t.TransId, b.betdaqid, b.SiteDBGroupID
			,b.bettype, b.statusID, b.status, b.winlostdate, b.SettlementTime, b.actual_stake, b.modds
			,b.srecommend, b.mrecommend, b.recommend, b.custid
			,b.winlost, b.awinlost, b.mwinlost, b.swinlost
			,b.playercomm, b.comm, b.acomm, b.scomm, b.ruben, b.creator, b.ExtraInfo
		FROM #temp_source t
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId
	END

	IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)	
	BEGIN
		SET @transInfoJson = (
			SELECT	transId AS 't'			
					,SettlementTime AS 'st' 
					,Status AS 's' 
					,StatusID AS 'sid'
					,WinLostDate AS 'wld'
					,betdaqid AS 'bdaq'
					,ruben AS 'r'
					,WinLost AS 'w' 
					,aWinLost AS 'aw' 
					,mWinLost AS 'mw' 
					,sWinLost AS 'sw' 
					,PlayerComm AS 'pc' 
					,Comm AS 'c' 
					,aComm AS 'ac' 
					,sComm AS 'sc' 
					,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl' 
					,bef_winlost AS 'bef_w' 
					,bef_statusid AS 'bef_sid' 
					,ExtraInfo AS 'ex'
			FROM	@tmpTransInfo
			FOR JSON AUTO
		)

		IF @transinfoJson IS NOT NULL
			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns 
				@SystemName = 'Settlement' 
				,@FunctionName = 'CalculateMainParlay'
				,@TableName = 'bettrans14'
				,@MatchId = 29
				,@TransInfoJson = @transinfoJson
				,@SettlementAction = 'CAL'
				,@TicketType = 'p'
		
	END

	IF @IsInsertTrigger = 1 OR @IsSiteDB = 1
	BEGIN
		-- Insert statements for trigger here
		INSERT INTO dbo.BalanceTrigger (custid, transid, bettype, actual_stake, winlost, playercomm, ActionDate, 
			ActionID, [Action],
			BalanceChanged,
			MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm, modds, winlostdate, bef_statusid, bef_winlost)
		SELECT
			-- if inserted.custid = 0, this should be VOID + Hidden
			-- if deleted.custid = 0, this may be Bet Recover
			case when i.custid = 0 then d.custid else i.custid end,
			i.transid, i.bettype, i.actual_stake, isnull(i.winlost,0) as winlost, isnull(i.playercomm,0) as playercomm, CURRENT_TIMESTAMP, 

			CASE 
				WHEN (
					i.actual_stake <> d.actual_stake 
					OR isnull(i.winlost,0) <> isnull(d.winlost,0) 
					OR isnull(i.playercomm,0) <> isnull(d.playercomm,0)
					OR isnull(i.statusid,0) <> isnull(d.statusid,0)
					OR i.custid <> d.custid
				) THEN
					CASE
					WHEN isnull(i.statusid,0) = 102 THEN 050 -- Void Bet

					WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 1 THEN CASE isnull(i.statusid,0) WHEN 101 THEN 020 WHEN 0 THEN 021 ELSE 0 END -- waiting -> Reject : running : something else
					WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 0 AND isnull(i.statusid,0) > 0  -- Settled : running -> Won/Lose/Draw/Refund
						THEN CASE 
								WHEN ISNULL(i.betdaqid,0) = -2 THEN 029 -- cashout ticket
								ELSE 030 -- settle ticket
							END
					WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 102 AND isnull(i.statusid,0) = 0 THEN 055 -- unvoid/recover : void -> running
					WHEN i.bettype < 19001 AND isnull(d.statusid,0) > 0 
						THEN CASE isnull(i.statusid,0) 
								WHEN 0 THEN CASE WHEN ISNULL(i.betdaqid,0) = -1 AND ISNULL(d.betdaqid,0) = -2 THEN 034 ELSE 032 END
								ELSE 031 
							END -- resettle or unsettle
					WHEN i.bettype > 20000 AND i.custid = 0 THEN 130 -- cancel transfer (custid set to zero)
					WHEN i.bettype > 20000 THEN 120 -- update transfer

					--WHEN i.bettype < 19001 AND d.custid = 0 AND i.custid > 0 THEN 055 -- recover bet
					ELSE 0 END
				ELSE 001
			END,
		
			--CASE WHEN i.custid =0 THEN 'Delete ' ELSE 'Update ' END
			--	+ CASE WHEN i.bettype < 19001 then 'Bet' ELSE 'Transfer' END + 
			--CASE WHEN i.custid <> 0 THEN ', from '+ d.[status] + ' to ' + i.[status] ELSE '' END
			--[Action]--vvv
			CASE 
				WHEN ( i.winlostdate <> d.winlostdate AND i.bettype NOT IN (29, 10)	)
					OR (i.winlostdate > d.winlostdate AND i.bettype = 10 )
					OR (i.winlostdate > d.winlostdate AND i.bettype = 29 AND d.statusID NOT IN (0,1) )
					THEN 'Move WLD from ' 
							+ CASE 
								WHEN ISNULL(d.winlostdate,'') = '' THEN REPLICATE(' ', 10) 
								ELSE CONVERT(VARCHAR,d.winlostdate, 23) 
							END
							+ ' to ' 
							+ CASE 
								WHEN ISNULL(i.winlostdate,'') = '' THEN REPLICATE(' ', 10)
								ELSE CONVERT(VARCHAR,i.winlostdate, 23) 
							END						
				ELSE '' 
			END + 
			ISNULL(CASE
					WHEN i.bettype < 19001 THEN 'Bet'
					WHEN i.bettype > 20000 THEN 'Transfer'
					ELSE isnull(d.[status],'running')
				END +
				CASE
					WHEN i.custid = 0 THEN ' cancelled, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
					WHEN i.bettype > 20000 THEN ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
					WHEN isnull(d.statusid,0) = 1 THEN
						CASE isnull(i.statusid,0)
						WHEN 0 THEN ' accepted'
						WHEN 101 THEN ' rejected'
						ELSE ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
						END
					WHEN isnull(d.statusid,0) = 0 THEN
						CASE 
							WHEN isnull(i.statusid,0) = 102 THEN ' voided'
							WHEN (isnull(i.statusid,0) BETWEEN 111 AND 113) OR isnull(i.statusid,0) = 103 
								THEN CASE 
										WHEN ISNULL(i.betdaqid,0) = -2 THEN ' Cash Out, ' + isnull(d.status,' running') + ' to '  + isnull(i.status,' running')
										ELSE  ' settled, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
									END
							ELSE ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
						END
					WHEN isnull(d.statusid,0) > 0 AND isnull(d.betdaqid,0) = -2 AND isnull(i.statusid,0) = 0 
						THEN ' Cancel Cash Out, ' + isnull(d.status,'running') + ' to ' + isnull(i.status,'running')
					ELSE ' Updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
				END,'')
			--[Action]--^^^	
 			, (isnull(i.winlost,0) - ISNULL(i.actual_stake, 0) + ISNULL(i.playercomm,0))
				- (ISNULL(d.winlost,0) - ISNULL(d.actual_stake, 0) + ISNULL(d.playercomm,0))
			,i.matchid
			,isnull(i.statusID,0)
			,CASE 
				WHEN (isnull(i.statusID,0) BETWEEN 111 AND 113 OR isnull(i.statusID,0) = 103) 
					THEN CASE 
							WHEN d.SettlementTime IS NULL THEN 1 -- first settled
							WHEN i.SettlementTime <> d.SettlementTime 
								THEN CASE
										WHEN isnull(d.statusID,0) = 0 THEN 2 -- change from running to settle 
										ELSE 3 
									END -- re-settled: change from settle to settle
							WHEN isnull(d.statusID,0) BETWEEN 111 AND 113 THEN 4 -- settle to settle, no change winlost
							ELSE 0 
						END
				ELSE 0
			END -- SettlementType
			,isnull(i.swinlost,0) as swinlost
			,isnull(i.mwinlost,0) as mwinlost
			,isnull(i.awinlost,0) as awinlost
			,isnull(i.scomm,0) as scomm
			,isnull(i.acomm,0) as acomm
			,isnull(i.comm,0) as comm
			,i.modds
			,i.winlostdate
			,d.statusID AS bef_statusid
			,isnull(d.winlost,0) AS bef_winlost
		FROM #AfterTransId14 i 
				INNER JOIN #BeforeTransId14 d ON i.transid = d.transid
		WHERE d.custid <> d.recommend 
			AND d.custid <> d.mrecommend 
			AND d.custid <> d.srecommend		
	END

	DROP TABLE #temp_source
	DROP TABLE #Refno
	DROP TABLE #BeforeTransId14
	DROP TABLE #AfterTransId14
END
GO
