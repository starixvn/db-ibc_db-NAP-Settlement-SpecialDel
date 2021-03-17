/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: Helen
	Date: 20210319
	Task: Deposit - Saba.Club - Free Bets [Redmine: #142369]
	DB: DBTRANS/bodb02
	
	Revisions:
		- 20210319@Helen: Deposit - Saba.Club - Free Bets [Redmine: #142369]
*/
USE bodb02
GO
CREATE TABLE LuckyDraw3rd_Log (
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Sporttype] [tinyint] NULL,
	[RoundID] INT,
	[CreatedDate] [datetime] NULL, 
	CONSTRAINT [LuckyDraw3rd_Log_ID] PRIMARY KEY NONCLUSTERED 
	(
		[ID] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [DATA]
) ON [DATA]

GO
CREATE CLUSTERED INDEX [CIX_SportType_RoundID] ON [dbo].[LuckyDraw3rd_Log] 
(
	[Sporttype] ASC,
	[RoundID] ASC
)
GO

