/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Test Licensee - SIT - ON SITEDB01
    DB: DBCTG-SiteDB2tmp

	 Revisions:
		- 20220926@Victoria: Clean Data on SiteDB01 of Licensee 'Bobo88' on SIT of the following tables: [Redmineid:#178145] 
							 Bet tickets tables:
								1.  bodb02.dbo.bettrans				2.  bodb02.dbo.bettrans14
								3.  bodb02.dbo.bettransG			4.  bodb02.dbo.bettransG14
								5.  bodb02.dbo.BettransInfo			6.  bodb02.dbo.BettransInfo14
								7.  bodb02.dbo.bettransLC			8.  bodb02.dbo.bettransLC14
								9.  bodb02.dbo.bettransm			10. bodb02.dbo.bettransm14
								11. bodb02.dbo.bettransRnG			12. bodb02.dbo.bettransRnG14
								13. bodb02.dbo.translog				14. bodb02.dbo.translog14
								15. bodb02.dbo.zzzbettrans			16. bodb02.dbo.zzzbettransm
								17. bodb02.dbo.Transfer				18. bodb02.dbo.Transfer_Coll		19. bodb02.dbo.TransferInfo
								20. bodb02.dbo.BetParlayDetail		21. bodb02.dbo.BetParlayResult
							 Tables balance:
								1.  bodb02.dbo.BalCreditCasino
								2.  bodb02.dbo.BalCreditOthers
								3.  bodb02.dbo.BalCreditSports
								4.  bodb02.dbo.BalCreditTransfer
								5.  bodb02.dbo.BalDebitCasino
								6.  bodb02.dbo.BalDebitOthers
								7.  bodb02.dbo.BalDebitSports
								8.  bodb02.dbo.BalDebitTransfer
								9.  bodb02.dbo.BalNetPosition
								10. bodb02.dbo.balanceTable
								11. bodb02.dbo.balanceTable_tmp
								12. bodb02.dbo.BalanceTable_tmp_cal
							 Other tables:
								1.  bodb02.dbo.Bonus_sum_winloss
								2.  bodb02.dbo.BonusAdjustmentTransfer
								3.  bodb02.dbo.BonusTrans
								4.  bodb02.dbo.BonusWalletCredit
								5.  bodb02.dbo.BonusWalletDebit
								6.  bodb02.dbo.BonusWalletPending
								7.  bodb02.dbo.CashOutSelling
								8.  bodb02.dbo.CustLimitBet_LIC
								9.  bodb02.dbo.CustLimitBetHistory_LIC
								10. bodb02.dbo.Task_bettrans14_IP2Country
								11. bodb02.dbo.Task_bettransLC14_IP2Country
								12. bodb02.dbo.Task_bettransRNG14_IP2Country
							 TW Tables list:
								1.  bodb02.dbo.BalancePendingCreditGame
								2.  bodb02.dbo.BalancePendingDebitGame
								3.  bodb02.dbo.BalCreditCasinoPending
								4.  bodb02.dbo.BalCreditOthersPending
								5.  bodb02.dbo.BalCreditSportsPending
								6.  bodb02.dbo.BalDebitCasinoPending
								7.  bodb02.dbo.BalDebitOthersPending
								8.  bodb02.dbo.BalDebitSportsPending
								9.  bodb02.dbo.Intg_GameRoundBetStake
								10. bodb02.dbo.LastBetTime
								11. bodb02.dbo.LastBetTime_Agent
								12. bodb02.dbo.MarkedTransaction
								13. bodb02.dbo.NetPositionCalculationLog
								14. bodb02.dbo.NetPositionTrans
								15. bodb02.dbo.Task_Cust_CheckBalance_Exception
								16. bodb02.dbo.Task_Cust_BalanceProblem1
								
*/

	CREATE TABLE #tmp_cust
	(
		custid INT PRIMARY KEY
	)

	CREATE TABLE #tmp_refno
	(
		refno BIGINT PRIMARY KEY
	)

	------------------------------------------------
	INSERT INTO #tmp_cust (custid)
	SELECT DISTINCT custid
	FROM CustDB.dbo.Customer WITH (NOLOCK)
	WHERE site IN	('Bobo88')
	------------------------------------------------
	/*****************Tables need to join with bettransXXX tables************************/
	--#tmp_refno
	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT b.refno
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid
	WHERE b.bettype = 29 AND b.matchid = 29

	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT b.refno
	FROM dbo.bettrans14 b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid
	WHERE b.bettype = 29 AND b.matchid = 29

	/* Bet Tickets */
	--5.  bodb02.dbo.BettransInfo	
	DELETE binfo
	FROM dbo.BettransInfo binfo WITH (ROWLOCK)
		INNER JOIN bettrans b WITH (NOLOCK) ON b.TransId = binfo.transid
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--6.  bodb02.dbo.BettransInfo14
	DELETE binfo
	FROM dbo.BettransInfo14 binfo WITH (ROWLOCK)
		INNER JOIN bettrans14 b WITH (NOLOCK) ON b.TransId = binfo.transid
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--18. bodb02.dbo.Transfer_Coll
	DELETE tc
	FROM dbo.Transfer_Coll tc WITH (ROWLOCK)
		INNER JOIN dbo.Transfer b WITH (NOLOCK) ON b.TransId = tc.TransID
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--19. bodb02.dbo.TransferInfo
	DELETE tc
	FROM dbo.TransferInfo tc WITH (ROWLOCK)
		INNER JOIN dbo.Transfer b WITH (NOLOCK) ON b.TransId = tc.TransID
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--20. bodb02.dbo.BetParlayDetail	
	DELETE b
	FROM dbo.BetParlayDetail b WITH (ROWLOCK)
		INNER JOIN #tmp_refno tmp ON tmp.refno = b.RefNo

	--21. bodb02.dbo.BetParlayResult
	DELETE b
	FROM dbo.BetParlayResult b WITH (ROWLOCK)
		INNER JOIN #tmp_refno tmp ON tmp.refno = b.RefNo

	/*Other Tables */
	--10. bodb02.dbo.Task_bettrans14_IP2Country
	DELETE tbip
	FROM dbo.Task_bettrans14_IP2Country tbip WITH (ROWLOCK)
		INNER JOIN bettrans14 b WITH (NOLOCK) ON b.TransId = tbip.transid
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--11. bodb02.dbo.Task_bettransLC14_IP2Country
	DELETE tbip
	FROM dbo.Task_bettransLC14_IP2Country tbip WITH (ROWLOCK)
		INNER JOIN bettransLC14 b WITH (NOLOCK) ON b.TransId = tbip.transid
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--12. bodb02.dbo.Task_bettransRNG14_IP2Country
	DELETE tbip
	FROM dbo.Task_bettransRNG14_IP2Country tbip WITH (ROWLOCK)
		INNER JOIN bettransRnG14 b WITH (NOLOCK) ON b.TransId = tbip.transid
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid
	
	--------------------------------------------------------
	/*******************Bet Tickets Tables**********************/
	--1.  bodb02.dbo.bettrans	
	DELETE b
	FROM dbo.bettrans b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--2.  bodb02.dbo.bettrans14
	DELETE b
	FROM dbo.bettrans14 b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--3.  bodb02.dbo.bettransG		
	DELETE b
	FROM dbo.bettransG b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--4.  bodb02.dbo.bettransG14
	DELETE b
	FROM dbo.bettransG14 b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--7.  bodb02.dbo.bettransLC		
	DELETE b
	FROM dbo.bettransLC b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--8.  bodb02.dbo.bettransLC14
	DELETE b
	FROM dbo.bettransLC14 b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--9.  bodb02.dbo.bettransm	
	DELETE b
	FROM dbo.bettransm b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--10. bodb02.dbo.bettransm14
	DELETE b
	FROM dbo.bettransm14 b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--11. bodb02.dbo.bettransRnG		
	DELETE b
	FROM dbo.bettransRnG b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--12. bodb02.dbo.bettransRnG14
	DELETE b
	FROM dbo.bettransRnG14 b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--13. bodb02.dbo.translog
	DELETE b
	FROM dbo.translog b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--14. bodb02.dbo.translog14
	DELETE b
	FROM dbo.translog14 b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--15. bodb02.dbo.zzzbettrans	
	DELETE b
	FROM dbo.zzzbettrans b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--16. bodb02.dbo.zzzbettransm
	DELETE b
	FROM dbo.zzzbettransm b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--17. bodb02.dbo.Transfer
	DELETE b
	FROM dbo.Transfer b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid
	
	/********************Tables Balance*************************/
	--1.  bodb02.dbo.BalCreditCasino
	DELETE b
	FROM dbo.BalCreditCasino b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--2.  bodb02.dbo.BalCreditOthers
	DELETE b
	FROM dbo.BalCreditOthers b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--3.  bodb02.dbo.BalCreditSports
	DELETE b
	FROM dbo.BalCreditSports b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--4.  bodb02.dbo.BalCreditTransfer
	DELETE b
	FROM dbo.BalCreditTransfer b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--5.  bodb02.dbo.BalDebitCasino
	DELETE b
	FROM dbo.BalDebitCasino b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--6.  bodb02.dbo.BalDebitOthers
	DELETE b
	FROM dbo.BalDebitOthers b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--7.  bodb02.dbo.BalDebitSports
	DELETE b
	FROM dbo.BalDebitSports b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--8.  bodb02.dbo.BalDebitTransfer
	DELETE b
	FROM dbo.BalDebitTransfer b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--9.  bodb02.dbo.BalNetPosition
	DELETE b
	FROM dbo.BalNetPosition b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--10. bodb02.dbo.balanceTable
	DELETE b
	FROM dbo.balanceTable b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--11. bodb02.dbo.balanceTable_tmp
	DELETE b
	FROM dbo.balanceTable_tmp b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--12. bodb02.dbo.BalanceTable_tmp_cal
	DELETE b
	FROM dbo.BalanceTable_tmp_cal b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	/*******************Other Tables**********************/
	--1.  bodb02.dbo.Bonus_sum_winloss
	DELETE b
	FROM dbo.Bonus_sum_winloss b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--2.  bodb02.dbo.BonusAdjustmentTransfer
	DELETE b
	FROM dbo.BonusAdjustmentTransfer b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--3.  bodb02.dbo.BonusTrans
	DELETE b
	FROM dbo.BonusTrans b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--4.  bodb02.dbo.BonusWalletCredit
	DELETE b
	FROM dbo.BonusWalletCredit b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--5.  bodb02.dbo.BonusWalletDebit
	DELETE b
	FROM dbo.BonusWalletDebit b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--6.  bodb02.dbo.BonusWalletPending
	DELETE b
	FROM dbo.BonusWalletPending b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--7.  bodb02.dbo.CashOutSelling
	DELETE b
	FROM dbo.CashOutSelling b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--8.  bodb02.dbo.CustLimitBet_LIC
	DELETE b
	FROM dbo.CustLimitBet_LIC b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--9.  bodb02.dbo.CustLimitBetHistory_LIC
	DELETE b
	FROM dbo.CustLimitBetHistory_LIC b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	/*******************TW Tables list**********************/
	--1.  bodb02.dbo.BalancePendingCreditGame
	DELETE b
	FROM dbo.BalancePendingCreditGame b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--2.  bodb02.dbo.BalancePendingDebitGame
	DELETE b
	FROM dbo.BalancePendingDebitGame b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--3.  bodb02.dbo.BalCreditCasinoPending
	DELETE b
	FROM dbo.BalCreditCasinoPending b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--4.  bodb02.dbo.BalCreditOthersPending
	DELETE b
	FROM dbo.BalCreditOthersPending b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--5.  bodb02.dbo.BalCreditSportsPending
	DELETE b
	FROM dbo.BalCreditSportsPending b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--6.  bodb02.dbo.BalDebitCasinoPending
	DELETE b
	FROM dbo.BalDebitCasinoPending b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--7.  bodb02.dbo.BalDebitOthersPending
	DELETE b
	FROM dbo.BalDebitOthersPending b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--8.  bodb02.dbo.BalDebitSportsPending
	DELETE b
	FROM dbo.BalDebitSportsPending b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--9.  bodb02.dbo.Intg_GameRoundBetStake
	DELETE b
	FROM dbo.Intg_GameRoundBetStake b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--10. bodb02.dbo.LastBetTime
	DELETE b
	FROM dbo.LastBetTime b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--11. bodb02.dbo.LastBetTime_Agent
	DELETE b
	FROM dbo.LastBetTime_Agent b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--12. bodb02.dbo.MarkedTransaction
	DELETE b
	FROM dbo.MarkedTransaction b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--13. bodb02.dbo.NetPositionCalculationLog
	DELETE b
	FROM dbo.NetPositionCalculationLog b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--14. bodb02.dbo.NetPositionTrans
	DELETE b
	FROM dbo.NetPositionTrans b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--15. bodb02.dbo.Task_Cust_CheckBalance_Exception
	DELETE b
	FROM dbo.Task_Cust_CheckBalance_Exception b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--16. bodb02.dbo.Task_Cust_BalanceProblem1
	DELETE b
	FROM dbo.Task_Cust_BalanceProblem1 b WITH (ROWLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	------------------------------------------------
	DROP TABLE #tmp_cust
	DROP TABLE #tmp_refno