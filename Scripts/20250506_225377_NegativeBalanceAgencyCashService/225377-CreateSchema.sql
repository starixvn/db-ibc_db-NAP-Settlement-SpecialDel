/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250506Aries
	Task	  : Negative Balance for Agency Cash Service  [Redmine:#225377]
	DB		  : DBSIC/bodb02
	Revisions:

*/
USE bodb02

CREATE TABLE [dbo].[BalanceNegative](
	[ExecID] [bigint] IDENTITY(1,1) NOT NULL,
	[ExecDate] [datetime] NOT NULL,
	[MatchID] [int] NOT NULL,
	[ActionID] [int] NULL,
	[GroupID] [tinyint] NOT NULL,
	[CustID] [int] NULL,
	[Balance] [money] NULL,
	[StatusID] [bit] NULL,
	[Remark] [varchar](2000) NULL,
	[SessionId] [varchar](50) NULL,
 	CONSTRAINT [PK_BalanceNegative_ExecID] PRIMARY KEY NONCLUSTERED ([ExecID] ASC)
)
GO
ALTER TABLE [dbo].[BalanceNegative] ADD  CONSTRAINT [DF_BalanceNegative_GroupID_0]  DEFAULT ((0)) FOR [GroupID]
CREATE CLUSTERED INDEX [CIX_BalanceNegative] ON [dbo].[BalanceNegative](MatchID,CustID,GroupID,StatusID)
CREATE NONCLUSTERED INDEX [IX_custid]ON [dbo].[BalanceNegative] (CustID)


GO

CREATE TABLE [dbo].[Cash_BalanceNegative](
	[LogID] [bigint] IDENTITY(1,1) NOT NULL,
	[LogDate] [datetime] NULL,
	[MatchID] [int] NOT NULL,
	[ActionID] [int] NULL,
	[CustID] [int] NULL,
	[GroupID] [tinyint] NOT NULL,
	[Balance] [money] NULL,
	[TotalBalance] [money] NULL,
	[StatusID] [bit] NULL,
	[SessionId] [varchar](50) NULL,
 	CONSTRAINT [PK_Cash_BalanceNegative_LogID] PRIMARY KEY NONCLUSTERED ([LogID] ASC)
) 
