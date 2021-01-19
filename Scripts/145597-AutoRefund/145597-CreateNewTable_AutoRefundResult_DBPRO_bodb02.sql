/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20201228@Louisa
	Task : New table for Auto Refund result [Redmine:#145597]
	DB: DBPRO/bodb02 

*/

USE bodb02
GO

CREATE TABLE [dbo].[AutoRefundResult] 
(
 AutoRefundResultId INT IDENTITY(1,1) NOT FOR REPLICATION NOT NULL
,MatchId		INT			NOT NULL
,SourceId		TINYINT	
,TypeId			TINYINT	
,StatusId		TINYINT
,TryCount		TINYINT	
,CreateDate		DATETIME
,ModifiedDate	DATETIME
,Remark			VARCHAR(1000)		
) ON [DATA]

GO

ALTER TABLE [dbo].[AutoRefundResult] ADD CONSTRAINT PK_AutoRefundResult 
PRIMARY KEY CLUSTERED
(
	[AutoRefundResultId] ASC
) ON [DATA]
GO

ALTER TABLE [dbo].[AutoRefundResult] ADD CONSTRAINT [DF_AutoRefundResult_StatusId] DEFAULT(0) FOR [StatusId]
GO

ALTER TABLE [dbo].[AutoRefundResult] ADD CONSTRAINT [DF_AutoRefundResult_TryCount] DEFAULT(0) FOR [TryCount]
GO

ALTER TABLE [dbo].[AutoRefundResult] ADD CONSTRAINT [DF_AutoRefundResult_CreateDate] DEFAULT(GETDATE()) FOR [CreateDate]
GO

ALTER TABLE [dbo].[AutoRefundResult] ADD CONSTRAINT [DF_AutoRefundResult_ModifiedDate] DEFAULT(GETDATE()) FOR [ModifiedDate]
GO

CREATE NONCLUSTERED INDEX [IX_AutoRefundResult_SourceStatusType] ON [dbo].[AutoRefundResult]
(
	[MatchId] ASC
	,[TypeId] ASC	
	,[StatusId] ASC
) ON [DATA]
GO