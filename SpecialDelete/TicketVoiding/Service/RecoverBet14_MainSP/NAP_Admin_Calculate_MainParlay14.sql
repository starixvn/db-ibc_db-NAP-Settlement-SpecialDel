/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MainParlay14] (@transIds VARCHAR(MAX))
AS
/*
	Created by: 20190715@Helen
	Task: Settlement  
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions:
		- 20190715@Helen: Recover/Void tickets in Bet 14 - [Redmine:115377]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240416@Max: [TVS] Recover Ticket - Recover full range of archived tickets [Redmine: #203754]
		- 20250516@July: Recover 14 - Insert changed data into BalanceTrigger table [Redmine: #227625]
		- 20250612@July: Add new column refno [Redmine: #226514]

	Param's Explanation:  
		   
		@transIds = '104730774034,104729373985'
					
*/
BEGIN
	
	SET NOCOUNT ON

	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@TransInfo			VARBINARY(MAX) = NULL
			,@MatchId			INT
			,@IsSiteDB			BIT 
			,@IsInsertTrigger	BIT = 0

    IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
        SET @IsSiteDB = 1
	
	IF (OBJECT_ID('BalanceTrigger','U') IS NOT NULL AND @@SERVERNAME IN ('TESTDB053','SITDB05','SITDB05BK1','DB05','DB05BK1'))
		OR @IsSiteDB = 1
	BEGIN
		SET @IsInsertTrigger = 1
	END

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
			RETURN

	END
	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @xml XML
		   
	DECLARE @tbl_transIDs AS TABLE(transid BIGINT)

	DECLARE @tmpTransInfo TABLE(
			  matchid INT, transid BIGINT, status NVARCHAR(10) , statusID TINYINT, ruben TINYINT, modds SMALLMONEY
			, winlost MONEY, aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			, PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			, statuswinlost TINYINT, creator INT, ExtraInfo VARCHAR(1000)
			, transdate DATETIME, comstatus NVARCHAR(40)
			)
	
	CREATE TABLE #BeforeTransId14(
	   matchid INT ,transid BIGINT PRIMARY KEY,betdaqid BIGINT ,sitedbgroupid SMALLINT
      ,bettype SMALLINT ,statusID TINYINT ,Status NVARCHAR(10)
	  ,winlostdate SMALLDATETIME ,SettlementTime DATETIME ,actual_stake MONEY ,modds SMALLMONEY
	  ,srecommend INT ,mrecommend INT,recommend INT ,custid INT	
	  ,winlost MONEY ,awinLost MONEY ,mwinLost MONEY ,swinLost MONEY
	  ,playercomm MONEY ,comm MONEY ,acomm MONEY ,scomm MONEY, refno BIGINT
	)
			
	CREATE TABLE #AfterTransId14(
	    matchid INT ,transid BIGINT PRIMARY KEY,betdaqid BIGINT ,sitedbgroupid SMALLINT
      ,bettype SMALLINT ,statusID TINYINT ,Status NVARCHAR(10)
	  ,winlostdate SMALLDATETIME ,SettlementTime DATETIME ,actual_stake MONEY ,modds SMALLMONEY
	  ,srecommend INT ,mrecommend INT,recommend INT ,custid INT	
	  ,winlost MONEY ,awinLost MONEY ,mwinLost MONEY ,swinLost MONEY
	  ,playercomm MONEY ,comm MONEY ,acomm MONEY ,scomm MONEY, ruben TINYINT, creator INT, ExtraInfo VARCHAR(1000), refno BIGINT
	)

	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)
	
	SET @XML = N'<root><r>' + REPLACE(@transIds, ',', '</r><r>') + '</r></root>'
	
	INSERT INTO @tbl_transIDs (transid)
	SELECT r.value('.','BIGINT')
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@xml = NULL))
	
	IF @IsInsertTrigger = 1 OR @IsSiteDB = 1
	BEGIN
		--capture before for balance trigger
		INSERT INTO #BeforeTransId14( 
			   matchid ,transid ,betdaqid ,sitedbgroupid
			  ,bettype ,statusID ,Status 
			  ,winlostdate ,SettlementTime ,actual_stake ,modds 
			  ,srecommend ,mrecommend ,recommend ,custid	
			  ,winlost ,awinLost ,mwinLost ,swinLost
			  ,playercomm ,comm ,acomm ,scomm, refno
			)
		SELECT b.matchid, t.TransId, b.betdaqid, b.SiteDBGroupID
			,b.bettype, b.statusID, b.status, b.winlostdate, b.SettlementTime, b.actual_stake, b.modds
			,b.srecommend, b.mrecommend, b.recommend, b.custid
			,b.winlost, b.awinlost, b.mwinlost, b.swinlost
			,b.playercomm, b.comm, b.acomm, b.scomm, b.refno
		FROM @tbl_transIDs t
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId
	END

	-- Reset main to running
	UPDATE	b WITH(ROWLOCK, UPDLOCK)
		SET status = 'running'
			,statusID = 0
			,ruben = 0
			--,modds = 0
			,winlost = 0
			,awinlost = 0
			,mwinlost = 0
			,swinlost = 0
			,playercomm = 0
			,comm = 0
			,acomm = 0
			,scomm = 0		
			,statuswinlost = NULL
			,creator = b.custid
			,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(2,'recover',b.ExtraInfo,NULL, b.bettype)
		OUTPUT deleted.matchid, deleted.TransId, inserted.status, inserted.statusID, inserted.ruben
			, inserted.winlost, inserted.awinlost, inserted.mwinlost, inserted.swinlost
			, inserted.playercomm, inserted.comm, inserted.acomm, inserted.scomm
			, inserted.statuswinlost, inserted.creator, inserted.ExtraInfo
		INTO @tmpTransInfo(matchid, transid, status, statusID, ruben, winlost, aWinLost, mWinLost, sWinLost
							,PlayerComm, Comm, aComm, sComm, statuswinlost, creator, ExtraInfo)
	FROM dbo.bettrans14 b
		INNER JOIN @tbl_transIDs t ON b.transid = t.transid

	IF @IsInsertTrigger = 1 OR @IsSiteDB = 1
	BEGIN
		--capture after for balance trigger
		INSERT INTO #AfterTransId14( 
			   matchid ,transid ,betdaqid ,sitedbgroupid
			  ,bettype ,statusID ,Status 
			  ,winlostdate ,SettlementTime ,actual_stake ,modds 
			  ,srecommend ,mrecommend ,recommend ,custid	
			  ,winlost ,awinLost ,mwinLost ,swinLost
			  ,playercomm ,comm ,acomm ,scomm, ruben, creator, ExtraInfo, refno
			)
		SELECT b.matchid, t.TransId, b.betdaqid, b.SiteDBGroupID
			,b.bettype, b.statusID, b.status, b.winlostdate, b.SettlementTime, b.actual_stake, b.modds
			,b.srecommend, b.mrecommend, b.recommend, b.custid
			,b.winlost, b.awinlost, b.mwinlost, b.swinlost
			,b.playercomm, b.comm, b.acomm, b.scomm, b.ruben, b.creator, b.ExtraInfo, b.refno
		FROM @tbl_transIDs t
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId
	END

	IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
	BEGIN
		INSERT INTO @tmpMatchidInfo (MatchId)
		SELECT DISTINCT MatchId FROM @tmpTransInfo

		WHILE (1=1)
		BEGIN
			UPDATE TOP(1)m
			SET IsFinish = 1, @matchid = MatchId 
			FROM @tmpMatchidInfo m
			WHERE IsFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK;
			SET @TransInfo = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, STATUS AS 's'
					, statusID AS 'sid'
					, ruben AS 'r'
					, winlost AS 'w'
					, awinlost AS 'aw'
					, mwinlost AS 'mw'
					, swinlost AS 'sw'
					, playercomm AS 'pc'
					, comm AS 'c'
					, acomm AS 'ac'
					, scomm AS 'sc'
					, CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl'
					, creator AS 'cr'
					, ExtraInfo AS 'ex'
			FROM	@tmpTransInfo WHERE matchid = @MatchId 
			FOR JSON PATH))

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
			SELECT 'TVS', 'RecoverMainParlay', 'bettrans14', 'U', @MatchId, @TransInfo, 'p'
		END

		DELETE FROM @tmpTransInfo
		DELETE FROM @tmpMatchidInfo
	END	
	
	IF @IsInsertTrigger = 1 OR @IsSiteDB = 1
	BEGIN
		-- Insert statements for trigger here
		INSERT INTO dbo.BalanceTrigger (custid, transid, bettype, actual_stake, winlost, playercomm, ActionDate, 
			ActionID, [Action],
			BalanceChanged,
			MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm, modds, winlostdate, bef_statusid, bef_winlost, refno)
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
			,d.refno
		FROM #AfterTransId14 i 
				INNER JOIN #BeforeTransId14 d ON i.transid = d.transid
		WHERE d.custid <> d.recommend 
			AND d.custid <> d.mrecommend 
			AND d.custid <> d.srecommend		
	END

	DROP TABLE #BeforeTransId14
	DROP TABLE #AfterTransId14
END
GO