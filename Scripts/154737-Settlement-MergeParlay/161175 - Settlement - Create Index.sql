/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20210904@Kathy
	Task : Create index on Settled_Message [Redmine:#161175]
	DB: DBTXN/bodb02
*/
USE bodb02
GO
CREATE CLUSTERED INDEX [CIX_Settled_Message_Starttime] ON [dbo].[Settled_Message]
(
	[Starttime] ASC
) ON [DATA]
GO


