/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_SummaryTicket19999_Update]
AS
/*	
	Created by: 20250919@July
	Task: [TVS] Manage Void Service - Correct summary ticket 19999 [Redmine: #238091]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20250919@July: Create new SP [Redmine:#238091]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SiteDBGroupID			  SMALLINT
	      , @AffectedList			  VARCHAR(MAX) = NULL
		  ,	@IsSiteDB				  BIT

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
			SET @IsSiteDB = 1

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @BeforeUpd 	TVP_BalanceWalletChange
		  , @AfterUpd 	TVP_BalanceWalletChange
		
	CREATE TABLE #Result_19999 (
			custid INT
		  , winlostdate SMALLDATETIME
		  , stake MONEY
		  , actual_stake MONEY
		  , winlost_dif MONEY
		  , awinlost_dif MONEY
		  , mwinlost_dif MONEY
		  , swinlost_dif MONEY
		  , playercomm_dif MONEY
		  , comm_dif MONEY
		  , acomm_dif MONEY
		  , scomm_dif MONEY
	)

	CREATE TABLE #BeforeTransId14(
		   matchid INT ,transid BIGINT PRIMARY KEY,betdaqid BIGINT ,sitedbgroupid SMALLINT
		  ,bettype SMALLINT ,statusID TINYINT ,Status NVARCHAR(10)
		  ,winlostdate SMALLDATETIME ,SettlementTime DATETIME ,actual_stake MONEY ,stake MONEY, modds SMALLMONEY
		  ,srecommend INT ,mrecommend INT,recommend INT ,custid INT	
		  ,winlost MONEY ,awinLost MONEY ,mwinLost MONEY ,swinLost MONEY
		  ,playercomm MONEY ,comm MONEY ,acomm MONEY ,scomm MONEY, refno BIGINT
		  ,sporttype SMALLINT, oddsid INT, ExtraInfo VARCHAR(1000), BonusID INT, WalletType TINYINT
	)

	CREATE TABLE #AfterTransId14(
		   matchid INT ,transid BIGINT PRIMARY KEY,betdaqid BIGINT ,sitedbgroupid SMALLINT
		  ,bettype SMALLINT ,statusID TINYINT ,Status NVARCHAR(10)
		  ,winlostdate SMALLDATETIME ,SettlementTime DATETIME ,actual_stake MONEY ,stake MONEY, modds SMALLMONEY
		  ,srecommend INT ,mrecommend INT,recommend INT ,custid INT	
		  ,winlost MONEY ,awinLost MONEY ,mwinLost MONEY ,swinLost MONEY
		  ,playercomm MONEY ,comm MONEY ,acomm MONEY ,scomm MONEY, refno BIGINT
		  ,sporttype SMALLINT, oddsid INT, ExtraInfo VARCHAR(1000), BonusID INT, WalletType TINYINT
	)
	
	--capture before for balance trigger
	INSERT INTO #BeforeTransId14( 
			matchid ,transid ,betdaqid ,sitedbgroupid
			,bettype ,statusID ,Status 
			,winlostdate ,SettlementTime ,actual_stake ,stake ,modds 
			,srecommend ,mrecommend ,recommend ,custid	
			,winlost ,awinLost ,mwinLost ,swinLost
			,playercomm ,comm ,acomm ,scomm, refno
			,oddsid, ExtraInfo, BonusID, WalletType
		)
	SELECT b.matchid, c.TransId, c.betdaqid, b.SiteDBGroupID
		,b.bettype, c.statusID, c.status, c.winlostdate, c.SettlementTime, c.actual_stake, c.stake, b.modds
		,b.srecommend, b.mrecommend, b.recommend, b.custid
		,c.winlost, c.awinlost, c.mwinlost, c.swinlost
		,c.playercomm, c.comm, c.acomm, c.scomm, b.refno
		,b.oddsid, b.ExtraInfo, b.BonusID, b.WalletType
	FROM dbo.TVS_BetTicket14 c WITH (NOLOCK)
		INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = c.TransId
	WHERE b.SiteDBGroupID = @SiteDBGroupID
		
	--capture after for balance trigger
	INSERT INTO #AfterTransId14( 
			matchid ,transid ,betdaqid ,sitedbgroupid
			,bettype ,statusID ,Status 
			,winlostdate ,SettlementTime ,actual_stake ,stake ,modds 
			,srecommend ,mrecommend ,recommend ,custid	
			,winlost ,awinLost ,mwinLost ,swinLost
			,playercomm ,comm ,acomm ,scomm, refno
			,oddsid, ExtraInfo, BonusID, WalletType
		)
	SELECT b.matchid, b.TransId, b.betdaqid, b.SiteDBGroupID
		,b.bettype, b.statusID, b.status, b.winlostdate, b.SettlementTime, b.actual_stake, b.stake, b.modds
		,b.srecommend, b.mrecommend, b.recommend, b.custid
		,b.winlost, b.awinlost, b.mwinlost, b.swinlost
		,b.playercomm, b.comm, b.acomm, b.scomm, b.refno
		,b.oddsid, b.ExtraInfo, b.BonusID, b.WalletType
	FROM dbo.TVS_BetTicket14 c WITH (NOLOCK)
		INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = c.TransId
	WHERE b.SiteDBGroupID = @SiteDBGroupID

	INSERT INTO #Result_19999 (custid, winlostdate
								, stake 
								, actual_stake 
								, winlost_dif, awinlost_dif, mwinlost_dif, swinlost_dif
								, playercomm_dif, comm_dif, acomm_dif, scomm_dif)
	SELECT b.CustID
		 , b.winlostdate
		 , SUM(a.stake - b.stake) AS stake
		 , SUM(a.actual_stake - b.actual_stake) AS actual_stake
		 , SUM(a.winlost - b.winlost)  AS winlost_dif
		 , SUM(a.awinlost - b.awinlost)  AS awinlost_dif
		 , SUM(a.mwinlost - b.mwinlost)  AS mwinlost_dif
		 , SUM(a.swinlost - b.swinlost)  AS swinlost_dif
		 , SUM(a.playercomm - b.playercomm)  AS playercomm_dif
		 , SUM(a.comm - b.comm)  AS comm_dif
		 , SUM(a.acomm - b.acomm)  AS acomm_dif
		 , SUM(a.scomm - b.scomm)  AS scomm_dif
	FROM #BeforeTransId14 b
		INNER JOIN #AfterTransId14 a ON b.custid = a.custid AND b.winlostdate = a.winlostdate 
	GROUP BY b.CustID, b.winlostdate

	SET @AffectedList = (SELECT CustID				AS '@c'
							   ,winlostdate			AS '@w'
							   ,stake				AS '@st'
							   ,actual_stake		AS '@ast'
							   ,winlost_dif			AS '@w_dif'
							   ,awinlost_dif		AS '@aw_dif'
							   ,mwinlost_dif		AS '@mw_dif'
							   ,swinlost_dif		AS '@sw_dif'
							   ,playercomm_dif		AS '@pc_dif'
							   ,comm_dif			AS '@c_dif'
							   ,acomm_dif			AS '@ac_dif'
							   ,scomm_dif			AS '@sc_dif'
						FROM #Result_19999
						FOR XML PATH('r'), ROOT( 'root' ))

	--Step 1: Update 19999	
	EXEC dbo.TicketVoiding_Admin_Bet14_19999 
		@AffectedList = @AffectedList
		,@IsSiteDB = @IsSiteDB

	-- UPDATE eventtype = 1
	IF(EXISTS (SELECT 1 FROM #BeforeTransId14 b WHERE NOT EXISTS (SELECT TOP 1 1 FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1) AND b.bettype = bettype)))
	BEGIN
		UPDATE	b
		SET sporttype 	= m.sporttype
		FROM	#BeforeTransId14 b
			INNER JOIN dbo.match14 m WITH(NOLOCK)
				ON	b.matchid = m.matchid
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1) AND b.bettype = bettype)
	END
	
	-- UPDATE eventtype = 2 [Outright ticket]
	IF(EXISTS (SELECT 1 FROM #BeforeTransId14 WHERE bettype = 10))
	BEGIN
		UPDATE b
		SET sporttype	= l.sporttype
		FROM #BeforeTransId14 b
			INNER JOIN dbo.outright14 AS o WITH (NOLOCK) 
				ON	b.matchid = o.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
				ON	o.leagueid = l.leagueid
		WHERE bettype = 10
	END
	
	-- UPDATE eventtype = 3 [VS range bettypes]
	IF(EXISTS (SELECT 1 FROM #BeforeTransId14 WHERE bettype IN (1231,1232,1233,1237,1238,2770,2771,15500,15501)))
	BEGIN
		UPDATE b
		SET sporttype 	= r.sporttype
		FROM #BeforeTransId14 b
			INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) 
				ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo14 r WITH (NOLOCK) 
				ON r.EventID = o.EventID
		WHERE b.bettype IN (1231,1232,1233,1237,1238,2770,2771,15500,15501)
	END
	
	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)/ Saba Coins (productid = 81)/Player Tips(productid = 74)
	BEGIN
		UPDATE d
		SET sporttype = sb.SportType
		   ,matchid = CASE WHEN ProductID IN (74) THEN SUBSTRING(d.ExtraInfo,CHARINDEX('m="', d.ExtraInfo) + 3,CHARINDEX('"', d.ExtraInfo, CHARINDEX('m="', d.ExtraInfo) + 3) -(CHARINDEX('m="', d.ExtraInfo) + 3)) ELSE d.matchid END
		FROM #BeforeTransId14 d
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON d.bettype = sb.BetType
		WHERE sb.ProductID IN (37,81,74)
	END

	UPDATE a
	SET sporttype = b.sporttype
	   ,matchid = b.matchid
	FROM	#AfterTransId14 a
		INNER JOIN #BeforeTransId14 b ON a.transid = b.transid

	--Step 2: Update balance correction
	BEGIN
		--capture balance before
		INSERT INTO @BeforeUpd (
			 matchid
			,custid
			,balanceType
			,BonusID
			,WalletType
			,balance
		)
		SELECT matchid
			 , custid
			 , CASE 
					WHEN (sporttype BETWEEN 1 AND 99 OR sporttype = 154) OR bettype IN (29,10) THEN 1 -- Sports
					WHEN sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
			   END AS balanceType
			 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
			 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			 , SUM(winlost - actual_stake + playercomm) AS balance
		FROM #BeforeTransId14 b
		GROUP BY matchid
			   , CustID
			   , CASE 
					WHEN (sporttype BETWEEN 1 AND 99 OR sporttype = 154) OR bettype IN (29,10) THEN 1 -- Sports
					WHEN sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				 END
			   , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
			   , ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets

		--capture balance after
		INSERT INTO @AfterUpd (
			 matchid
			,custid
			,balanceType
			,BonusID
			,WalletType
			,balance
		)
		SELECT matchid
			 , custid
			 , CASE 
					WHEN (sporttype BETWEEN 1 AND 99 OR sporttype = 154)  OR bettype IN (29,10) THEN 1 -- Sports
					WHEN sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
			   END AS balanceType
			 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
			 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			 , SUM(winlost - actual_stake + playercomm) AS balance
		FROM #AfterTransId14 b
		GROUP BY matchid
			   , CustID
			   , CASE 
					WHEN (sporttype BETWEEN 1 AND 99 OR sporttype = 154) OR bettype IN (29,10) THEN 1 -- Sports
					WHEN sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				 END
			   , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
			   , ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets
	
		---INSERT data into pending balance table   
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			  @BalanceWalletBefore	= @BeforeUpd
			, @BalanceWalletAfter	= @AfterUpd
			, @ActionId				= 0
	END

	--Step 3: Insert routine task
	EXEC dbo.TicketVoiding_Admin_Bet14_RoutineTask_Insert 
		@AffectedList = @AffectedList
		,@IsSiteDB = @IsSiteDB

	--Step 4: Insert Balance Trigger
	BEGIN
		IF @IsSiteDB = 1
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
	END

	--Step 5: Truncate table (TVS_BetTicket14)
	TRUNCATE TABLE TVS_BetTicket14

	DROP TABLE #Result_19999
	DROP TABLE #AfterTransId14
	DROP TABLE #BeforeTransId14
END		
GO


