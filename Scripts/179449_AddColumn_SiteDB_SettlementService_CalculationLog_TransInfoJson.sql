/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20221025@Louisa
	Task: Settlement  
	
	Revisions:
		- 20221025@Louisa: Add new column [Redmine:#179449]

	Param's Explanation:  
		   
*/
 
USE bodb02
GO
 
IF NOT EXISTS (SELECT TOP 1 1 FROM sys.objects o
				INNER JOIN sys.columns c ON o.object_id = c.object_id
				WHERE o.name = 'SiteDB_SettlementService_CalculationLog'
					AND c.name = 'TransInfoJson'
				)
BEGIN
	ALTER TABLE SiteDB_SettlementService_CalculationLog
	ADD TransInfoJson VARCHAR(MAX)
END

GO