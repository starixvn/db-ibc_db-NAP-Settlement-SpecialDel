/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
    Created: 20241223@Aries
	Task: Support Auto Refund for Soccer's Early Results [Redmine:#214410]
	DB: DBPRO/bodb02
*/
USE bodb02
GO
ALTER TABLE dbo.AutoRefundResult ADD ResourceId VARCHAR(20)
ALTER TABLE dbo.AutoRefundResult ADD HomeValue VARCHAR(50)
ALTER TABLE dbo.AutoRefundResult ADD AwayValue VARCHAR(50)