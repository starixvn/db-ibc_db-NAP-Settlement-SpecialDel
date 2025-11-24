/*<info serverAlias="DBTP-bodb02,DBSID-bodb02,DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20251118@Hughie
	Task: Upgrade Sporttype 
	DB: DBTP-bodb02,DBSID-bodb02,DBCTG-bodb02

	Revisions: 
		- 20251106@Hughie: Create [Redmine:#241262]
	Params explaination:

*/
USE bodb02
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'CIX_SportType_CustID_RoundID' AND object_id = OBJECT_ID('LuckyDraw3rd'))
	DROP INDEX CIX_SportType_CustID_RoundID ON LuckyDraw3rd
GO

ALTER TABLE LuckyDraw3rd
ALTER COLUMN Sporttype SMALLINT NULL
GO

CREATE CLUSTERED INDEX CIX_SportType_CustID_RoundID ON LuckyDraw3rd (Sporttype, CustID, RoundID)
GO