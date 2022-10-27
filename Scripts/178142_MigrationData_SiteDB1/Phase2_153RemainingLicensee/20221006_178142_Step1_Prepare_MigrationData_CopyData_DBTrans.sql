/*<info serverAlias="DBSIG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Real Licensee
    DB: DBCTG-SiteDBtmp

	 Revisions:
		- 20220926@Victoria: SELECT data INTO new tables for the following tables [Redmineid:#178142] 
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

USE SiteDBtmp
GO

CREATE TABLE cust_20221006
(
	custid INT PRIMARY KEY
)

------------------------------------------------
INSERT INTO cust_20221006 (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer WITH (NOLOCK)
WHERE site IN ('allwincity','allwinCV','bdtt','bdtt2','GB888CV','Bobbet','Tianbo','DingTai','MTech','Omni88','e8casino','e8casinoCV','GoldenF','LEIHUO','DongYing','bmwbet','HIDZ','HONBET','Newhonbet','HOT99','XTDGT','LLgaming','AEUG','UG2','JJBGAME','VKGAME','JJBGAMECV','VKGAMECV','KOKVN','KOKVN2','Lucky88','11bet','Fabet','One88','Debet','Zbet','Sin88','Sunwin','Five88','Red88','Lode88','Zowin','SV88','Nbet','OXbet','Sky88','SM88','SL88SW','Okada','BPLE','OkadaSW','SunGame','Sun988','SSSSEA','Ty777','Mopgaming','Raisetech','TopGame','ZFRT143','ZFRT166','ZhiFeng055','ZFRT156','ZhiFeng106','ZhiFeng122','ZFRT129','ZhiFeng098','ZFRT165','ZFRT144','ZhiFeng147','ZFRT155','ZhiFeng026','ZFRT186','ZhiFeng156','ZhiFeng133','ZFRT126CV','ZFRT126','CENTRAL168','ZFRT090','ZF055PMW','ZFRT195','ZhiFeng138','ZhiFeng183','ZhiFeng013','ZFRT167','ZF138THB','ZFRT144CV','ZF138VND','ZFRT161','ZhiFeng201','ZFRT158CV','Zhifeng215','ZhiFeng208','ZFRT213','ZhiFeng222','Zzun88','Man1878','iBET','Xinbo','HonorW','M8Credit','FLC','OCMS','dj888','JIBET','awc2','YongBao','Datang001','infini88','Hecbet','Royal','vssports','DEWA','88Macao','9wickets','LSM99','Leng4D','Bonanza88','Senibet','WBS','OPEBET','DFGame','OYO','awc','loc','wmcasino','OESports','yuanbao','Rakyat4DSW','GBET','Towin','C7YOUXICV','SEAL888','ZF026','starsoccer','24AVIASL','H1royal','HFYX','ZhiFeng142','ZFRT218','KSTECH','WLSTAR','ZFRT198','F88IN1SW','ZhiFeng084','GoldenF2CV','WGAMING','DMsports','12B','Riverich','ZF215aTR','AKYL99','Lucklotter','Niu8gaming')


	



	