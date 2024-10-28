/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
    Created: 20241028@Aries
	Task: Direct payout for early soccer [Redmine:#211079]
	DB: DBPRO/bodb02
*/
USE bodb02
GO
ALTER TABLE dbo.AutoPayoutResult ADD ResourceId VARCHAR(20)
GO
ALTER TABLE dbo.AutoPayoutResult14 ADD ResourceId VARCHAR(20)
GO