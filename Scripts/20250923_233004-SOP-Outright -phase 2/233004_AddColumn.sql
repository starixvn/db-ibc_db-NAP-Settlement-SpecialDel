/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20250925@Hughie
	Task: Apply SOP for Outright phase 2 [Redmine: #233004]
	DB: DBPRO/bodb02

*/
USE bodb02
GO

IF NOT EXISTS (SELECT 1
				FROM sys.columns
				WHERE object_id = OBJECT_ID('dbo.ResultDetailOutright')
				  AND name = 'SettleBy'
				)
BEGIN
	ALTER TABLE ResultDetailOutright 
	ADD SettleBy INT NULL
END