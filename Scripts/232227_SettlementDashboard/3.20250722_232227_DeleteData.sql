/*<info serverAlias="DBWH-bodb_dwrs" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250722@Max
	Task	  : Integration - Settlement Time Dashboard report [Redmine:#232227]
	DB		  : DBWH-bodb_dwrs
	Revisions:
		- 20250722@Max: Init data [Redmine:#232227]
*/

DELETE r
FROM SettlementPerformanceReport r
WHERE r.eventdate = '2025-07-22' 