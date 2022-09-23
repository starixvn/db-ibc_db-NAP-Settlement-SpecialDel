/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220811@Victoria
    Task: Data Migration for SiteDB - Existing Licensee
    DB: DBSIG-bodb02

	 Revisions:
		- 20220811@Victoria: INSERT data for the following tables - Other tables [Redmineid:#176350]
									1.  dbo.Bonus_sum_winloss
									2.  dbo.BonusAdjustmentTransfer
									3.  dbo.BonusTrans
									4.  dbo.BonusWalletCredit
									5.  dbo.BonusWalletDebit
									6.  dbo.BonusWalletPending
									7.  dbo.CashOutSelling
									8.  dbo.CustLimitBet_LIC
									9.  dbo.CustLimitBetHistory_LIC
									10. dbo.Task_bettrans14_IP2Country
									11. dbo.Task_bettransLC14_IP2Country
									12. dbo.Task_bettransRNG14_IP2Country

*/

	USE bodb02
	GO

	
	CREATE TABLE #tmp_cust
	(
		custid INT PRIMARY KEY
	)
	
	------------------------------------------------
	INSERT INTO #tmp_cust (custid)
	SELECT DISTINCT custid
	FROM CustDB.dbo.Customer WITH (NOLOCK)
	WHERE site IN ('Athena000','SampleSite')
	------------------------------------------------
	
	--1. Bonus_sum_winloss
	--INSERT INTO [dbo].[Bonus_sum_winloss] ([CustId], [BonusId], [winlostdate], [Amount])
	SELECT bon.[CustId], bon.[BonusId], bon.[winlostdate], bon.[Amount]
	INTO [Bonus_sum_winloss_old20220825]
	FROM [dbo].[Bonus_sum_winloss] bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--2. BonusAdjustmentTransfer
	-- There is no index on custid for table BonusAdjustmentTransfer, has only an index on ExecID
	--SET IDENTITY_INSERT BonusAdjustmentTransfer ON

	--INSERT INTO [dbo].[BonusAdjustmentTransfer] ([ExecID], [LogDate], [ExecDate], [CustID], [MatchID], [BonusID], [StatusID], [Amount], [isTransferred])
	SELECT bon.[ExecID], bon.[LogDate], bon.[ExecDate], bon.[CustID], bon.[MatchID], bon.[BonusID], bon.[StatusID], bon.[Amount], bon.[isTransferred]
	INTO [BonusAdjustmentTransfer_old20220825]
	FROM [dbo].[BonusAdjustmentTransfer] bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--SET IDENTITY_INSERT BonusAdjustmentTransfer OFF

	--3. BonusTrans
	--SET IDENTITY_INSERT BonusTrans ON

	--INSERT INTO [dbo].[BonusTrans] ([BonusTransId], [CustID], [Recommend], [Mrecommend], [Srecommend], [Amount], [StatusId], [Creator], [CreatedDate], 
									--[PaymentDate], [IsComplained])
	SELECT  bon.[BonusTransId], bon.[CustID], bon.[Recommend], bon.[Mrecommend], bon.[Srecommend], bon.[Amount], bon.[StatusId], bon.[Creator], bon.[CreatedDate], 
			bon.[PaymentDate], bon.[IsComplained]
	INTO [BonusTrans_old20220825]
	FROM [dbo].[BonusTrans] bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--SET IDENTITY_INSERT BonusTrans OFF

	--4. BonusWalletCredit
	--INSERT INTO [dbo].[BonusWalletCredit] ([CustID], [BonusID], [StatusID], [initBonus], [LockedAmt], [Amount])
	SELECT  bon.[CustID], bon.[BonusID], bon.[StatusID], bon.[initBonus], bon.[LockedAmt], bon.[Amount]
	INTO [BonusWalletCredit_old20220825]
	FROM [dbo].[BonusWalletCredit] bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--5. BonusWalletDebit
	--INSERT INTO [dbo].[BonusWalletDebit] ([CustID], [BonusID], [Amount])
	SELECT  bon.[CustID], bon.[BonusID], bon.[Amount]
	INTO [BonusWalletDebit_old20220825]
	FROM [dbo].[BonusWalletDebit] bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--6. BonusWalletPending
	-- There is no index on custid for table BonusWalletPending, has only an index on Rn
	--SET IDENTITY_INSERT BonusWalletPending ON

	--INSERT INTO [dbo].[BonusWalletPending] ([Rn], [CustID], [BonusID], [Amount])
	SELECT  bon.[Rn], bon.[CustID], bon.[BonusID], bon.[Amount]
	INTO [BonusWalletPending_old20220825]
	FROM [dbo].[BonusWalletPending] bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--SET IDENTITY_INSERT BonusWalletPending OFF

	--7. CashOutSelling
	-- There is no index on custid for table CashOutSelling, has only an index on TransID
	--INSERT INTO [dbo].[CashOutSelling] ([TransID], [MatchID], [Bettype], [Custid], [CashOutStatus], [Winlost], [PriceInfo], [CheckTime], 
										--[CreateDate], [ChangeDate], [IsTest], [VirtualRate], [CashOutExtraInfo])
	SELECT	cosell.[TransID], cosell.[MatchID], cosell.[Bettype], cosell.[Custid], cosell.[CashOutStatus], cosell.[Winlost], cosell.[PriceInfo], cosell.[CheckTime], 
			cosell.[CreateDate], cosell.[ChangeDate], cosell.[IsTest], cosell.[VirtualRate], cosell.[CashOutExtraInfo]
	INTO [CashOutSelling_old20220825]
	FROM [dbo].[CashOutSelling] cosell WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = cosell.custid

	--8. CustLimitBet_LIC
	--INSERT INTO [dbo].[CustLimitBet_LIC] ([Matchid], [CustID], [AccumTurnover], [AccumPayout], [EventTypeID], [LastQueueID], [ModifiedDate])
	SELECT	clb.[Matchid], clb.[CustID], clb.[AccumTurnover], clb.[AccumPayout], clb.[EventTypeID], clb.[LastQueueID], clb.[ModifiedDate]
	INTO [CustLimitBet_LIC_old20220825]
	FROM [dbo].[CustLimitBet_LIC] clb WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = clb.custid

	--9. CustLimitBetHistory_LIC
	--INSERT INTO [dbo].[CustLimitBetHistory_LIC] ([Matchid], [CustID], [Transid], [TurnoverAdjust], [PayoutAdjust], [EventTypeID], [CreatedDate])
	SELECT	clbh.[Matchid], clbh.[CustID], clbh.[Transid], clbh.[TurnoverAdjust], clbh.[PayoutAdjust], clbh.[EventTypeID], clbh.[CreatedDate]
	INTO [CustLimitBetHistory_LIC_old20220825]
	FROM [dbo].[CustLimitBetHistory_LIC] clbh WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = clbh.custid

	--10. dbo.Task_bettrans14_IP2Country
	SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
	INTO [Task_bettrans14_IP2Country_old20220825]
	FROM [dbo].[Task_bettrans14_IP2Country] tbip WITH (NOLOCK)
		INNER JOIN [dbo].[bettrans14] b WITH (NOLOCK) ON b.transid = tbip.transid
		
	--11. dbo.Task_bettransLC14_IP2Country
	SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
	INTO [Task_bettransLC14_IP2Country_old20220825]
	FROM [dbo].[Task_bettransLC14_IP2Country] tbip WITH (NOLOCK)
		INNER JOIN [dbo].[bettransLC14] b WITH (NOLOCK) ON b.transid = tbip.transid

	--12. dbo.Task_bettransRNG14_IP2Country
	SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
	INTO [Task_bettransRNG14_IP2Country_old20220825]
	FROM [dbo].[Task_bettransRNG14_IP2Country] tbip WITH (NOLOCK)
		INNER JOIN [dbo].[bettransRNG14] b WITH (NOLOCK) ON b.transid = tbip.transid

	------------------------------------------------
	DROP TABLE #tmp_cust
GO


TRUNCATE TABLE  dbo.Bonus_sum_winloss
TRUNCATE TABLE  dbo.BonusAdjustmentTransfer
TRUNCATE TABLE  dbo.BonusTrans
TRUNCATE TABLE  dbo.BonusWalletCredit
TRUNCATE TABLE  dbo.BonusWalletDebit
TRUNCATE TABLE  dbo.BonusWalletPending
TRUNCATE TABLE  dbo.CashOutSelling
TRUNCATE TABLE  dbo.CustLimitBet_LIC
TRUNCATE TABLE  dbo.CustLimitBetHistory_LIC
TRUNCATE TABLE  dbo.Task_bettrans14_IP2Country
TRUNCATE TABLE  dbo.Task_bettransLC14_IP2Country
TRUNCATE TABLE  dbo.Task_bettransRNG14_IP2Country


--- INSERT DATA 
--1. Bonus_sum_winloss
	INSERT INTO [dbo].[Bonus_sum_winloss] ([CustId], [BonusId], [winlostdate], [Amount])
	SELECT bon.[CustId], bon.[BonusId], bon.[winlostdate], bon.[Amount]
	FROM [dbo].[Bonus_sum_winloss_old20220825] bon WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--2. BonusAdjustmentTransfer
	-- There is no index on custid for table BonusAdjustmentTransfer, has only an index on ExecID
	SET IDENTITY_INSERT BonusAdjustmentTransfer ON

	INSERT INTO [dbo].[BonusAdjustmentTransfer] ([ExecID], [LogDate], [ExecDate], [CustID], [MatchID], [BonusID], [StatusID], [Amount], [isTransferred])
	SELECT bon.[ExecID], bon.[LogDate], bon.[ExecDate], bon.[CustID], bon.[MatchID], bon.[BonusID], bon.[StatusID], bon.[Amount], bon.[isTransferred]
	FROM [dbo].[BonusAdjustmentTransfer_old20220825] bon WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	SET IDENTITY_INSERT BonusAdjustmentTransfer OFF

	--3. BonusTrans
	SET IDENTITY_INSERT BonusTrans ON

	INSERT INTO [dbo].[BonusTrans] ([BonusTransId], [CustID], [Recommend], [Mrecommend], [Srecommend], [Amount], [StatusId], [Creator], [CreatedDate], 
									[PaymentDate], [IsComplained])
	SELECT  bon.[BonusTransId], bon.[CustID], bon.[Recommend], bon.[Mrecommend], bon.[Srecommend], bon.[Amount], bon.[StatusId], bon.[Creator], bon.[CreatedDate], 
			bon.[PaymentDate], bon.[IsComplained]
	FROM [dbo].[BonusTrans_old20220825] bon WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	SET IDENTITY_INSERT BonusTrans OFF

	--4. BonusWalletCredit
	INSERT INTO [dbo].[BonusWalletCredit] ([CustID], [BonusID], [StatusID], [initBonus], [LockedAmt], [Amount])
	SELECT  bon.[CustID], bon.[BonusID], bon.[StatusID], bon.[initBonus], bon.[LockedAmt], bon.[Amount]
	FROM [dbo].[BonusWalletCredit_old20220825] bon WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--5. BonusWalletDebit
	INSERT INTO [dbo].[BonusWalletDebit] ([CustID], [BonusID], [Amount])
	SELECT  bon.[CustID], bon.[BonusID], bon.[Amount]
	FROM [dbo].[BonusWalletDebit_old20220825] bon WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--6. BonusWalletPending
	-- There is no index on custid for table BonusWalletPending, has only an index on Rn
	SET IDENTITY_INSERT BonusWalletPending ON

	INSERT INTO [dbo].[BonusWalletPending] ([Rn], [CustID], [BonusID], [Amount])
	SELECT  bon.[Rn], bon.[CustID], bon.[BonusID], bon.[Amount]
	FROM [dbo].[BonusWalletPending_old20220825] bon WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	SET IDENTITY_INSERT BonusWalletPending OFF

	--7. CashOutSelling
	-- There is no index on custid for table CashOutSelling, has only an index on TransID
	INSERT INTO [dbo].[CashOutSelling] ([TransID], [MatchID], [Bettype], [Custid], [CashOutStatus], [Winlost], [PriceInfo], [CheckTime], 
										[CreateDate], [ChangeDate], [IsTest], [VirtualRate], [CashOutExtraInfo])
	SELECT	cosell.[TransID], cosell.[MatchID], cosell.[Bettype], cosell.[Custid], cosell.[CashOutStatus], cosell.[Winlost], cosell.[PriceInfo], cosell.[CheckTime], 
			cosell.[CreateDate], cosell.[ChangeDate], cosell.[IsTest], cosell.[VirtualRate], cosell.[CashOutExtraInfo]
	FROM [dbo].[CashOutSelling_old20220825] cosell WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = cosell.custid

	--8. CustLimitBet_LIC
	INSERT INTO [dbo].[CustLimitBet_LIC] ([Matchid], [CustID], [AccumTurnover], [AccumPayout], [EventTypeID], [LastQueueID], [ModifiedDate])
	SELECT	clb.[Matchid], clb.[CustID], clb.[AccumTurnover], clb.[AccumPayout], clb.[EventTypeID], clb.[LastQueueID], clb.[ModifiedDate]
	FROM [dbo].[CustLimitBet_LIC_old20220825] clb WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = clb.custid

	--9. CustLimitBetHistory_LIC
	INSERT INTO [dbo].[CustLimitBetHistory_LIC] ([Matchid], [CustID], [Transid], [TurnoverAdjust], [PayoutAdjust], [EventTypeID], [CreatedDate])
	SELECT	clbh.[Matchid], clbh.[CustID], clbh.[Transid], clbh.[TurnoverAdjust], clbh.[PayoutAdjust], clbh.[EventTypeID], clbh.[CreatedDate]
	FROM [dbo].[CustLimitBetHistory_LIC_old20220825] clbh WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = clbh.custid

	--10. dbo.Task_bettrans14_IP2Country
	INSERT INTO Task_bettrans14_IP2Country ([transid], [winlostdate], [CountryShort], [IPArchive])
	SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
	FROM [dbo].[Task_bettrans14_IP2Country_old20220825] tbip WITH (NOLOCK)
		
	--11. dbo.Task_bettransLC14_IP2Country
	INSERT INTO Task_bettransLC14_IP2Country ([transid], [winlostdate], [CountryShort], [IPArchive])
	SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
	FROM [dbo].[Task_bettransLC14_IP2Country_old20220825] tbip WITH (NOLOCK)

	--12. dbo.Task_bettransRNG14_IP2Country
	INSERT INTO Task_bettransRNG14_IP2Country ([transid], [winlostdate], [CountryShort], [IPArchive])
	SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
	FROM [dbo].[Task_bettransRNG14_IP2Country_old20220825] tbip WITH (NOLOCK)