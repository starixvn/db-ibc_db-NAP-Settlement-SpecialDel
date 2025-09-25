/*<info serverAlias="DBPRO-bodb02,DBAGE-bodb02,DBBOF-bodb02,DBACC-bodb02,IRS_DBTP-bodb02,DBRepl-ReplDB" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20250925@Hughie
	Task: Apply SOP for Outright phase 2 [Redmine: #233004]
	DB: DBPRO/bodb02

*/
IF NOT EXISTS (SELECT 1
				FROM sys.columns
				WHERE object_id = OBJECT_ID('dbo.ResultDetailOutright')
				  AND name = 'SettledBy'
				)
BEGIN
	ALTER TABLE ResultDetailOutright 
	ADD SettledBy INT NULL
END