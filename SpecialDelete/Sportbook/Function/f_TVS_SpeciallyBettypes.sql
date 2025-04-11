/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02,DBACC-bodb02,DBARC-bodb_Archive,DBRPT-bodb_Report,DB04Admin1-bodb02,DBBOF-bodb02,DBAGE-bodb02,DBKLC1-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_TVS_SpeciallyBettypes] ()
RETURNS TABLE
AS
/*
    Created: 20240718@Max
    Task: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02,DBACC-bodb02,DBARC-bodb_Archive,DBRPT-bodb_Report,DB04Admin1-bodb02,DBBOF-bodb02,DBAGE-bodb02,DBKLC1-bodb02

    Revisions:
		- 20240718@Max: Create function [Redmine: #207545]
		- 20250411@Max: [TVS] Deploy function f_TVS_SpeciallyBettypes to all subs db of dbtrans_bet [Redmine: #223692]

    Parameters Explanation:    
		- TypeId: 0 - Main parlay Sportbook
				  1 - Main parlay VS
				  2 - Outright
				  3 - Bet Builder
*/

RETURN (

	SELECT	CONVERT(SMALLINT, 29) AS Bettype
		,CONVERT(TINYINT, 0) AS TypeId  
	UNION ALL SELECT 2799,1
	UNION ALL SELECT 10449,1
	UNION ALL SELECT 11099,1
	-----Outright
	UNION ALL SELECT 10,2
	-----Bet builder
	UNION ALL SELECT 38,3
)
GO
