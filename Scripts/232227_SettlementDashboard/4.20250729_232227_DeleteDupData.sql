/*<info serverAlias="DBWH-bodb_account" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250729@Max
	Task	  : Integration - Settlement Time Dashboard report [Redmine:#232227]
	DB		  : DBWH-bodb_account, DBDW2-bodb_account
	Revisions:
		- 20250729@Max: Delete duplicate data [Redmine:#232227]
*/

DECLARE @EventDate DATETIME = '2025-07-25'

;WITH CTE(
	RowId, 
    DuplicateCount)
AS (SELECT RowID,
           ROW_NUMBER() OVER(PARTITION BY EventDate,Sporttype,leagueid
           ORDER BY EventDate,Sporttype,leagueid) AS DuplicateCount
    FROM bodb_account.dbo.SettlementPerformanceReport s WITH (NOLOCK)
	WHERE s.EventDate >= @EventDate)
DELETE FROM CTE
WHERE DuplicateCount > 1;