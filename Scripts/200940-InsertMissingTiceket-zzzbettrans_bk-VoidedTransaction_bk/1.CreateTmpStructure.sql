?/*<info serverAlias="DBARC-bodb_Archive" executers="" isFunction="0"></info>*/
/*	
	Created by: Max
	Date: 20240301
	Task: Insert zzzbettrans_bk for missing ticket - [Redmine: #200940]
	DB: DBARC-bodb_Archive
	
*/ 
USE bodb02
GO

CREATE TABLE [dbo].[tmp_zzzbettrans_bk](
	[transid] [bigint] NOT NULL,
	[custid] [int] NOT NULL,
	[transdate] [datetime] NOT NULL,
	[oddsid] [int] NOT NULL,
	[hdp1] [smallmoney] NULL,
	[hdp2] [smallmoney] NULL,
	[odds] [smallmoney] NULL,
	[stake] [money] NOT NULL,
	[status] [nvarchar](10) NULL,
	[winlost] [money] NULL,
	[livehomescore] [smallint] NULL,
	[liveawayscore] [smallint] NULL,
	[liveindicator] [bit] NULL,
	[betteam] [nvarchar](10) NULL,
	[creator] [int] NOT NULL,
	[refno] [bigint] NULL,
	[comstatus] [nvarchar](20) NULL,
	[winlostdate] [smalldatetime] NULL,
	[betfrom] [nvarchar](4) NULL,
	[betcheck] [nvarchar](50) NULL,
	[checktime] [datetime] NULL,
	[matchid] [int] NULL,
	[bettype] [smallint] NULL,
	[keyid] [int] NOT NULL,
	[VoidingHistoryId] [int] NULL
)
GO

CREATE TABLE [dbo].[tmp_TicketVoiding_VoidedTransaction_bk](
	[TransId] [bigint] NOT NULL,
	[MessageId] [int] NOT NULL,
	[ReasonId] [int] NOT NULL,
	[MatchId] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[Id] [int] NOT NULL,
	[IssueTypeID] [tinyint] NULL,
	[SubIssueTypeID] [tinyint] NULL,
	[CustID] [int] NULL,
)
GO

