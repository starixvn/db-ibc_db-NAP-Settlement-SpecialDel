/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*	
	Creator: Louisa
	Date: 20211015
	Task: Update data type
	DB: DBPRO/bodb02

	Revisions:
		- 20211015@Louisa: Update data type [Redmine:#]
				  
*/

USE bodb02
GO

SET NOCOUNT ON
	
	ALTER TABLE dbo.ResultDetailOS DROP CONSTRAINT DF_ResultDetailOS_CreateDate
	GO

	ALTER TABLE dbo.ResultDetailOS ALTER COLUMN CreateDate DATETIME
	GO

	ALTER TABLE dbo.ResultDetailOS ADD CONSTRAINT DF_ResultDetailOS_CreateDate DEFAULT(GETDATE()) FOR CreateDate
	GO

	ALTER TABLE dbo.ResultDetailOS ALTER COLUMN LastModifyDate DATETIME
	GO

	---------------------------------------------------------------------------------

	ALTER TABLE dbo.ResultDetailES DROP CONSTRAINT DF_ResultDetailES_CreateDate
	GO

	ALTER TABLE dbo.ResultDetailES ALTER COLUMN CreateDate DATETIME
	GO

	ALTER TABLE dbo.ResultDetailES ADD CONSTRAINT DF_ResultDetailES_CreateDate DEFAULT(GETDATE()) FOR CreateDate
	GO

	ALTER TABLE dbo.ResultDetailES ALTER COLUMN LastModifyDate DATETIME
	GO


