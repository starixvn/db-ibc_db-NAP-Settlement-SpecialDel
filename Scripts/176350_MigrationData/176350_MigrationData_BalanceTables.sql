/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220811@Victoria
    Task: Data Migration for SiteDB - Existing Licensee
    DB: DBSIG-bodb02

	 Revisions:
		- 20220811@Victoria: INSERT data for the following tables balance [Redmineid:#176350]
									1.  dbo.BalCreditCasino
									2.  dbo.BalCreditOthers
									3.  dbo.BalCreditSports
									4.  dbo.BalCreditTransfer
									5.  dbo.BalDebitCasino
									6.  dbo.BalDebitOthers
									7.  dbo.BalDebitSports
									8.  dbo.BalDebitTransfer
									9.  dbo.BalNetPosition
									10. dbo.balanceTable
									11. dbo.balanceTable_tmp
									12. dbo.BalanceTable_tmp_cal

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
	
	--1. BalCreditCasino
	INSERT INTO [dbo].[BalCreditCasino] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM [dbo].[BalCreditCasino_old20220825] bal WITH (NOLOCK)
	INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--2. BalCreditOthers
	INSERT INTO [dbo].[BalCreditOthers] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM [dbo].[BalCreditOthers_old20220825] bal WITH (NOLOCK)
	INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--3. BalCreditSports
	INSERT INTO [dbo].[BalCreditSports] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM [dbo].[BalCreditSports_old20220825] bal WITH (NOLOCK)
	INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--4. BalCreditTransfer
	INSERT INTO  [dbo].[BalCreditTransfer]([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM [dbo].[BalCreditTransfer_old20220825] bal WITH (NOLOCK)
	INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--5. BalDebitCasino
	INSERT INTO  [dbo].[BalDebitCasino]([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM [dbo].[BalDebitCasino_old20220825] bal WITH (NOLOCK)
	INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--6. BalDebitOthers
	INSERT INTO [dbo].[BalDebitOthers]([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM [dbo].[BalDebitOthers_old20220825] bal WITH (NOLOCK)
	INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--7. BalDebitSports
	INSERT INTO [dbo].[BalDebitSports]([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM [dbo].[BalDebitSports_old20220825] bal WITH (NOLOCK)
	INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--8. BalDebitTransfer
	INSERT INTO [dbo].[BalDebitTransfer]([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM [dbo].[BalDebitTransfer_old20220825] bal WITH (NOLOCK)
	INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--9. BalNetPosition
	INSERT INTO [dbo].[BalNetPosition]([CustID], [MatchID], [Bettype], [Debit], [Credit], [CreatedDate], [ModifiedDate])
	SELECT bal.[CustID], bal.[MatchID], bal.[Bettype], bal.[Debit], bal.[Credit], bal.[CreatedDate], bal.[ModifiedDate]
	FROM [dbo].[BalNetPosition_old20220825] bal WITH (NOLOCK)
	INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--10. balanceTable
	--There is no index for table balanceTable
	INSERT INTO [dbo].[balanceTable](	[custid], [roleid], [amount], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [recommend], [mrecommend], 
										[srecommend], [currency], [UserName], [CurrencyName], [actualrate], [TicketCount], [balTicketCount])
	SELECT  bal.[custid], bal.[roleid], bal.[amount], bal.[awinlost], bal.[mwinlost], bal.[swinlost], bal.[playercomm], bal.[comm], bal.[acomm], bal.[scomm], bal.[recommend], bal.[mrecommend], 
			bal.[srecommend], bal.[currency], bal.[UserName], bal.[CurrencyName], bal.[actualrate], bal.[TicketCount], bal.[balTicketCount]
	FROM [dbo].[balanceTable_old20220825] bal WITH (NOLOCK)
	INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--11. balanceTable_tmp
	INSERT INTO [dbo].[balanceTable_tmp](	[winlostdate], [custid], [roleid], [amount], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [recommend], [mrecommend], 
											[srecommend], [currency], [UserName], [CurrencyName], [actualrate], [TicketCount], [balTicketCount])
	SELECT  bal.[winlostdate], bal.[custid], bal.[roleid], bal.[amount], bal.[awinlost], bal.[mwinlost], bal.[swinlost], bal.[playercomm], bal.[comm], bal.[acomm], bal.[scomm], bal.[recommend], bal.[mrecommend], 
			bal.[srecommend], bal.[currency], bal.[UserName], bal.[CurrencyName], bal.[actualrate], bal.[TicketCount], bal.[balTicketCount]
	FROM [dbo].[balanceTable_tmp_old20220825] bal WITH (NOLOCK)
	INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--12. BalanceTable_tmp_cal
	--There is no index for table balanceTable
	INSERT INTO [dbo].[BalanceTable_tmp_cal] (	[dow], [roleid], [custid], [recommend], [mrecommend], [srecommend], 
												[amt1], [tcnt1], [amt2], [tcnt2], [amt3], [tcnt3], [amt4], [tcnt4])
	SELECT	bal.[dow], bal.[roleid], bal.[custid], bal.[recommend], bal.[mrecommend], bal.[srecommend], 
			bal.[amt1], bal.[tcnt1], bal.[amt2], bal.[tcnt2], bal.[amt3], bal.[tcnt3], bal.[amt4], bal.[tcnt4]
	FROM [dbo].[BalanceTable_tmp_cal_old20220825] bal WITH (NOLOCK)
	INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	------------------------------------------------
	DROP TABLE #tmp_cust