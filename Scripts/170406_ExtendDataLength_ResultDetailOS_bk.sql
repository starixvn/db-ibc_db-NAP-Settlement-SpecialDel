/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0"></info>*/

/*
	Created : 20220329@Louisa
	Task	: Extend data length for dbo.ResultDetailOS_bk.OtherInfo [Redmine:#170406]

*/

USE bodb_archive
GO


ALTER TABLE dbo.ResultDetailOS_bk ALTER COLUMN OtherInfo VARCHAR(2000)
GO
