/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created : Max
	Task	: Add index IX_custid [Redmine:#194102]
	DB: DB05-bodb02, DB05BK1-bodb02
*/
USE [bodb02]
GO

/****** Object:  Index [IX_custid]    Script Date: 9/17/2023 11:41:33 PM ******/
CREATE NONCLUSTERED INDEX [IX_custid] ON [dbo].[Transfer]
(
	[CustId] ASC,
	[WinlostDate] ASC,
	[Bettype] ASC
)
INCLUDE([Winlost],[PlayerComm],[Actual_Stake],[RefNo]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Transfer_Index]
GO


