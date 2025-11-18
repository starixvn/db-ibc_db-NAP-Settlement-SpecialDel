/*<info serverAlias="DBSID-bodb02,DBSIC-bodb02,DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20251118@Hughie
	Task: Upgrade Sporttype 
	DB: DBSID-bodb02,DBSIC-bodb02,DBCTG-bodb02

	Revisions: 
		- 20251106@Hughie: Create [Redmine:#241262]
	Params explaination:

*/
USE bodb02
GO

ALTER TABLE LuckyDraw3rd_Log
ALTER COLUMN Sporttype SMALLINT NULL

ALTER TABLE Single_Calculate_Queue_3rd
ALTER COLUMN Sporttype SMALLINT NULL