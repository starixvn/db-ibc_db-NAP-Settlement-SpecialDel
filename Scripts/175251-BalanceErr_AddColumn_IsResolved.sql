/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
   Created:20220921@Louisa
   Task: Scale Out BetTrans [Redmine:#175251]

   DB: DBCTG/bodb02
	
	Revisions:
		- 20220921@Louisa: Add new column IsResolved [Redmine:#175251]
	
	Param's Explanation: 

*/

USE bodb02
GO

IF NOT EXISTS ( SELECT TOP 1 1 FROM sys.objects o
			INNER JOIN sys.columns c 
				ON o.object_id = c.object_id
			WHERE o.name = 'BalanceErr'
				AND c.name = 'IsResolved'
		)
BEGIN
	ALTER TABLE dbo.BalanceErr ADD IsResolved BIT
END
GO

IF NOT EXISTS (SELECT TOP 1 1 FROM sys.default_constraints WHERE name = 'DF_BalanceErr_IsResolved')
BEGIN
	ALTER TABLE dbo.BalanceErr ADD CONSTRAINT DF_BalanceErr_IsResolved DEFAULT(0) FOR IsResolved

END
GO