/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_SummaryTicket19999_Update]
(
	  @TransIds          VARCHAR(MAX) = NULL	
)
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

	DECLARE @tmpTransIdList AS TABLE (TransId BIGINT)
	
	DECLARE @BeforeUpd 	TVP_BalanceWalletChange
		  , @AfterUpd 	TVP_BalanceWalletChange
		
	CREATE TABLE #Result_19999 (custid INT
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
		  ,playercomm MONEY ,comm MONEY ,acomm MONEY ,scomm MONEY, refno BIGINT
	)

	INSERT INTO @tmpTransIdList (TransId)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	;WITH CTE_SumBettrans14 AS (
		SELECT b14.CustID, b14.winlostdate
			 , SUM(stake) AS stake
			 , SUM(actual_stake) AS actual_stake
			 , SUM(winlost) AS winlost
			 , SUM(awinlost) AS awinlost
			 , SUM(mwinlost) AS mwinlost
			 , SUM(swinlost) AS swinlost
			 , SUM(playercomm) AS playercomm
			 , SUM(comm) AS comm
			 , SUM(acomm) AS acomm
			 , SUM(scomm) AS scomm
		FROM dbo.bettrans14 b14 WITH (NOLOCK) 
		WHERE b14.SiteDBGroupID = @SiteDBGroupID
			AND	EXISTS ( SELECT TOP 1 1 FROM @tmpTransIdList t WHERE t.TransId = b14.transid)
		GROUP BY b14.CustID, b14.winlostdate
	)
	INSERT INTO #Result_19999 (custid, winlostdate
								, stake 
								, actual_stake 
								, winlost_dif, awinlost_dif, mwinlost_dif, swinlost_dif
								, playercomm_dif, comm_dif, acomm_dif, scomm_dif )
	SELECT s.CustID
		,s.winlostdate
		, s.stake - b.Stake AS stake
		, s.actual_stake - b.actual_stake AS actual_stake
		, s.winlost - b.winlost  AS winlost_dif
		, s.awinlost - b.awinlost  AS awinlost_dif
		, s.mwinlost - b.mwinlost  AS mwinlost_dif
		, s.swinlost - b.swinlost  AS swinlost_dif
		, s.playercomm - b.playercomm  AS playercomm_dif
		, s.comm - b.comm  AS comm_dif
		, s.acomm - b.acomm  AS acomm_dif
		, s.scomm - b.scomm  AS scomm_dif
	FROM CTE_SumBettrans14 s
		INNER JOIN dbo.Transfer b WITH (ROWLOCK) ON b.custid = s.custid AND b.winlostdate = s.winlostdate 

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
		,@IsSiteDB = 1

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
					WHEN (tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154)  OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN tmp.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
			   END AS balanceType
			 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
			 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			 , SUM(winlost - actual_stake + playercomm) AS balance
		FROM
		(
			-- normal ticket
			SELECT c.custid
				 , b.BonusID
				 , b.WalletType
				 , c.winlost, c.actual_stake , c.playercomm
				 , b.bettype, b.matchid, c.sporttype
			FROM dbo.TVS_BetTicket14 c WITH (NOLOCK)
				INNER JOIN dbo.bettrans14 b ON c.transid = b.transid
			WHERE EXISTS ( SELECT TOP 1 1 FROM @tmpTransIdList t WHERE t.TransId = c.transid)
		) tmp
		GROUP BY matchid
			   , CustID
			   , CASE 
					WHEN (tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN tmp.sporttype = 162 THEN 3 -- Casino
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
					WHEN (tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN tmp.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
			   END AS balanceType
			 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
			 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			 , SUM(winlost - actual_stake + playercomm) balance
		FROM
		(
			-- normal ticket
			SELECT b.custid
				 , b.BonusID
				 , b.WalletType
				 , b.winlost, b.actual_stake ,b.playercomm, b.bettype, b.matchid, b.sporttype
			FROM dbo.TVS_BetTicket14 c WITH (NOLOCK)
				INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = c.TransId
			WHERE EXISTS ( SELECT TOP 1 1 FROM @tmpTransIdList t WHERE t.TransId = c.transid)
		) tmp
		GROUP BY matchid
			   , CustID
			   , CASE 
					WHEN (tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN tmp.sporttype = 162 THEN 3 -- Casino
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
		,@IsSiteDB = 1

	--Step 4: Insert Balance Trigger
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
		SELECT b.matchid, c.TransId, b.betdaqid, @SiteDBGroupID
			,b.bettype, c.statusID, c.status, c.winlostdate, c.SettlementTime, c.actual_stake, b.modds
			,b.srecommend, b.mrecommend, b.recommend, b.custid
			,c.winlost, c.awinlost, c.mwinlost, c.swinlost
			,c.playercomm, c.comm, c.acomm, c.scomm, b.refno
		FROM dbo.TVS_BetTicket14 c WITH (NOLOCK)
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = c.TransId
		WHERE EXISTS ( SELECT TOP 1 1 FROM @tmpTransIdList t WHERE t.TransId = c.transid)
		
		--capture after for balance trigger
		INSERT INTO #AfterTransId14( 
			   matchid ,transid ,betdaqid ,sitedbgroupid
			  ,bettype ,statusID ,Status 
			  ,winlostdate ,SettlementTime ,actual_stake ,modds 
			  ,srecommend ,mrecommend ,recommend ,custid	
			  ,winlost ,awinLost ,mwinLost ,swinLost
			  ,playercomm ,comm ,acomm ,scomm, refno
			)
		SELECT b.matchid, b.TransId, b.betdaqid, @SiteDBGroupID
			,b.bettype, b.statusID, b.status, b.winlostdate, b.SettlementTime, b.actual_stake, b.modds
			,b.srecommend, b.mrecommend, b.recommend, b.custid
			,b.winlost, b.awinlost, b.mwinlost, b.swinlost
			,b.playercomm, b.comm, b.acomm, b.scomm, b.refno
		FROM dbo.TVS_BetTicket14 c WITH (NOLOCK)
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = c.TransId
		WHERE EXISTS ( SELECT TOP 1 1 FROM @tmpTransIdList t WHERE t.TransId = c.transid)

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
		DROP TABLE #AfterTransId14
		DROP TABLE #BeforeTransId14
	END

	--Step 5: Delete list ticket input into table (TVS_BetTicket14)
	DELETE FROM TVS_BetTicket14
	WHERE EXISTS ( SELECT TOP 1 1 FROM @tmpTransIdList t WHERE t.TransId = transid)

	DROP TABLE #Result_19999
END		
GO


