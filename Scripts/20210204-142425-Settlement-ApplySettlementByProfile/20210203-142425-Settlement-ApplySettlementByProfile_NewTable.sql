/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE [bodb02]
GO

CREATE TABLE [dbo].[SingleSettlementTrace](
	[MatchId] [int] NULL,
	[SqlCommand] [varchar](max) NULL,
	[CreatedDate] [datetime] NULL
) ON [DATA] TEXTIMAGE_ON [DATA]
GO

ALTER TABLE [dbo].[SingleSettlementTrace] ADD  CONSTRAINT [DF_SingleSettlementTrace_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO


CREATE CLUSTERED INDEX [CIX_SingleSettlementTrace] ON [dbo].[SingleSettlementTrace]
(
	[MatchId] ASC
) ON [DATA]
GO