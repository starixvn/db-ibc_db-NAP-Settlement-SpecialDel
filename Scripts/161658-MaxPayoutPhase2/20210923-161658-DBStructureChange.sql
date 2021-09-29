/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210923@Max
	Task: Max Payout Phase 2 - [Redmine: #161658]
	DB: DBTRANS-bodb02
*/

USE bodb02
GO

ALTER TABLE dbo.CustLimitBetQueue 
	ALTER COLUMN EventTypeID TINYINT NULL;






