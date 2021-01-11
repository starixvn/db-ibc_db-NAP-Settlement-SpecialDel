/*<info serverAlias="DBARC-bodb_Archive" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20201228@Louisa
	Task : New table for Auto Refund result [Redmine:#145597]
	DB: DBARC/bodb_Archive 

*/

USE bodb_Archive 
GO

CREATE TABLE [dbo].[AutoRefundResult_bk] 
(
 AutoRefundResultId INT NOT NULL
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


ALTER TABLE [dbo].[AutoRefundResult_bk] ADD CONSTRAINT PK_AutoRefundResult_bk
PRIMARY KEY CLUSTERED
(
	[AutoRefundResultId] ASC
) ON [DATA]
GO