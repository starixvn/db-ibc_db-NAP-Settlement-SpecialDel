/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0"></info>*/

/*	
	Creator: Louisa
	Date: 20211015
	Task: Update data type
	DB: DBPRO/bodb02

	Revisions:
		- 20211015@Louisa: Update data type [Redmine:#]
				  
*/

USE bodb_archive
GO


SET NOCOUNT ON
	
	--ResultDetailOS_bk
	ALTER TABLE dbo.ResultDetailOS_bk ALTER COLUMN CreateDate DATETIME
	GO

	ALTER TABLE dbo.ResultDetailOS_bk ALTER COLUMN LastModifyDate DATETIME
	GO

	--ResultDetailES_bk
	ALTER TABLE dbo.ResultDetailES_bk ALTER COLUMN CreateDate DATETIME
	GO

	ALTER TABLE dbo.ResultDetailES_bk ALTER COLUMN LastModifyDate DATETIME
	GO