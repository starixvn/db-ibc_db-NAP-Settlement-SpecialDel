/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: Louisa
	Date: 20210729
	Task: Auto Settle Cricket [Redmine:#154586]

*/

USE bodb02
GO

CREATE TABLE dbo.AutoPayoutResultOS (
		 AutoPayoutResultId	INT IDENTITY(1,1)
		,MatchId			INT NOT NULL
		,ResourceId			VARCHAR(20) NOT NULL 
		,HomeValue			VARCHAR(50)
		,AwayValue			VARCHAR(50)
		,StatusId			TINYINT
		,CreatedBy			INT
		,ModifiedBy			INT
		,CreatedDate		DATETIME
		,ModifiedDate		DATETIME 
CONSTRAINT [PK_AutoPayoutResultOS] PRIMARY KEY NONCLUSTERED 
(
	[AutoPayoutResultId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
) ON [DATA]
GO


ALTER TABLE dbo.AutoPayoutResultOS ADD CONSTRAINT DF_AutoPayoutResultOS_StatusId DEFAULT (0) FOR StatusId
GO

ALTER TABLE dbo.AutoPayoutResultOS ADD CONSTRAINT DF_AutoPayoutResultOS_CreatedDate DEFAULT (GETDATE()) FOR CreatedDate
GO

ALTER TABLE dbo.AutoPayoutResultOS ADD CONSTRAINT DF_AutoPayoutResultOS_ModifiedDate DEFAULT (GETDATE()) FOR ModifiedDate
GO

CREATE NONCLUSTERED INDEX IX_AutoPayoutResultOS_MatchIdResourceId ON dbo.AutoPayoutResultOS 
(
	MatchId ASC,
	ResourceId ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO