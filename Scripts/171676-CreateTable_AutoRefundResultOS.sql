/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20220518@Louisa
	Task : New table for Auto Refund Other sports [Redmine:#171676]
	DB: DBPRO/bodb02 

*/

CREATE TABLE dbo.AutoRefundResultOS (
	AutoRefundResultOSId INT		IDENTITY(1,1)	
	,MatchId			INT			NOT NULL
	,SourceId			TINYINT		NOT NULL
	,ResourceId			VARCHAR(20)	NOT NULL
	,TypeId				TINYINT	
	,StatusId			TINYINT	
	,TryCount			TINYINT	
	,CreateDate			DATETIME	
	,ModifiedDate		DATETIME	
	,Remark				VARCHAR	
) --ON [DATA]
GO


ALTER TABLE [dbo].[AutoRefundResultOS] ADD CONSTRAINT PK_AutoRefundResultOS
PRIMARY KEY CLUSTERED
(
	AutoRefundResultOSId ASC
) --ON [DATA]
GO


CREATE NONCLUSTERED INDEX [IX_AutoRefundResultOS_MatchIdResourceId] ON [dbo].[AutoRefundResultOS]
(
	MatchId ASC
	,ResourceId ASC
) --ON [DATA]
GO


ALTER TABLE [dbo].[AutoRefundResultOS] ADD CONSTRAINT [DF_AutoRefundResultOS_StatusId] DEFAULT(0) FOR [StatusId]
GO

ALTER TABLE [dbo].[AutoRefundResultOS] ADD CONSTRAINT [DF_AutoRefundResultOS_TryCount] DEFAULT(0) FOR [TryCount]
GO

ALTER TABLE [dbo].[AutoRefundResultOS] ADD CONSTRAINT [DF_AutoRefundResultOS_CreateDate] DEFAULT(GETDATE()) FOR [CreateDate]
GO

ALTER TABLE [dbo].[AutoRefundResultOS] ADD CONSTRAINT [DF_AutoRefundResultOS_ModifiedDate] DEFAULT(GETDATE()) FOR [ModifiedDate]
GO
