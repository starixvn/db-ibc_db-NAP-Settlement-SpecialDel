/*<info serverAlias="DBACC-bodb02,DBCTS-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20251113@Hughie
	Task: Upgrade Sporttype 
	DB: DBACC-bodb02,DBCTS-bodb02

	Revisions: 
		- 20251106@Hughie: Create [Redmine:#241262]
	Params explaination:

*/
USE bodb02
GO

ALTER TABLE LuckyDraw3rd
ALTER COLUMN Sporttype SMALLINT NULL