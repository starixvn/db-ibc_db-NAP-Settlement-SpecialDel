/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE [bodb02]
GO
CREATE NONCLUSTERED INDEX [IX_SingleSettlementTrace_CreatedDate] ON [dbo].[SingleSettlementTrace]
(
	[CreatedDate] ASC
) WITH (ONLINE = ON) ON [DATA]
GO