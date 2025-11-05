/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

USE bodb02
GO

/*
	20251105@Louisa: ajust Transfer 19999 [Redmine:#243637]

*/

---1. COPY to bettrans14 and delete bettrans
	EXEC ExecRep_NAP_Admin_06


----2: ajust Transfer 19999

UPDATE  f
		SET  Stake			= 	2882
			,Actual_Stake	= 	2882
			,Winlost		= 	2043.949
			,AWinlost		= 	779.3873
			,MWinlost		= 	0
			,SWinlost		= 	0
			,PlayerComm		= 	0
			,Comm			= 	0
			,AComm			= 	0
			,SComm			= 	0
FROM dbo.Transfer f WITH(ROWLOCK, UPDLOCK)
WHERE  f.CustId = 182307399 
	AND  f.bettype =   19999
	AND  f.WinlostDate = '2025-11-01'


UPDATE  f
		SET  Stake			= 	1252
			,Actual_Stake	= 	1252
			,Winlost		= 	1502.2775
			,AWinlost		= 	-234.0095
			,MWinlost		= 	0
			,SWinlost		= 	0
			,PlayerComm		= 	0
			,Comm			= 	0
			,AComm			= 	0
			,SComm			= 	0
FROM dbo.Transfer f WITH(ROWLOCK, UPDLOCK)
WHERE  f.CustId = 175147784 
	AND  f.bettype =   19999
	AND  f.WinlostDate = '2025-11-01'



 






















































