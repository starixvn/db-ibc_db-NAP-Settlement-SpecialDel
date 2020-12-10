/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20201113@Louisa
	Task : Add new column ResultSetting [Redmine:#135097]
	DB: DBPRO/bodb02

	Revisions:
		- 220201113@Louisa: Add new column ResultSetting (dbo.ResultDetail/ES/OS) [Redmine:#135097]
*/

USE bodb02
GO

IF NOT EXISTS(	SELECT TOP 1 1 FROM sys.columns 
				WHERE Name = N'ResultSetting' 
					AND OBJECT_ID = OBJECT_ID(N'dbo.ResultDetail')
			)
BEGIN
	ALTER TABLE dbo.ResultDetail ADD ResultSetting TINYINT NULL
END
GO

-----------------------------------------------------------------------
IF NOT EXISTS(	SELECT TOP 1 1 FROM sys.columns 
				WHERE Name = N'ResultSetting' 
					AND OBJECT_ID = OBJECT_ID(N'dbo.ResultDetailES')
			)
BEGIN
	ALTER TABLE dbo.ResultDetailES ADD ResultSetting TINYINT NULL
END
GO

-----------------------------------------------------------------------
IF NOT EXISTS(	SELECT TOP 1 1 FROM sys.columns 
				WHERE Name = N'ResultSetting' 
					AND OBJECT_ID = OBJECT_ID(N'dbo.ResultDetailOS')
			)
BEGIN
	ALTER TABLE dbo.ResultDetailOS ADD ResultSetting TINYINT NULL
END

GO
