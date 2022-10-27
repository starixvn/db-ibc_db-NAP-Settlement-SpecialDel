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
WHERE site IN ('24Tech','MRCATSB','24AVIA','ig128','A1game','txwl002','weicai','shengboyun','633esports','pmwint','Diamond','ig128s','442ball','asiabet88','TLC','JBO','Betway','KingFun','IBO','Kzing2','MANBETX','LS88','TH3','V03','XTSB','KZO41','kzsbxjCV','Nexus','IGPTech','AJJCV','KeenOcean','K8VN','Storm88','liv66','liv66SW','win365','livv88sw','WINHX1','KhmerG','afb99','khmer','ManCity','Mancity2','N88','N8B','N8G','NukeGaming','Pay4d','Weiwei','Avia','MARS','AnvoFH','erhaozhan','TCbet','TaoCai','FHLMSABA','Titank','FHLMSABAS','Sunrise','Sunriseb2b','SunriseCV','Wanfang','KUTECH','GamingSoft','Dade','Nbbet','BetDeal','Xtu168','GSCSW','Yibo','YiboCV','JIDU','Wanbo','ZhiFeng032','ZhiFeng036','ZhiFeng035','ZhiFeng021','ZhiFeng009','ZFRT082','mtegames','ZhiFeng037','ZFRT125','ZFRT133','NewFuture','ZFRT132','ZhiFeng040','ZFRT128','ZFRT080','JIB88','ZhiFeng012','ZFRT115','ZFRT142','SAGAME88','ZFRT150','ZFRT081','NextBet','IONclub','Ae88','Liga','ISC888')


	



	