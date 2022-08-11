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
	INSERT INTO [dbo].[Bonus_sum_winloss] ([CustId], [BonusId], [winlostdate], [Amount])
	SELECT bon.[CustId], bon.[BonusId], bon.[winlostdate], bon.[Amount]
	FROM [dbo].[Bonus_sum_winloss_old20220825] bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--2. BonusAdjustmentTransfer
	-- There is no index on custid for table BonusAdjustmentTransfer, has only an index on ExecID
	SET IDENTITY_INSERT BonusAdjustmentTransfer ON

	INSERT INTO [dbo].[BonusAdjustmentTransfer] ([ExecID], [LogDate], [ExecDate], [CustID], [MatchID], [BonusID], [StatusID], [Amount], [isTransferred])
	SELECT bon.[ExecID], bon.[LogDate], bon.[ExecDate], bon.[CustID], bon.[MatchID], bon.[BonusID], bon.[StatusID], bon.[Amount], bon.[isTransferred]
	FROM [dbo].[BonusAdjustmentTransfer_old20220825] bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	SET IDENTITY_INSERT BonusAdjustmentTransfer OFF

	--3. BonusTrans
	SET IDENTITY_INSERT BonusTrans ON

	INSERT INTO [dbo].[BonusTrans] ([BonusTransId], [CustID], [Recommend], [Mrecommend], [Srecommend], [Amount], [StatusId], [Creator], [CreatedDate], 
									[PaymentDate], [IsComplained])
	SELECT  bon.[BonusTransId], bon.[CustID], bon.[Recommend], bon.[Mrecommend], bon.[Srecommend], bon.[Amount], bon.[StatusId], bon.[Creator], bon.[CreatedDate], 
			bon.[PaymentDate], bon.[IsComplained]
	FROM [dbo].[BonusTrans_old20220825] bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	SET IDENTITY_INSERT BonusTrans OFF

	--4. BonusWalletCredit
	INSERT INTO [dbo].[BonusWalletCredit] ([CustID], [BonusID], [StatusID], [initBonus], [LockedAmt], [Amount])
	SELECT  bon.[CustID], bon.[BonusID], bon.[StatusID], bon.[initBonus], bon.[LockedAmt], bon.[Amount]
	FROM [dbo].[BonusWalletCredit_old20220825] bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--5. BonusWalletDebit
	INSERT INTO [dbo].[BonusWalletDebit] ([CustID], [BonusID], [Amount])
	SELECT  bon.[CustID], bon.[BonusID], bon.[Amount]
	FROM [dbo].[BonusWalletDebit_old20220825] bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--6. BonusWalletPending
	-- There is no index on custid for table BonusWalletPending, has only an index on Rn
	SET IDENTITY_INSERT BonusWalletPending ON

	INSERT INTO [dbo].[BonusWalletPending] ([Rn], [CustID], [BonusID], [Amount])
	SELECT  bon.[Rn], bon.[CustID], bon.[BonusID], bon.[Amount]
	FROM [dbo].[BonusWalletPending_old20220825] bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	SET IDENTITY_INSERT BonusWalletPending OFF

	--7. CashOutSelling
	-- There is no index on custid for table CashOutSelling, has only an index on TransID
	INSERT INTO [dbo].[CashOutSelling] ([TransID], [MatchID], [Bettype], [Custid], [CashOutStatus], [Winlost], [PriceInfo], [CheckTime], 
										[CreateDate], [ChangeDate], [IsTest], [VirtualRate], [CashOutExtraInfo])
	SELECT	cosell.[TransID], cosell.[MatchID], cosell.[Bettype], cosell.[Custid], cosell.[CashOutStatus], cosell.[Winlost], cosell.[PriceInfo], cosell.[CheckTime], 
			cosell.[CreateDate], cosell.[ChangeDate], cosell.[IsTest], cosell.[VirtualRate], cosell.[CashOutExtraInfo]
	FROM [dbo].[CashOutSelling_old20220825] cosell WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = cosell.custid

	--8. CustLimitBet_LIC
	INSERT INTO [dbo].[CustLimitBet_LIC] ([Matchid], [CustID], [AccumTurnover], [AccumPayout], [EventTypeID], [LastQueueID], [ModifiedDate])
	SELECT	clb.[Matchid], clb.[CustID], clb.[AccumTurnover], clb.[AccumPayout], clb.[EventTypeID], clb.[LastQueueID], clb.[ModifiedDate]
	FROM [dbo].[CustLimitBet_LIC_old20220825] clb WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = clb.custid

	--9. CustLimitBetHistory_LIC
	INSERT INTO [dbo].[CustLimitBetHistory_LIC] ([Matchid], [CustID], [Transid], [TurnoverAdjust], [PayoutAdjust], [EventTypeID], [CreatedDate])
	SELECT	clbh.[Matchid], clbh.[CustID], clbh.[Transid], clbh.[TurnoverAdjust], clbh.[PayoutAdjust], clbh.[EventTypeID], clbh.[CreatedDate]
	FROM [dbo].[CustLimitBetHistory_LIC_old20220825] clbh WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = clbh.custid

	------------------------------------------------
	DROP TABLE #tmp_cust