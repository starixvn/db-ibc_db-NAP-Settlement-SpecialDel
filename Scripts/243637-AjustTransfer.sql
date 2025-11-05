/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

USE bodb02
GO

/*
	20251105@Louisa: issue ticket on DBTrans does not move to bettrans14 even SiteDB was moved Redmine:#243637

*/

----STEP 2: ajust Transfer 19999

UPDATE  f
		SET  TransDate		= 	'2025-11-01'
			,WinlostDate	= 	'2025-11-01'
			,Bettype		= 	19999
			,Stake			= 	2882
			,Actual_Stake	= 	2882
			,Winlost		= 	2043.949
			,AWinlost		= 	779.3873
			,MWinlost		= 	0
			,SWinlost		= 	0
			,PlayerComm		= 	0
			,Comm			= 	0
			,AComm			= 	0
			,SComm			= 	0
			,StatusId		= 	142
			,RefNo			= 	300000119593
			,TransDesc		= 	Null
			,Recommend		= 	89330904
			,MRecommend		= 	89330903
			,SRecommend		= 	89330902
			,Username		= 	'ASKMEBETSTB01S393729'
			,Currency		= 	4
			,CurrencyName	= 	'TB'
			,ActualRate		= 	0.1263
			,Creator		= 	8
			,Balance		= 	Null
			,IP				= 	Null
			,CheckTime		= 	'2025-11-04 17:43:11'
			,SerialNo		= 	0
			,RepUpdateTime	= 	Null
FROM dbo.Transfer f WITH(ROWLOCK, UPDLOCK)
WHERE  f.CustId = 182307399 
	AND  f.bettype =   19999
	AND  f.WinlostDate = '2025-11-01'


UPDATE  f
		SET  TransDate		= 	'2025-11-01'
			,WinlostDate	= 	'2025-11-01'
			,Bettype		= 	19999
			,Stake			= 	1252
			,Actual_Stake	= 	1252
			,Winlost		= 	1502.2775
			,AWinlost		= 	-234.0095
			,MWinlost		= 	0
			,SWinlost		= 	0
			,PlayerComm		= 	0
			,Comm			= 	0
			,AComm			= 	0
			,SComm			= 	0
			,StatusId		= 	142
			,RefNo			= 	300000113649
			,TransDesc		= 	Null
			,Recommend		= 	121949486
			,MRecommend		= 	121949485
			,SRecommend		= 	121949484
			,Username		= 	'ZABBETTB01S46244'
			,Currency		= 	4
			,CurrencyName	= 	'TB'
			,ActualRate		= 	0.1263
			,Creator		= 	8
			,Balance		= 	Null
			,IP				= 	Null
			,CheckTime		= 	'2025-11-04 17:43:08'
			,SerialNo		= 	0
			,RepUpdateTime	= 	Null
FROM dbo.Transfer f WITH(ROWLOCK, UPDLOCK)
WHERE  f.CustId = 175147784 
	AND  f.bettype =   19999
	AND  f.WinlostDate = '2025-11-01'



 






















































