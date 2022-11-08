/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - DBTRANS
    DB: DBCTG-bodb02

	 Revisions:
		- 20221107@Victoria: INSERT from the copy all data of the following tables [Redmineid:#180033] 
							 BalCreditCasino,BalCreditOthers,BalCreditSports,BalCreditTransfer,BalDebitCasino,BalDebitOthers,BalDebitSports,
							 BalDebitTransfer,BalNetPosition,balanceTable,balanceTable_tmp,BalanceTable_tmp_cal
*/

USE bodb02
GO
------------------------------------------------
/*********UPDATE DATA IF ALREADY EXISTS****************/
--BalCreditCasino
UPDATE main
SET [Balance] = bal.[Balance]
FROM [dbo].[BalCreditCasino] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN DBSIG01.SiteDB01tmp.dbo.BalCreditCasino_Copy bal ON main.custid = bal.custid

--BalCreditOthers
UPDATE main
SET [Balance] = bal.[Balance]
FROM [dbo].[BalCreditOthers] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN DBSIG01.SiteDB01tmp.dbo.BalCreditOthers_Copy bal WITH (NOLOCK) ON main.custid = bal.custid

--BalCreditSports
UPDATE main
SET [Balance] = bal.[Balance]
FROM [dbo].[BalCreditSports] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN DBSIG01.SiteDB01tmp.dbo.BalCreditSports_Copy bal WITH (NOLOCK) ON main.custid = bal.custid

--BalCreditTransfer
UPDATE main
SET [Balance] = bal.[Balance]
FROM [dbo].[BalCreditTransfer] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN DBSIG01.SiteDB01tmp.dbo.BalCreditTransfer_Copy bal WITH (NOLOCK) ON main.custid = bal.custid

--BalDebitCasino
UPDATE main
SET [Balance] = bal.[Balance]
FROM [dbo].[BalDebitCasino] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN DBSIG01.SiteDB01tmp.dbo.BalDebitCasino_Copy bal WITH (NOLOCK) ON main.custid = bal.custid

--BalDebitOthers
UPDATE main
SET [Balance] = bal.[Balance]
FROM [dbo].[BalDebitOthers] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN DBSIG01.SiteDB01tmp.dbo.BalDebitOthers_Copy bal WITH (NOLOCK) ON main.custid = bal.custid

--BalDebitSports
UPDATE main
SET [Balance] = bal.[Balance]
FROM [dbo].[BalDebitSports] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN DBSIG01.SiteDB01tmp.dbo.BalDebitSports_Copy bal WITH (NOLOCK) ON main.custid = bal.custid

--BalDebitTransfer
UPDATE main
SET [Balance] = bal.[Balance]
FROM [dbo].[BalDebitTransfer] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN DBSIG01.SiteDB01tmp.dbo.BalDebitTransfer_Copy bal WITH (NOLOCK) ON main.custid = bal.custid

--BalNetPosition
UPDATE main
SET [MatchID]=bal.[MatchID],[Bettype]=bal.[Bettype],[Debit]=bal.[Debit],[Credit]=bal.[Credit],[CreatedDate]=bal.[CreatedDate],[ModifiedDate]=bal.[ModifiedDate]
FROM [dbo].[BalNetPosition] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN DBSIG01.SiteDB01tmp.dbo.BalNetPosition_Copy bal WITH (NOLOCK) ON main.custid = bal.custid

--balanceTable
UPDATE main
SET [roleid]=bal.[roleid],[amount]=bal.[amount],[awinlost]=bal.[awinlost],[mwinlost]=bal.[mwinlost],[swinlost]=bal.[swinlost],[playercomm]=bal.[playercomm],[comm]=bal.[comm],
	[acomm]=bal.[acomm],[scomm]=bal.[scomm],[recommend]=bal.[recommend],[mrecommend]=bal.[mrecommend],[srecommend]=bal.[srecommend],[currency]=bal.[currency],
	[UserName]=bal.[UserName],[CurrencyName]=bal.[CurrencyName],[actualrate]=bal.[actualrate],[TicketCount]=bal.[TicketCount],[balTicketCount]=bal.[balTicketCount]
FROM [dbo].[balanceTable] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN DBSIG01.SiteDB01tmp.dbo.balanceTable_Copy bal WITH (NOLOCK) ON main.custid = bal.custid

--balanceTable_tmp
UPDATE main
SET [roleid]=bal.[roleid],[amount]=bal.[amount],[awinlost]=bal.[awinlost],[mwinlost]=bal.[mwinlost],[swinlost]=bal.[swinlost],[playercomm]=bal.[playercomm],[comm]=bal.[comm],
	[acomm]=bal.[acomm],[scomm]=bal.[scomm],[recommend]=bal.[recommend],[mrecommend]=bal.[mrecommend],[srecommend]=bal.[srecommend],[currency]=bal.[currency],
	[UserName]=bal.[UserName],[CurrencyName]=bal.[CurrencyName],[actualrate]=bal.[actualrate],[TicketCount]=bal.[TicketCount],[balTicketCount]=bal.[balTicketCount]
FROM [dbo].[balanceTable_tmp] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN DBSIG01.SiteDB01tmp.dbo.balanceTable_tmp_Copy bal WITH (NOLOCK) ON main.custid = bal.custid AND main.winlostdate = bal.winlostdate

--BalanceTable_tmp_cal
UPDATE main
SET [dow]=bal.[dow],[roleid]=bal.[roleid],[recommend]=bal.[recommend],[mrecommend]=bal.[mrecommend],[srecommend]=bal.[srecommend],
	[amt1]=bal.[amt1],[tcnt1]=bal.[tcnt1],[amt2]=bal.[amt2],[tcnt2]=bal.[tcnt2],[amt3]=bal.[amt3],[tcnt3]=bal.[tcnt3],[amt4]=bal.[amt4],[tcnt4]=bal.[tcnt4]
FROM [dbo].[BalanceTable_tmp_cal] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN DBSIG01.SiteDB01tmp.dbo.BalanceTable_tmp_cal_Copy bal WITH (NOLOCK) ON main.custid = bal.custid

/*********INSERT DATA IF NOT EXISTS****************/
--1. BalCreditCasino
INSERT INTO [dbo].[BalCreditCasino] ([custid], [Balance])
SELECT bal.[custid], bal.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalCreditCasino_Copy bal WITH (NOLOCK)
	LEFT JOIN [dbo].[BalCreditCasino] main WITH (NOLOCK) ON main.custid = bal.custid
WHERE main.custid IS NULL

--2. BalCreditOthers
INSERT INTO [dbo].[BalCreditOthers] ([custid], [Balance])
SELECT bal.[custid], bal.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalCreditOthers_Copy bal WITH (NOLOCK)
	LEFT JOIN [dbo].[BalCreditOthers] main WITH (NOLOCK) ON main.custid = bal.custid
WHERE main.custid IS NULL

--3. BalCreditSports
INSERT INTO [dbo].[BalCreditSports] ([custid], [Balance])
SELECT bal.[custid], bal.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalCreditSports_Copy bal WITH (NOLOCK)
	LEFT JOIN [dbo].[BalCreditSports] main WITH (NOLOCK) ON main.custid = bal.custid
WHERE main.custid IS NULL

--4. BalCreditTransfer
INSERT INTO  [dbo].[BalCreditTransfer]([custid], [Balance])
SELECT bal.[custid], bal.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalCreditTransfer_Copy bal WITH (NOLOCK)
	LEFT JOIN [dbo].[BalCreditTransfer] main WITH (NOLOCK) ON main.custid = bal.custid
WHERE main.custid IS NULL

--5. BalDebitCasino
INSERT INTO  [dbo].[BalDebitCasino]([custid], [Balance])
SELECT bal.[custid], bal.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalDebitCasino_Copy bal WITH (NOLOCK)
	LEFT JOIN [dbo].[BalDebitCasino] main WITH (NOLOCK) ON main.custid = bal.custid
WHERE main.custid IS NULL

--6. BalDebitOthers
INSERT INTO [dbo].[BalDebitOthers]([custid], [Balance])
SELECT bal.[custid], bal.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalDebitOthers_Copy bal WITH (NOLOCK)
	LEFT JOIN [dbo].[BalDebitOthers] main WITH (NOLOCK) ON main.custid = bal.custid
WHERE main.custid IS NULL

--7. BalDebitSports
INSERT INTO [dbo].[BalDebitSports]([custid], [Balance])
SELECT bal.[custid], bal.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalDebitSports_Copy bal WITH (NOLOCK)
	LEFT JOIN [dbo].[BalDebitSports] main WITH (NOLOCK) ON main.custid = bal.custid
WHERE main.custid IS NULL

--8. BalDebitTransfer
INSERT INTO [dbo].[BalDebitTransfer]([custid], [Balance])
SELECT bal.[custid], bal.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalDebitTransfer_Copy bal WITH (NOLOCK)
	LEFT JOIN [dbo].[BalDebitTransfer] main WITH (NOLOCK) ON main.custid = bal.custid
WHERE main.custid IS NULL

--9. BalNetPosition
INSERT INTO [dbo].[BalNetPosition]([CustID], [MatchID], [Bettype], [Debit], [Credit], [CreatedDate], [ModifiedDate])
SELECT bal.[CustID], bal.[MatchID], bal.[Bettype], bal.[Debit], bal.[Credit], bal.[CreatedDate], bal.[ModifiedDate]
FROM DBSIG01.SiteDB01tmp.dbo.BalNetPosition_Copy bal WITH (NOLOCK)
	LEFT JOIN [dbo].[BalNetPosition] main WITH (NOLOCK) ON main.custid = bal.custid
WHERE main.custid IS NULL

--10. balanceTable
--There is no index for table balanceTable
INSERT INTO [dbo].[balanceTable](	[custid], [roleid], [amount], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [recommend], [mrecommend], 
									[srecommend], [currency], [UserName], [CurrencyName], [actualrate], [TicketCount], [balTicketCount])
SELECT  bal.[custid], bal.[roleid], bal.[amount], bal.[awinlost], bal.[mwinlost], bal.[swinlost], bal.[playercomm], bal.[comm], bal.[acomm], bal.[scomm], bal.[recommend], bal.[mrecommend], 
		bal.[srecommend], bal.[currency], bal.[UserName], bal.[CurrencyName], bal.[actualrate], bal.[TicketCount], bal.[balTicketCount]
FROM DBSIG01.SiteDB01tmp.dbo.balanceTable_Copy bal WITH (NOLOCK)
	LEFT JOIN [dbo].[balanceTable] main WITH (NOLOCK) ON main.custid = bal.custid
WHERE main.custid IS NULL

--11. balanceTable_tmp
INSERT INTO [dbo].[balanceTable_tmp](	[winlostdate], [custid], [roleid], [amount], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [recommend], [mrecommend], 
										[srecommend], [currency], [UserName], [CurrencyName], [actualrate], [TicketCount], [balTicketCount])
SELECT  bal.[winlostdate], bal.[custid], bal.[roleid], bal.[amount], bal.[awinlost], bal.[mwinlost], bal.[swinlost], bal.[playercomm], bal.[comm], bal.[acomm], bal.[scomm], bal.[recommend], bal.[mrecommend], 
		bal.[srecommend], bal.[currency], bal.[UserName], bal.[CurrencyName], bal.[actualrate], bal.[TicketCount], bal.[balTicketCount]
FROM DBSIG01.SiteDB01tmp.dbo.balanceTable_tmp_Copy bal WITH (NOLOCK)
	LEFT JOIN [dbo].[balanceTable_tmp] main WITH (NOLOCK) ON main.custid = bal.custid AND main.winlostdate = bal.winlostdate
WHERE main.custid IS NULL AND main.winlostdate IS NULL

--12. BalanceTable_tmp_cal
--There is no index for table balanceTable
INSERT INTO [dbo].[BalanceTable_tmp_cal] (	[dow], [roleid], [custid], [recommend], [mrecommend], [srecommend], 
											[amt1], [tcnt1], [amt2], [tcnt2], [amt3], [tcnt3], [amt4], [tcnt4])
SELECT	bal.[dow], bal.[roleid], bal.[custid], bal.[recommend], bal.[mrecommend], bal.[srecommend], 
		bal.[amt1], bal.[tcnt1], bal.[amt2], bal.[tcnt2], bal.[amt3], bal.[tcnt3], bal.[amt4], bal.[tcnt4]
FROM DBSIG01.SiteDB01tmp.dbo.BalanceTable_tmp_cal_Copy bal WITH (NOLOCK)
	LEFT JOIN [dbo].[BalanceTable_tmp_cal] main WITH (NOLOCK) ON main.custid = bal.custid
WHERE main.custid IS NULL