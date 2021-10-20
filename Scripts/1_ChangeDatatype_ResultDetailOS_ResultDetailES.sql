/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*	
	Creator: Louisa
	Date: 20211015
	Task: Update data type
	DB: DBPRO/bodb02

	Revisions:
		- 20211015@Louisa: Update data type [Redmine:#163474]
				  
*/

USE bodb02
GO

SET NOCOUNT ON
	
	--ResultDetailOS

	ALTER TABLE dbo.ResultDetailOS DROP CONSTRAINT DF_ResultDetailOS_CreateDate
	GO

	ALTER TABLE dbo.ResultDetailOS ALTER COLUMN CreateDate DATETIME
	GO

	ALTER TABLE dbo.ResultDetailOS ADD CONSTRAINT DF_ResultDetailOS_CreateDate DEFAULT(GETDATE()) FOR CreateDate
	GO

	ALTER TABLE dbo.ResultDetailOS ALTER COLUMN LastModifyDate DATETIME
	GO

	--ResultDetailOS14

	ALTER TABLE dbo.ResultDetailOS14 ALTER COLUMN CreateDate DATETIME
	GO

	ALTER TABLE dbo.ResultDetailOS14 ALTER COLUMN LastModifyDate DATETIME
	GO

	--ResultDetailES
	ALTER TABLE dbo.ResultDetailES DROP CONSTRAINT DF_ResultDetailES_CreateDate
	GO

	ALTER TABLE dbo.ResultDetailES ALTER COLUMN CreateDate DATETIME
	GO

	ALTER TABLE dbo.ResultDetailES ADD CONSTRAINT DF_ResultDetailES_CreateDate DEFAULT(GETDATE()) FOR CreateDate
	GO

	ALTER TABLE dbo.ResultDetailES ALTER COLUMN LastModifyDate DATETIME
	GO

	--ResultDetailES14
	ALTER TABLE dbo.ResultDetailES14 ALTER COLUMN CreateDate DATETIME
	GO

	ALTER TABLE dbo.ResultDetailES14 ALTER COLUMN LastModifyDate DATETIME
	GO


