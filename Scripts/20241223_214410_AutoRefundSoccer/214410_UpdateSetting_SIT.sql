/*<info serverAlias="DBPRO-bodb02,IRS_DBTP-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250512@Hughie
	Task: Support Auto Refund for Soccer's Early Results [Redmine:#214410]
	DB: DBPRO/bodb02,IRS_DBTP-bodb02
*/
 
USE bodb02
GO

TRUNCATE TABLE AutoRefundSetting
