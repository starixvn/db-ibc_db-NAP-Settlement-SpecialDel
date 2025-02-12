/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20241223@Aries
	Task: Support Auto Refund for Soccer's Early Results [Redmine:#214410]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
ALTER TABLE dbo.AutoRefundResult ADD OtherInfo VARCHAR(MAX)
