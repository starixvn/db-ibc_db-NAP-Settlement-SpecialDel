/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
    Created: 20240503@Aries
	Task: Support Auto Payout 2 for Basketball [Redmine:#203520]
	DB: DBPRO/bodb02
*/

USE bodb02
GO

CREATE TABLE dbo.AutoPayoutPrepareOS (
		 Id					INT IDENTITY(1,1)
		,MatchId			INT NOT NULL
		,ResourceId			VARCHAR(20) NOT NULL 
		,StatusId			TINYINT
		,CreatedDate		DATETIME
		,Remark				VARCHAR(MAX) 
CONSTRAINT [PK_AutoPayoutPrepareOS] PRIMARY KEY NONCLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
) ON [DATA]
GO

CREATE CLUSTERED INDEX CIX_AutoPayoutPrepareOS_MatchIdResourceId ON dbo.AutoPayoutPrepareOS 
(
	MatchId ASC,
	ResourceId ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO