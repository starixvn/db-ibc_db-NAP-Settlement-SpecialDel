/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created : 20220329@Louisa
	Task	: Extend data length for dbo.ResultDetailOS.OtherInfo [Redmine:#170406]

*/

USE bodb02
GO


ALTER TABLE dbo.ResultDetailOS ALTER COLUMN OtherInfo VARCHAR(2000)
GO

ALTER TABLE dbo.ResultDetailOS14 ALTER COLUMN OtherInfo VARCHAR(2000)
GO

