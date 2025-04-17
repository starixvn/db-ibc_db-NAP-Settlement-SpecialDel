/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20250417@Hughie
	Task: Settlement  
	
	Revisions:
		- 20250416@Hughie: Settle - Integrate - Result Amendment -Betbuilder [Redmine:#224372]

	Param's Explanation:  
		   
*/
USE bodb02
GO

IF NOT EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE object_id = OBJECT_ID('dbo.SiteDB_SettlementService_CalculationLog_3rd') 
    AND name = 'BroadcastSessionId'   
)
BEGIN
	ALTER TABLE dbo.SiteDB_SettlementService_CalculationLog_3rd
	ADD BroadcastSessionId VARCHAR(50) NULL

	CREATE NONCLUSTERED INDEX IX_SiteDB_SettlementService_CalculationLog_3rd_BroadcastSessionId
    ON dbo.SiteDB_SettlementService_CalculationLog_3rd(BroadcastSessionId);

END
ELSE
BEGIN
    RETURN
END